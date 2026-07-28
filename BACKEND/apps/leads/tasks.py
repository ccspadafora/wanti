from celery import shared_task

from apps.leads.services.leads import expire_stale_leads as _expire


@shared_task(name='apps.leads.tasks.expire_stale_leads')
def expire_stale_leads():
    return {'expired': _expire()}
