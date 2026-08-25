from django.db import IntegrityError, transaction
from django.db.models import F
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import ContactOutcome, MatchStatus, TransactionType, UserStatus
from apps.common.exceptions import ConflictError, PermissionError, ValidationError
from apps.contacts.models import ContactUnlock
from apps.leads.services.leads import create_lead_from_unlock
from apps.matching.models import Match
from apps.wallet.models import WalletTransaction
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet


def unlock_contact(
    match: Match,
    actor,
    *,
    idempotency_key: str | None = None,
) -> tuple[ContactUnlock, bool]:
    """
    Solo el vendedor gasta Wanti para desbloquear el contacto del comprador.
    Retorna (unlock, created). Reintentos / carrera no cobran dos veces.
    """
    with transaction.atomic():
        is_seller = match.seller_id == actor.id
        if not is_seller:
            raise PermissionError(
                'Solo el vendedor puede desbloquear el contacto gastando Wanti'
            )
        if actor.status != UserStatus.ACTIVE:
            raise PermissionError('Cuenta no activa')

        # Serializa unlocks concurrentes del mismo match
        locked = Match.objects.select_for_update().select_related(
            'buyer', 'seller', 'inventory_item'
        ).get(pk=match.pk)

        existing = ContactUnlock.objects.filter(match_id=locked.id).first()
        if existing:
            return existing, False

        key = (idempotency_key or '').strip() or None
        if key:
            prior_txn = WalletTransaction.objects.filter(idempotency_key=key).first()
            if prior_txn is not None:
                linked = ContactUnlock.objects.filter(wallet_transaction=prior_txn).first()
                if linked:
                    return linked, False

        if locked.status == MatchStatus.UNLOCKED:
            # Estado inconsistente raro: marcado UNLOCKED sin fila ContactUnlock
            raise ConflictError('Match ya desbloqueado')

        title = locked.inventory_item.title
        note = f'Desbloqueo de {locked.buyer.full_name} · {title}'

        wallet = get_or_create_wallet(actor)
        txn = apply_transaction(
            wallet=wallet,
            transaction_type=TransactionType.UNLOCK,
            amount_wantis=-1,
            related_object=locked,
            note=note,
            created_by=actor,
            idempotency_key=key,
        )

        linked = ContactUnlock.objects.filter(wallet_transaction=txn).first()
        if linked:
            return linked, False

        try:
            unlock = ContactUnlock.objects.create(
                match=locked,
                buyer=locked.buyer,
                seller=locked.seller,
                wantis_charged=1,
                wallet_transaction=txn,
            )
        except IntegrityError:
            existing = ContactUnlock.objects.filter(match_id=locked.id).first()
            if existing:
                return existing, False
            raise

        locked.status = MatchStatus.UNLOCKED
        locked.unlocked_at = timezone.now()
        locked.save(update_fields=['status', 'unlocked_at', 'updated_at'])
        locked.inventory_item.__class__.objects.filter(pk=locked.inventory_item_id).update(
            unlock_count=F('unlock_count') + 1
        )
        create_lead_from_unlock(unlock)
        log_audit_event(
            actor_user=actor,
            action='CONTACT_UNLOCKED',
            entity='ContactUnlock',
            entity_id=unlock.id,
            metadata={'unlocked_by': 'seller', 'idempotency_key': key},
        )
        from apps.notifications.tasks import notify_contact_unlocked

        notify_contact_unlocked.delay(str(unlock.id))
        return unlock, True


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
