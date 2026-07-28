import logging

logger = logging.getLogger(__name__)


def send_otp_via_twilio(phone: str, code: str, channel: str) -> None:
    from django.conf import settings

    enabled = str(getattr(settings, "TWILIO_ENABLED", False)).lower() in (
        "1",
        "true",
        "yes",
    )
    if not enabled:
        logger.info("OTP stub → phone=%s channel=%s code=%s", phone, channel, code)
        return
    from apps.common.integrations.twilio.client import get_twilio_client

    client = get_twilio_client()
    logger.info("Twilio OTP enviado a %s vía %s", phone, channel)
    _ = client
