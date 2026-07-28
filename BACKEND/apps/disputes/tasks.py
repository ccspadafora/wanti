from celery import shared_task

from apps.disputes.services import disputes as dispute_services


@shared_task(name='apps.disputes.tasks.start_auto_review')
def start_auto_review(dispute_id):
    return str(dispute_services.start_auto_review(dispute_id).id)


@shared_task(name='apps.disputes.tasks.check_auto_review_timeouts')
def check_auto_review_timeouts():
    return {'escalated': dispute_services.check_auto_review_timeouts()}
