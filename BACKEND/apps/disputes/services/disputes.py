from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import DisputeStatus, TransactionType
from apps.common.exceptions import ConflictError, DisputeStateError, PermissionError
from apps.common.services.settings_service import get_setting
from apps.contacts.models import ContactUnlock
from apps.disputes.models import Dispute, DisputeEvent
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet


def _add_event(dispute, event_type, actor=None, payload=None):
    return DisputeEvent.objects.create(
        dispute=dispute,
        event_type=event_type,
        actor=actor,
        payload=payload or {},
    )


@transaction.atomic
def open_dispute(contact_unlock: ContactUnlock, opened_by, reason: str, description='') -> Dispute:
    if opened_by.id not in (contact_unlock.buyer_id, contact_unlock.seller_id):
        raise PermissionError()
    active = Dispute.objects.filter(
        contact_unlock=contact_unlock,
        status__in=[
            DisputeStatus.OPEN,
            DisputeStatus.AUTO_REVIEW,
            DisputeStatus.HUMAN_REVIEW,
            DisputeStatus.APPEALED,
        ],
    ).exists()
    if active:
        raise ConflictError('Ya existe una disputa activa para este desbloqueo')

    dispute = Dispute.objects.create(
        contact_unlock=contact_unlock,
        opened_by=opened_by,
        reason=reason,
        description=description,
        status=DisputeStatus.OPEN,
    )
    _add_event(dispute, 'OPENED', actor=opened_by)
    log_audit_event(
        actor_user=opened_by,
        action='DISPUTE_OPENED',
        entity='Dispute',
        entity_id=dispute.id,
    )
    from apps.disputes.tasks import start_auto_review

    start_auto_review.delay(str(dispute.id))
    return dispute


@transaction.atomic
def start_auto_review(dispute_id) -> Dispute:
    dispute = Dispute.objects.select_for_update().select_related('contact_unlock').get(
        pk=dispute_id
    )
    hours = get_setting('DISPUTE_AUTO_TIMEOUT_HOURS', 72)
    dispute.status = DisputeStatus.AUTO_REVIEW
    dispute.auto_review_started_at = timezone.now()
    dispute.auto_review_deadline = timezone.now() + timedelta(hours=hours)
    dispute.save(
        update_fields=[
            'status',
            'auto_review_started_at',
            'auto_review_deadline',
            'updated_at',
        ]
    )
    _add_event(dispute, 'AUTO_PING_SENT')
    from apps.notifications.tasks import notify_dispute_auto_ping

    notify_dispute_auto_ping.delay(str(dispute.id))
    return dispute


@transaction.atomic
def buyer_responds_auto_review(dispute: Dispute, buyer, confirmed_purchase: bool) -> Dispute:
    if dispute.contact_unlock.buyer_id != buyer.id:
        raise PermissionError()
    if dispute.status != DisputeStatus.AUTO_REVIEW:
        raise DisputeStateError()
    dispute.buyer_confirmed_purchase = confirmed_purchase
    dispute.save(update_fields=['buyer_confirmed_purchase', 'updated_at'])
    _add_event(
        dispute,
        'BUYER_RESPONDED',
        actor=buyer,
        payload={'confirmed_purchase': confirmed_purchase},
    )
    if confirmed_purchase:
        return _reject_dispute(dispute, actor=None, note='Comprador confirmó la compra')
    return _escalate_to_human(dispute)


def _escalate_to_human(dispute: Dispute) -> Dispute:
    dispute.status = DisputeStatus.HUMAN_REVIEW
    dispute.escalated_at = timezone.now()
    dispute.save(update_fields=['status', 'escalated_at', 'updated_at'])
    _add_event(dispute, 'ESCALATED')
    return dispute


