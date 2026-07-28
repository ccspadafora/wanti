import logging
from django.utils import timezone

logger = logging.getLogger(__name__)


def send_push(notification) -> None:
    notification.delivery_status = notification.DeliveryStatus.SENT
    notification.sent_at = timezone.now()
    notification.provider_reference = f"db-logger-{notification.id}"
    notification.save(
        update_fields=["delivery_status", "sent_at", "provider_reference", "updated_at"]
    )
    logger.info(
        "Push mock → user=%s template=%s",
        notification.recipient_id,
        notification.template_code,
    )
