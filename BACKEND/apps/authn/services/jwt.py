from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import UserStatus
from apps.common.exceptions import PermissionError, ValidationError
from apps.users.selectors.users import get_user_by_email


def issue_tokens_for_user(user) -> dict:
    from rest_framework_simplejwt.tokens import RefreshToken

    refresh = RefreshToken.for_user(user)
    refresh['role'] = user.role
    refresh['fully_verified'] = user.is_fully_verified
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}


def login_user(*, email: str, password: str, ip_address=None) -> dict:
    user = get_user_by_email(email)
    if user is None or not user.check_password(password):
        if user is not None:
            log_audit_event(
                actor_user=user,
                action='LOGIN_FAILED',
                entity='User',
                entity_id=user.id,
                ip_address=ip_address,
            )
        raise ValidationError('Credenciales inválidas')

    if user.status == UserStatus.SUSPENDED:
        log_audit_event(
            actor_user=user,
            action='LOGIN_BLOCKED_SUSPENDED',
            entity='User',
            entity_id=user.id,
            ip_address=ip_address,
        )
        raise PermissionError('Cuenta suspendida')

    user.last_login_at = timezone.now()
    user.last_login = timezone.now()
    user.save(update_fields=['last_login_at', 'last_login', 'updated_at'])
    tokens = issue_tokens_for_user(user)
    log_audit_event(
        actor_user=user,
        action='LOGIN_SUCCESS',
        entity='User',
        entity_id=user.id,
        ip_address=ip_address,
    )
    return {'user': user, **tokens}
