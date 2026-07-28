import os

from celery import Celery

os.environ.setdefault(
    'DJANGO_SETTINGS_MODULE',
    os.getenv('DJANGO_SETTINGS_MODULE', 'app.settings.local'),
)

app = Celery('wanti')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

app.conf.task_routes = {
    'apps.notifications.tasks.notify_contact_unlocked': {'queue': 'high'},
    'apps.notifications.tasks.notify_dispute_auto_ping': {'queue': 'high'},
    'apps.matching.tasks.run_match_for_need_task': {'queue': 'high'},
    'apps.matching.tasks.run_match_for_item_task': {'queue': 'default'},
    'apps.notifications.tasks.notify_matches': {'queue': 'default'},
    'apps.notifications.tasks.notify_review_pending': {'queue': 'default'},
    'apps.notifications.tasks.notify_dispute_resolved': {'queue': 'default'},
    'apps.disputes.tasks.start_auto_review': {'queue': 'default'},
    'apps.leads.tasks.expire_stale_leads': {'queue': 'low'},
    'apps.needs.tasks.expire_stale_needs': {'queue': 'low'},
    'apps.needs.tasks.notify_needs_expiring_soon': {'queue': 'default'},
    'apps.wallet.tasks.reconcile_balances': {'queue': 'low'},
    'apps.disputes.tasks.check_auto_review_timeouts': {'queue': 'low'},
}

app.conf.task_default_queue = 'default'
app.conf.task_acks_late = True
app.conf.worker_prefetch_multiplier = 1
