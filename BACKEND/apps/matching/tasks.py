from celery import shared_task

from apps.matching.services.engine import run_match_for_item, run_match_for_need


@shared_task(name='apps.matching.tasks.run_match_for_need_task')
def run_match_for_need_task(need_id):
    return run_match_for_need(need_id)


@shared_task(name='apps.matching.tasks.run_match_for_item_task')
def run_match_for_item_task(item_id):
    return run_match_for_item(item_id)
