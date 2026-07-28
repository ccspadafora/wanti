from celery import shared_task

from apps.common.constants import MatchStatus, NotificationChannel
from apps.contacts.models import ContactUnlock
from apps.disputes.models import Dispute
from apps.needs.models import Need
from apps.notifications.services.dispatcher import dispatch


@shared_task(name='apps.notifications.tasks.notify_matches')
def notify_matches(need_id):
    need = Need.objects.get(id=need_id)
    matches = need.matches.filter(status=MatchStatus.GENERATED)
    if not matches.exists():
        return
    dispatch(
        need.buyer,
        'MATCH_NEW_FOR_BUYER',
        body=f'Tenés {matches.count()} nuevos matches para {need.title}',
    )
    for match in matches:
        dispatch(
            match.seller,
            'MATCH_NEW_FOR_SELLER',
            body=f'Un comprador busca algo como tu {match.inventory_item.title}',
            payload={'match_id': str(match.id)},
        )


@shared_task(name='apps.notifications.tasks.notify_contact_unlocked')
def notify_contact_unlocked(unlock_id):
    unlock = ContactUnlock.objects.get(id=unlock_id)
    dispatch(
        unlock.seller,
        'CONTACT_UNLOCKED_TO_SELLER',
        channel=NotificationChannel.PUSH,
        body='Un comprador desbloqueó tu contacto',
        payload={'unlock_id': str(unlock.id)},
    )


@shared_task(name='apps.notifications.tasks.notify_dispute_auto_ping')
def notify_dispute_auto_ping(dispute_id):
    dispute = Dispute.objects.select_related('contact_unlock__buyer').get(id=dispute_id)
    buyer = dispute.contact_unlock.buyer
    dispatch(
        buyer,
        'DISPUTE_AUTO_PING',
        body='¿Completaste la compra con este vendedor?',
        payload={'dispute_id': str(dispute.id)},
    )


@shared_task(name='apps.notifications.tasks.notify_review_pending')
def notify_review_pending(unlock_id):
    unlock = ContactUnlock.objects.select_related('buyer', 'seller').get(id=unlock_id)
    for user in (unlock.buyer, unlock.seller):
        dispatch(
            user,
            'REVIEW_PENDING',
            body='Calificá tu experiencia en Wanti',
            payload={'unlock_id': str(unlock.id)},
        )


@shared_task(name='apps.notifications.tasks.notify_dispute_resolved')
def notify_dispute_resolved(dispute_id):
    dispute = Dispute.objects.select_related(
        'contact_unlock__buyer', 'contact_unlock__seller', 'opened_by'
    ).get(id=dispute_id)
    for user in {
        dispute.opened_by,
        dispute.contact_unlock.buyer,
        dispute.contact_unlock.seller,
    }:
        dispatch(
            user,
            'DISPUTE_RESOLVED',
            body=f'Tu disputa fue resuelta: {dispute.status}',
            channel=NotificationChannel.EMAIL,
            payload={'dispute_id': str(dispute.id), 'status': dispute.status},
        )
