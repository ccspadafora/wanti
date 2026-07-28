from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import LeadStage
from apps.common.exceptions import PermissionError, ValidationError
from apps.common.services.settings_service import get_setting
from apps.leads.models import Lead, LeadNote


@transaction.atomic
def create_lead_from_unlock(contact_unlock) -> Lead:
    days = get_setting('LEAD_EXPIRY_DAYS', 30)
    now = timezone.now()
    lead, _ = Lead.objects.get_or_create(
        contact_unlock=contact_unlock,
        defaults={
            'seller': contact_unlock.seller,
            'buyer': contact_unlock.buyer,
            'stage': LeadStage.NEW,
            'expires_at': now + timedelta(days=days),
        },
    )
    return lead


@transaction.atomic
def change_stage(lead: Lead, seller, stage: str, sold_price_cop=None) -> Lead:
    if lead.seller_id != seller.id:
        raise PermissionError()
    if stage not in LeadStage.values:
        raise ValidationError('Stage inválido')
    lead.stage = stage
    lead.last_activity_at = timezone.now()
    days = get_setting('LEAD_EXPIRY_DAYS', 30)
    lead.expires_at = lead.last_activity_at + timedelta(days=days)
    if stage == LeadStage.PURCHASED and sold_price_cop is not None:
        lead.sold_price_cop = sold_price_cop
    lead.save()
    log_audit_event(
        actor_user=seller,
        action='LEAD_STAGE_CHANGED',
        entity='Lead',
        entity_id=lead.id,
        metadata={'stage': stage},
    )
    return lead


@transaction.atomic
def add_note(lead: Lead, author, text: str) -> LeadNote:
    if lead.seller_id != author.id:
        raise PermissionError()
    note = LeadNote.objects.create(
        lead=lead,
        author=author,
        text=text,
        stage_at_time=lead.stage,
    )
    lead.last_activity_at = timezone.now()
    days = get_setting('LEAD_EXPIRY_DAYS', 30)
    lead.expires_at = lead.last_activity_at + timedelta(days=days)
    lead.save(update_fields=['last_activity_at', 'expires_at', 'updated_at'])
    return note


def expire_stale_leads() -> int:
    now = timezone.now()
    return Lead.objects.filter(
        expires_at__lt=now,
        stage__in=[LeadStage.NEW, LeadStage.IN_NEGOTIATION, LeadStage.TO_VISIT],
    ).update(stage=LeadStage.EXPIRED)
