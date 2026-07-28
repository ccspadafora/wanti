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
    apply_transaction(
        wallet=wallet,
        transaction_type=TransactionType.TOPUP,
        amount_wantis=package.wantis_base,
        related_object=order,
        note=f'Recarga paquete {package.name}',
        created_by=order.user,
    )
    if package.wantis_bonus:
        apply_transaction(
            wallet=wallet,
            transaction_type=TransactionType.BONUS,
            amount_wantis=package.wantis_bonus,
            related_object=order,
            note=f'Bonificación +{package.wantis_bonus}',
            created_by=order.user,
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
def fail_topup_order(order: TopupOrder, provider_payload: dict | None = None) -> TopupOrder:
    order = TopupOrder.objects.select_for_update().get(pk=order.pk)
    if order.status == TopupStatus.COMPLETED:
        raise ValidationError('No se puede fallar una orden completada')
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
