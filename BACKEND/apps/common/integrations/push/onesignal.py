"""OneSignal REST push provider."""

from __future__ import annotations

import logging

import requests
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


def _enabled() -> bool:
    return bool(
        getattr(settings, 'ONESIGNAL_ENABLED', False)
        and getattr(settings, 'ONESIGNAL_APP_ID', '')
        and getattr(settings, 'ONESIGNAL_REST_API_KEY', '')
    )


def send_push(notification) -> None:
    """
    Envía push vía OneSignal usando external_id = UUID del usuario.
    Si OneSignal no está configurado, marca SENT en modo mock (db-logger).
    """
    if not _enabled():
        from apps.common.integrations.push.db_logger import send_push as mock_send

        mock_send(notification)
        return

    app_id = settings.ONESIGNAL_APP_ID
    api_key = settings.ONESIGNAL_REST_API_KEY
    external_id = str(notification.recipient_id)
    title = (notification.title or notification.template_code or 'Wanti').strip()
    body = (notification.body or '').strip() or title
    data = {
        'template_code': notification.template_code,
        'notification_id': str(notification.id),
        **(notification.payload or {}),
    }

    payload = {
        'app_id': app_id,
        'target_channel': 'push',
        'include_aliases': {'external_id': [external_id]},
        'headings': {'en': title, 'es': title},
        'contents': {'en': body, 'es': body},
        'data': {k: str(v) for k, v in data.items()},
    }

    try:
        res = requests.post(
            'https://api.onesignal.com/notifications',
            headers={
                'Authorization': f'Key {api_key}',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
            json=payload,
            timeout=15,
        )
        if res.status_code >= 400:
            notification.delivery_status = notification.DeliveryStatus.FAILED
            notification.error_message = (res.text or '')[:2000]
            notification.save(
                update_fields=['delivery_status', 'error_message', 'updated_at']
            )
            logger.warning(
                'OneSignal push failed user=%s status=%s body=%s',
                external_id,
                res.status_code,
                res.text[:300],
            )
            return

        body_json = {}
        try:
            body_json = res.json()
        except Exception:
            body_json = {}
        notification.delivery_status = notification.DeliveryStatus.SENT
        notification.sent_at = timezone.now()
        notification.provider_reference = str(
            body_json.get('id') or body_json.get('notification_id') or ''
        )[:120]
        notification.error_message = ''
        notification.save(
            update_fields=[
                'delivery_status',
                'sent_at',
                'provider_reference',
                'error_message',
                'updated_at',
            ]
        )
    except requests.RequestException as exc:
        notification.delivery_status = notification.DeliveryStatus.FAILED
        notification.error_message = str(exc)[:2000]
        notification.save(
            update_fields=['delivery_status', 'error_message', 'updated_at']
        )
        logger.exception('OneSignal request error user=%s', external_id)
