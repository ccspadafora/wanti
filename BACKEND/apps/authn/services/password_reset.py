import secrets
from datetime import timedelta
from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from apps.audit.services.audit_log import log_audit_event
from apps.authn.models import PasswordResetToken
from apps.common.exceptions import ValidationError
from apps.users.selectors.users import get_user_by_email


def request_password_reset(email: str, ip_address=None):
    user = get_user_by_email(email)
    if user is None:
        return None
    PasswordResetToken.objects.filter(user=user, used_at__isnull=True).update(
        expires_at=timezone.now()
    )
    token = PasswordResetToken.objects.create(
        user=user,
        token=secrets.token_urlsafe(48)[:64],
        expires_at=timezone.now() + timedelta(hours=2),
        requested_ip=ip_address,
    )
    reset_url = f"{settings.FRONTEND_BASE_URL}/auth/reset-password?token={token.token}"
    send_mail(
        subject="Restablecé tu contraseña en Wanti",
        message=f"Restablecé tu contraseña: {reset_url}",
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        fail_silently=True,
    )
    log_audit_event(
        actor_user=user,
        action="PASSWORD_RESET_REQUESTED",
        entity="User",
        entity_id=user.id,
        ip_address=ip_address,
    )
    return token.token


@transaction.atomic
def confirm_password_reset(token_str: str, new_password: str):
    try:
        token = PasswordResetToken.objects.select_related("user").get(token=token_str)
    except PasswordResetToken.DoesNotExist as exc:
        raise ValidationError("Token inválido") from exc
    if token.used_at is not None:
        raise ValidationError("Token ya usado")
    if token.expires_at < timezone.now():
        raise ValidationError("Token expirado")
    user = token.user
    user.set_password(new_password)
    user.last_login_at = None
    user.save(update_fields=["password", "last_login_at", "updated_at"])
    token.used_at = timezone.now()
    token.save(update_fields=["used_at", "updated_at"])
    PasswordResetToken.objects.filter(user=user, used_at__isnull=True).exclude(
        pk=token.pk
    ).update(expires_at=timezone.now())
    try:
        from rest_framework_simplejwt.token_blacklist.models import (
            BlacklistedToken,
            OutstandingToken,
        )

        for outstanding in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=outstanding)
    except Exception:
        pass
    log_audit_event(
        actor_user=user,
        action="PASSWORD_RESET_COMPLETED",
        entity="User",
        entity_id=user.id,
    )
    return user
