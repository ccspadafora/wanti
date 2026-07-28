import hashlib
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.authn.models import PhoneOtp
from apps.common.constants import OtpChannel, UserStatus
from apps.common.exceptions import OtpInvalidError
from apps.common.integrations.twilio.otp import send_otp_via_twilio
from apps.common.services.settings_service import get_setting


def _hash_code(code: str) -> str:
    salted = f'{code}{settings.SECRET_KEY}'
    return hashlib.sha256(salted.encode()).hexdigest()


def request_otp(user, channel=OtpChannel.WHATSAPP, new_phone=None) -> tuple[PhoneOtp, str]:
    PhoneOtp.objects.filter(user=user, verified_at__isnull=True).update(
        expires_at=timezone.now()
    )
    code = f'{secrets.randbelow(1_000_000):06d}'
    ttl = get_setting('OTP_TTL_SECONDS', 300)
    context = {'new_phone': new_phone} if new_phone else {}
    otp = PhoneOtp.objects.create(
        user=user,
        code_hash=_hash_code(code),
        channel=channel,
        expires_at=timezone.now() + timedelta(seconds=ttl),
        context=context,
    )
    target_phone = new_phone or user.phone
    send_otp_via_twilio(target_phone, code, channel)
    log_audit_event(
        actor_user=user,
        action='OTP_SENT',
        entity='User',
        entity_id=user.id,
        metadata={'channel': channel},
    )
    return otp, code


@transaction.atomic
def verify_otp(user, code: str) -> None:
    otp = (
        PhoneOtp.objects.filter(user=user, verified_at__isnull=True)
        .order_by('-created_at')
        .first()
    )
    if otp is None:
        raise OtpInvalidError('No hay un OTP activo')
    if otp.expires_at < timezone.now():
        raise OtpInvalidError('OTP expirado')

    max_attempts = get_setting('OTP_MAX_ATTEMPTS', 5)
    if otp.attempts >= max_attempts:
        raise OtpInvalidError('Demasiados intentos fallidos')

    if _hash_code(code) != otp.code_hash:
        otp.attempts += 1
        otp.save(update_fields=['attempts', 'updated_at'])
        raise OtpInvalidError('Código incorrecto')

    otp.verified_at = timezone.now()
    otp.save(update_fields=['verified_at', 'updated_at'])

    new_phone = (otp.context or {}).get('new_phone')
    update_fields = ['phone_verified_at', 'updated_at']
    if new_phone:
        user.phone = new_phone
        update_fields.append('phone')
    user.phone_verified_at = timezone.now()
    user.save(update_fields=update_fields)

    if user.email_verified_at is not None and user.status == UserStatus.PENDING:
        from apps.users.services.users import activate_user_after_verification

        activate_user_after_verification(user)

    log_audit_event(
        actor_user=user,
        action='OTP_VERIFIED',
        entity='User',
        entity_id=user.id,
    )
