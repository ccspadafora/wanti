from django.db import transaction
from django.db.models import F
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import ContactOutcome, MatchStatus, TransactionType, UserStatus
from apps.common.exceptions import ConflictError, PermissionError, ValidationError
from apps.contacts.models import ContactUnlock
from apps.leads.services.leads import create_lead_from_unlock
from apps.matching.models import Match
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet


@transaction.atomic
def unlock_contact(match: Match, buyer) -> ContactUnlock:
    if match.buyer_id != buyer.id:
        raise PermissionError('Solo el comprador puede desbloquear')
    if buyer.status != UserStatus.ACTIVE:
        raise PermissionError('Cuenta no activa')

    existing = ContactUnlock.objects.filter(match=match).first()
    if existing:
        return existing

    if match.status == MatchStatus.UNLOCKED:
        raise ConflictError('Match ya desbloqueado')

    wallet = get_or_create_wallet(buyer)
    txn = apply_transaction(
        wallet=wallet,
        transaction_type=TransactionType.UNLOCK,
        amount_wantis=-1,
        related_object=match,
        note=f'Desbloqueo {match.inventory_item.title}',
        created_by=buyer,
    )
    unlock = ContactUnlock.objects.create(
        match=match,
        buyer=buyer,
        seller=match.seller,
        wantis_charged=1,
        wallet_transaction=txn,
    )
    match.status = MatchStatus.UNLOCKED
    match.unlocked_at = timezone.now()
    match.save(update_fields=['status', 'unlocked_at', 'updated_at'])
    match.inventory_item.__class__.objects.filter(pk=match.inventory_item_id).update(
        unlock_count=F('unlock_count') + 1
    )
    create_lead_from_unlock(unlock)
    log_audit_event(
        actor_user=buyer,
        action='CONTACT_UNLOCKED',
        entity='ContactUnlock',
        entity_id=unlock.id,
    )
    from apps.notifications.tasks import notify_contact_unlocked

    notify_contact_unlocked.delay(str(unlock.id))
    return unlock


def mark_whatsapp_opened(unlock: ContactUnlock, actor) -> ContactUnlock:
    if actor.id not in (unlock.buyer_id, unlock.seller_id):
        raise PermissionError()
    if unlock.whatsapp_opened_at is None:
        unlock.whatsapp_opened_at = timezone.now()
        unlock.save(update_fields=['whatsapp_opened_at', 'updated_at'])
    return unlock


@transaction.atomic
def report_outcome(unlock: ContactUnlock, buyer, outcome: str) -> ContactUnlock:
    if unlock.buyer_id != buyer.id:
        raise PermissionError()
    if outcome not in ContactOutcome.values:
        raise ValidationError('Outcome inválido')
    unlock.outcome = outcome
    unlock.outcome_reported_at = timezone.now()
    unlock.save(update_fields=['outcome', 'outcome_reported_at', 'updated_at'])
    log_audit_event(
        actor_user=buyer,
        action='CONTACT_OUTCOME_REPORTED',
        entity='ContactUnlock',
        entity_id=unlock.id,
        metadata={'outcome': outcome},
    )
    if outcome in (ContactOutcome.PURCHASED, ContactOutcome.NOT_PURCHASED):
        from apps.notifications.tasks import notify_review_pending

        notify_review_pending.delay(str(unlock.id))
    return unlock
