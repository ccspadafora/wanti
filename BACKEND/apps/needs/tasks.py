from celery import shared_task

from apps.needs.services.needs import (
    expire_stale_needs as _expire,
    notify_needs_expiring_soon as _notify,
)


@shared_task(name='apps.needs.tasks.expire_stale_needs')
def expire_stale_needs():
    return {'expired': _expire()}


@shared_task(name='apps.needs.tasks.notify_needs_expiring_soon')
def notify_needs_expiring_soon():
    return {'notified': _notify()}
