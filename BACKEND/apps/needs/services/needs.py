from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import AssetType, NeedStatus
from apps.common.exceptions import PermissionError, UserNotVerifiedError, ValidationError
from apps.common.services.settings_service import get_setting
from apps.geo.services import resolve_geo_location, resolve_travel_city_ids
from apps.needs.models import Need, NeedCriterion, NeedImage, PropertyNeed, VehicleNeed


def _filter_model_fields(model, data: dict) -> dict:
    allowed = {f.name for f in model._meta.fields if f.name not in {'need', 'item'}}
    return {k: v for k, v in data.items() if k in allowed}


def _validate_budget_ratio(budget_max_cop, commercial_value=None):
    ratio = get_setting('MIN_BUDGET_RATIO', 0.40)
    if commercial_value is not None and budget_max_cop < commercial_value * ratio:
        raise ValidationError(
            'El presupuesto es demasiado bajo respecto al valor comercial de referencia'
        )


def _sync_structural_criteria(need: Need) -> None:
    """Ensure brand/model/category/year are REQUIRED criteria derived from detail metadata."""
    if need.asset_type != AssetType.VEHICLE:
        return
    vehicle = getattr(need, 'vehicle', None)
    if vehicle is None:
        return

    structural_specs = [
        ('vehicle_category', 30),
        ('brand', 30),
        ('model', 30),
        ('line', 20),
        ('year_min', 20),
        ('year_max', 20),
    ]
    for attribute, weight in structural_specs:
        value = getattr(vehicle, attribute, None)
        if value is None or (isinstance(value, str) and not value.strip()):
            NeedCriterion.objects.filter(need=need, attribute=attribute).delete()
            continue
        NeedCriterion.objects.update_or_create(
            need=need,
            attribute=attribute,
            defaults={'mode': 'REQUIRED', 'weight': weight},
        )


@transaction.atomic
def create_need(buyer, data: dict, *, bypass_verification: bool = False) -> Need:
    if not bypass_verification and not buyer.can_publish:
        raise UserNotVerifiedError('Debes verificar email y teléfono para publicar')
    payment_types = data.get('payment_types') or [data['payment_type']]
    if not payment_types:
        payment_types = [data['payment_type']]
    geo = resolve_geo_location(
        department=data.get('department'),
        city=data.get('city'),
        geo_city_id=data.get('geo_city_id'),
        location=data.get('location'),
    )

    trade_in_item_id = data.get('trade_in_inventory_id')
    if trade_in_item_id:
        from apps.inventory.models import InventoryItem

        try:
            trade_item = InventoryItem.objects.get(id=trade_in_item_id, seller=buyer)
        except InventoryItem.DoesNotExist as exc:
            raise ValidationError(
                'El inventario de permuta no existe o no te pertenece'
            ) from exc
    else:
        trade_item = None

    need = Need.objects.create(
        buyer=buyer,
        asset_type=data['asset_type'],
        title=data['title'],
        description=data.get('description', ''),
        budget_max_cop=data['budget_max_cop'],
        payment_type=payment_types[0],
        payment_types=payment_types,
        trade_in_description=data.get('trade_in_description', ''),
        trade_in_item=trade_item,
        city=geo['city'],
        department=geo['department'],
        geo_city=geo['geo_city'],
        willing_to_travel=bool(data.get('willing_to_travel')),
        location=geo['location'],
        status=NeedStatus.DRAFT,
    )
    travel_cities = resolve_travel_city_ids(data.get('travel_city_ids') or [])
    if travel_cities:
        need.willing_to_travel = True
        need.save(update_fields=['willing_to_travel', 'updated_at'])
        need.travel_cities.set(travel_cities)
    detail_data = data.get('detail') or {}
    catalog_version_id = detail_data.get('catalog_version_id')
    if need.asset_type == AssetType.VEHICLE and catalog_version_id:
        from apps.catalog.services.version_specs import validate_detail_against_version

        validate_detail_against_version(catalog_version_id, detail_data)
    if need.asset_type == AssetType.VEHICLE:
        VehicleNeed.objects.create(need=need, **_filter_model_fields(VehicleNeed, detail_data))
    else:
        PropertyNeed.objects.create(need=need, **_filter_model_fields(PropertyNeed, detail_data))

    for criterion in data.get('criteria') or []:
        NeedCriterion.objects.create(need=need, **criterion)
    for image in data.get('images') or []:
        NeedImage.objects.create(need=need, **image)
    if not need.images.exists():
        from apps.needs.services.thumbnails import ensure_need_thumbnail

        ensure_need_thumbnail(need)

    log_audit_event(
        actor_user=buyer,
        action='NEED_CREATED',
        entity='Need',
        entity_id=need.id,
    )
    return need


@transaction.atomic
def publish_need(need: Need, buyer, *, legal_accepted: bool = True) -> Need:
    if need.buyer_id != buyer.id:
        raise PermissionError('No puedes publicar esta necesidad')
    if need.status != NeedStatus.DRAFT:
        raise ValidationError('Solo se puede publicar desde DRAFT')
    if not legal_accepted:
        raise ValidationError('Debes aceptar la cláusula de responsabilidad')
    if not buyer.can_publish:
        raise UserNotVerifiedError()

    _validate_budget_ratio(need.budget_max_cop)
    _sync_structural_criteria(need)
    days = get_setting('NEED_DURATION_DAYS', 30)
    need.status = NeedStatus.ACTIVE
    need.expires_at = timezone.now() + timedelta(days=days)
    need.legal_disclaimer_accepted_at = timezone.now()
    need.save(
        update_fields=[
            'status',
            'expires_at',
            'legal_disclaimer_accepted_at',
            'updated_at',
        ]
    )
    log_audit_event(
        actor_user=buyer,
        action='NEED_PUBLISHED',
        entity='Need',
        entity_id=need.id,
    )
    from apps.matching.tasks import run_match_for_need_task

    run_match_for_need_task.delay(str(need.id))
    return need


