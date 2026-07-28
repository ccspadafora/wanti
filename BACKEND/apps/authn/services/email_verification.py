import secrets
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.authn.models import EmailVerificationToken
from apps.common.constants import UserStatus
from apps.common.exceptions import ValidationError
from apps.users.models import User


def send_verification_email(user, new_email=None) -> EmailVerificationToken:
    EmailVerificationToken.objects.filter(user=user, used_at__isnull=True).update(
        expires_at=timezone.now()
    )
    context = {'new_email': new_email} if new_email else {}
    token = EmailVerificationToken.objects.create(
        user=user,
        token=secrets.token_urlsafe(48)[:64],
        expires_at=timezone.now() + timedelta(hours=24),
        context=context,
    )
    target_email = new_email or user.email
    verify_url = f'{settings.FRONTEND_BASE_URL}/auth/verify-email?token={token.token}'
    send_mail(
        subject='Verifica tu correo en Wanti',
        message=f'Confirma tu correo: {verify_url}',
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[target_email],
        fail_silently=True,
    )
    log_audit_event(
        actor_user=user,
        action='EMAIL_VERIFICATION_SENT',
        entity='User',
        entity_id=user.id,
    )
    return token


@transaction.atomic
def verify_email_token(token_str: str) -> User:
    try:
        token = EmailVerificationToken.objects.select_related('user').get(token=token_str)
    except EmailVerificationToken.DoesNotExist as exc:
        raise ValidationError('Token inválido') from exc
    if token.used_at is not None:
        raise ValidationError('Token ya usado')
    if token.expires_at < timezone.now():
        raise ValidationError('Token expirado')

    user = token.user
    new_email = (token.context or {}).get('new_email')
    if new_email:
        user.email = new_email
    user.email_verified_at = timezone.now()
    user.save(update_fields=['email', 'email_verified_at', 'updated_at'])
    token.used_at = timezone.now()
    token.save(update_fields=['used_at', 'updated_at'])

    if user.phone_verified_at is not None and user.status == UserStatus.PENDING:
        from apps.users.services.users import activate_user_after_verification

        activate_user_after_verification(user)

    log_audit_event(
        actor_user=user,
        action='EMAIL_VERIFIED',
        entity='User',
        entity_id=user.id,
    )
    return user