@transaction.atomic
def approve_dispute(dispute: Dispute, admin_user, resolution_note='') -> Dispute:
    if dispute.status not in (DisputeStatus.HUMAN_REVIEW, DisputeStatus.APPEALED):
        raise DisputeStateError()
    unlock = dispute.contact_unlock
    wallet = get_or_create_wallet(unlock.buyer)
    refund_txn = apply_transaction(
        wallet=wallet,
        transaction_type=TransactionType.REFUND,
        amount_wantis=unlock.wantis_charged,
        related_object=dispute,
        note=f'Reembolso disputa {dispute.id}',
        created_by=admin_user,
    )
    appeal_days = get_setting('DISPUTE_APPEAL_DAYS', 7)
    dispute.status = DisputeStatus.APPROVED
    dispute.resolved_at = timezone.now()
    dispute.resolved_by = admin_user
    dispute.resolution_note = resolution_note
    dispute.refund_transaction = refund_txn
    dispute.appeal_deadline = timezone.now() + timedelta(days=appeal_days)
    dispute.save()
    _add_event(dispute, 'RESOLVED', actor=admin_user, payload={'result': 'APPROVED'})
    log_audit_event(
        actor_user=admin_user,
        action='DISPUTE_RESOLVED',
        entity='Dispute',
        entity_id=dispute.id,
        metadata={'result': 'APPROVED'},
    )
    from apps.notifications.tasks import notify_dispute_resolved

    notify_dispute_resolved.delay(str(dispute.id))
    return dispute


def _reject_dispute(dispute: Dispute, actor=None, note='') -> Dispute:
    appeal_days = get_setting('DISPUTE_APPEAL_DAYS', 7)
    dispute.status = DisputeStatus.REJECTED
    dispute.resolved_at = timezone.now()
    dispute.resolved_by = actor
    dispute.resolution_note = note
    dispute.appeal_deadline = timezone.now() + timedelta(days=appeal_days)
    dispute.save()
    _add_event(dispute, 'RESOLVED', actor=actor, payload={'result': 'REJECTED'})
    from apps.notifications.tasks import notify_dispute_resolved

    notify_dispute_resolved.delay(str(dispute.id))
    return dispute


@transaction.atomic
def reject_dispute(dispute: Dispute, admin_user, resolution_note='') -> Dispute:
    if dispute.status not in (DisputeStatus.HUMAN_REVIEW, DisputeStatus.APPEALED):
        raise DisputeStateError()
    return _reject_dispute(dispute, actor=admin_user, note=resolution_note)


@transaction.atomic
def cancel_dispute(dispute: Dispute, actor) -> Dispute:
    if dispute.opened_by_id != actor.id:
        raise PermissionError()
    if dispute.status not in (DisputeStatus.OPEN, DisputeStatus.AUTO_REVIEW):
        raise DisputeStateError()
    dispute.status = DisputeStatus.CANCELLED
    dispute.save(update_fields=['status', 'updated_at'])
    _add_event(dispute, 'CANCELLED', actor=actor)
    return dispute


@transaction.atomic
def appeal_dispute(dispute: Dispute, actor, reason: str = '') -> Dispute:
    unlock = dispute.contact_unlock
    if actor.id not in (unlock.buyer_id, unlock.seller_id):
        raise PermissionError()
    if dispute.status not in (DisputeStatus.APPROVED, DisputeStatus.REJECTED):
        raise DisputeStateError()
    if not dispute.appeal_deadline or timezone.now() > dispute.appeal_deadline:
        raise DisputeStateError('Plazo de apelación vencido')
    dispute.status = DisputeStatus.APPEALED
    dispute.save(update_fields=['status', 'updated_at'])
    _add_event(dispute, 'APPEALED', actor=actor, payload={'reason': reason})
    log_audit_event(
        actor_user=actor,
        action='DISPUTE_APPEALED',
        entity='Dispute',
        entity_id=dispute.id,
    )
    return dispute


def check_auto_review_timeouts() -> int:
    now = timezone.now()
    qs = Dispute.objects.filter(
        status=DisputeStatus.AUTO_REVIEW,
        auto_review_deadline__lt=now,
    )
    count = 0
    for dispute in qs:
        with transaction.atomic():
            _escalate_to_human(dispute)
            count += 1
    return count