@transaction.atomic
def update_need(need: Need, buyer, data: dict) -> Need:
    if need.buyer_id != buyer.id:
        raise PermissionError()
    if need.status in (NeedStatus.DELETED, NeedStatus.EXPIRED, NeedStatus.FULFILLED):
        raise ValidationError('No se puede editar en este estado')

    rematch = False
    for field in (
        'title',
        'description',
        'budget_max_cop',
        'payment_type',
        'city',
        'location',
    ):
        if field in data:
            setattr(need, field, data[field])
            if field in ('budget_max_cop', 'location', 'city'):
                rematch = True
    need.save()

    if 'criteria' in data:
        need.criteria.all().delete()
        for criterion in data['criteria']:
            NeedCriterion.objects.create(need=need, **criterion)
        rematch = True

    log_audit_event(
        actor_user=buyer,
        action='NEED_UPDATED',
        entity='Need',
        entity_id=need.id,
    )
    if rematch and need.status == NeedStatus.ACTIVE:
        from apps.matching.tasks import run_match_for_need_task

        run_match_for_need_task.delay(str(need.id))
    return need


@transaction.atomic
def pause_need(need: Need, buyer) -> Need:
    if need.buyer_id != buyer.id:
        raise PermissionError()
    if need.status != NeedStatus.ACTIVE:
        raise ValidationError('Solo se pausan necesidades ACTIVE')
    need.status = NeedStatus.PAUSED
    need.save(update_fields=['status', 'updated_at'])
    log_audit_event(actor_user=buyer, action='NEED_PAUSED', entity='Need', entity_id=need.id)
    return need


@transaction.atomic
def resume_need(need: Need, buyer) -> Need:
    if need.buyer_id != buyer.id:
        raise PermissionError()
    if need.status != NeedStatus.PAUSED:
        raise ValidationError('Solo se reanudan necesidades PAUSED')
    need.status = NeedStatus.ACTIVE
    need.save(update_fields=['status', 'updated_at'])
    log_audit_event(actor_user=buyer, action='NEED_RESUMED', entity='Need', entity_id=need.id)
    from apps.matching.tasks import run_match_for_need_task

    run_match_for_need_task.delay(str(need.id))
    return need


@transaction.atomic
def delete_need(need: Need, buyer) -> Need:
    if need.buyer_id != buyer.id:
        raise PermissionError()
    need.status = NeedStatus.DELETED
    need.save(update_fields=['status', 'updated_at'])
    log_audit_event(actor_user=buyer, action='NEED_DELETED', entity='Need', entity_id=need.id)
    return need


@transaction.atomic
def renew_need(need: Need, buyer) -> Need:
    if need.buyer_id != buyer.id:
        raise PermissionError('No puedes renovar esta necesidad')
    if need.status not in (NeedStatus.ACTIVE, NeedStatus.PAUSED):
        raise ValidationError('Solo se pueden renovar necesidades activas o pausadas')
    if not need.expires_at:
        raise ValidationError('La necesidad no tiene fecha de vencimiento')

    now = timezone.now()
    days_left = (need.expires_at - now).total_seconds() / 86400
    if days_left > 5:
        raise ValidationError('La renovación solo está disponible desde 5 días antes del vencimiento')

    days = get_setting('NEED_DURATION_DAYS', 30)
    need.expires_at = now + timedelta(days=days)
    need.renewal_reminder_sent_at = None
    if need.status == NeedStatus.PAUSED:
        need.status = NeedStatus.ACTIVE
    need.save(
        update_fields=['expires_at', 'renewal_reminder_sent_at', 'status', 'updated_at']
    )
    log_audit_event(
        actor_user=buyer,
        action='NEED_RENEWED',
        entity='Need',
        entity_id=need.id,
        metadata={'new_expires_at': need.expires_at.isoformat(), 'days': days},
    )
    from apps.matching.tasks import run_match_for_need_task

    run_match_for_need_task.delay(str(need.id))
    return need


def expire_stale_needs() -> int:
    now = timezone.now()
    qs = Need.objects.filter(status=NeedStatus.ACTIVE, expires_at__lt=now)
    count = qs.update(status=NeedStatus.EXPIRED)
    return count


def notify_needs_expiring_soon() -> int:
    from apps.common.constants import NotificationChannel
    from apps.notifications.services.dispatcher import dispatch

    now = timezone.now()
    target_date = (now + timedelta(days=5)).date()
    qs = (
        Need.objects.filter(
            status__in=(NeedStatus.ACTIVE, NeedStatus.PAUSED),
            expires_at__date=target_date,
            renewal_reminder_sent_at__isnull=True,
        )
        .select_related('buyer')
    )
    sent = 0
    for need in qs:
        days = get_setting('NEED_DURATION_DAYS', 30)
        dispatch(
            need.buyer,
            'NEED_EXPIRING_SOON',
            title='Tu publicación vence pronto',
            body=(
                f'“{need.title}” vence en 5 días. Renovala ahora y sumá {days} días más.'
            ),
            channel=NotificationChannel.PUSH,
            payload={
                'need_id': str(need.id),
                'expires_at': need.expires_at.isoformat() if need.expires_at else None,
                'action': 'renew_need',
            },
        )
        need.renewal_reminder_sent_at = now
        need.save(update_fields=['renewal_reminder_sent_at', 'updated_at'])
        sent += 1
    return sent
