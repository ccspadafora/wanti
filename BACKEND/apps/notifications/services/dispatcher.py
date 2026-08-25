from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone

from apps.common.constants import NotificationChannel
from apps.common.integrations.push.onesignal import send_push
from apps.notifications.models import Notification


def dispatch(
    recipient,
    template_code: str,
    *,
    body: str,
    title: str = '',
    channel=NotificationChannel.PUSH,
    payload=None,
) -> Notification:
    notification = Notification.objects.create(
        recipient=recipient,
        channel=channel,
        template_code=template_code,
        title=title,
        body=body,
        payload=payload or {},
    )
    if channel == NotificationChannel.PUSH:
        send_push(notification)
    elif channel == NotificationChannel.EMAIL:
        _send_email(notification)
    else:
        notification.delivery_status = Notification.DeliveryStatus.SENT
        notification.sent_at = timezone.now()
        notification.save(update_fields=['delivery_status', 'sent_at', 'updated_at'])
    return notification


def _send_email(notification: Notification) -> None:
    send_mail(
        subject=notification.title or notification.template_code,
        message=notification.body,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[notification.recipient.email],
        fail_silently=True,
    )
    notification.delivery_status = Notification.DeliveryStatus.SENT
    notification.sent_at = timezone.now()
    notification.save(update_fields=['delivery_status', 'sent_at', 'updated_at'])
