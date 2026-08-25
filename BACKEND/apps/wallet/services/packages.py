from django.db import transaction
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import TopupStatus, TransactionType
from apps.common.exceptions import ConflictError, NotFoundError, ValidationError
from apps.wallet.models import TopupOrder, TopupPackage
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet


@transaction.atomic
def create_topup_order(user, package_id) -> TopupOrder:
    try:
        package = TopupPackage.objects.get(id=package_id, is_active=True)
    except TopupPackage.DoesNotExist as exc:
        raise NotFoundError('Paquete no encontrado') from exc
    order = TopupOrder.objects.create(
        user=user,
        package=package,
        wantis_total=package.wantis_base + package.wantis_bonus,
        price_cop=package.price_cop,
        status=TopupStatus.PENDING,
    )
    log_audit_event(
        actor_user=user,
        action='TOPUP_ORDER_CREATED',
        entity='TopupOrder',
        entity_id=order.id,
        metadata={'package': package.name, 'price': str(package.price_cop)},
    )
    return order


@transaction.atomic
def complete_topup_order(
    order: TopupOrder,
    provider_reference: str,
    provider_payload: dict,
) -> TopupOrder:
    order = TopupOrder.objects.select_for_update().get(pk=order.pk)
    if order.status == TopupStatus.COMPLETED:
        return order
    if order.status != TopupStatus.PENDING:
        raise ConflictError(f'Orden en estado {order.status}')

    wallet = get_or_create_wallet(order.user)
    package = order.package
    # Idempotencia: no acreditar TOPUP dos veces por la misma orden
    apply_transaction(
        wallet=wallet,
        transaction_type=TransactionType.TOPUP,
        amount_wantis=package.wantis_base,
        related_object=order,
        note=f'Recarga paquete {package.name}',
        created_by=order.user,
        idempotency_key=f'topup:{order.id}',
    )
    if package.wantis_bonus:
        apply_transaction(
            wallet=wallet,
            transaction_type=TransactionType.BONUS,
            amount_wantis=package.wantis_bonus,
            related_object=order,
            note=f'Bonificación +{package.wantis_bonus}',
            created_by=order.user,
            idempotency_key=f'topup-bonus:{order.id}',
        )
    order.status = TopupStatus.COMPLETED
    order.provider_reference = provider_reference
    order.provider_payload = provider_payload or {}
    order.completed_at = timezone.now()
    order.save(
        update_fields=[
            'status',
            'provider_reference',
            'provider_payload',
            'completed_at',
            'updated_at',
        ]
    )
    log_audit_event(
        actor_user=order.user,
        action='TOPUP_ORDER_COMPLETED',
        entity='TopupOrder',
        entity_id=order.id,
    )
    return order


@transaction.atomic
def fail_topup_order(order: TopupOrder, provider_payload=None) -> TopupOrder:
    order = TopupOrder.objects.select_for_update().get(pk=order.pk)
    if order.status == TopupStatus.COMPLETED:
        raise ValidationError('No se puede fallar una orden completada')
    if order.status in (TopupStatus.FAILED, TopupStatus.CANCELLED, TopupStatus.REFUNDED):
        return order
    order.status = TopupStatus.FAILED
    if provider_payload is not None:
        order.provider_payload = provider_payload
    order.save(update_fields=['status', 'provider_payload', 'updated_at'])
    log_audit_event(
        actor_user=order.user,
        action='TOPUP_ORDER_FAILED',
        entity='TopupOrder',
        entity_id=order.id,
    )
    return order


@transaction.atomic
def cancel_topup_order(order: TopupOrder, provider_payload=None) -> TopupOrder:
    order = TopupOrder.objects.select_for_update().get(pk=order.pk)
    if order.status == TopupStatus.COMPLETED:
        raise ValidationError('No se puede cancelar una orden completada')
    if order.status in (TopupStatus.CANCELLED, TopupStatus.FAILED, TopupStatus.REFUNDED):
        return order
    order.status = TopupStatus.CANCELLED
    if provider_payload is not None:
        order.provider_payload = provider_payload
    order.save(update_fields=['status', 'provider_payload', 'updated_at'])
    log_audit_event(
        actor_user=order.user,
        action='TOPUP_ORDER_CANCELLED',
        entity='TopupOrder',
        entity_id=order.id,
    )
    return order


def list_packages(include_inactive: bool = True):
    qs = TopupPackage.objects.all().order_by('order', 'name')
    if not include_inactive:
        qs = qs.filter(is_active=True)
    return qs


@transaction.atomic
def create_package(actor_user, data: dict) -> TopupPackage:
    package = TopupPackage.objects.create(
        name=data['name'],
        wantis_base=data['wantis_base'],
        wantis_bonus=data.get('wantis_bonus', 0),
        price_cop=data['price_cop'],
        is_popular=data.get('is_popular', False),
        is_active=data.get('is_active', True),
        order=data.get('order', 0),
    )
    log_audit_event(
        actor_user=actor_user,
        action='TOPUP_PACKAGE_CREATED',
        entity='TopupPackage',
        entity_id=package.id,
        metadata={'name': package.name},
    )
    return package


@transaction.atomic
def update_package(package: TopupPackage, actor_user, data: dict) -> TopupPackage:
    for field in (
        'name',
        'wantis_base',
        'wantis_bonus',
        'price_cop',
        'is_popular',
        'is_active',
        'order',
    ):
        if field in data:
            setattr(package, field, data[field])
    package.save()
    log_audit_event(
        actor_user=actor_user,
        action='TOPUP_PACKAGE_UPDATED',
        entity='TopupPackage',
        entity_id=package.id,
    )
    return package


@transaction.atomic
def deactivate_package(package: TopupPackage, actor_user) -> TopupPackage:
    package.is_active = False
    package.save(update_fields=['is_active', 'updated_at'])
    log_audit_event(
        actor_user=actor_user,
        action='TOPUP_PACKAGE_DEACTIVATED',
        entity='TopupPackage',
        entity_id=package.id,
    )
    return package
