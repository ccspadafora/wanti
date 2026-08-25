from django.db import transaction
from django.utils import timezone

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import UserRole, UserStatus
from apps.common.exceptions import ConflictError, PermissionError, ValidationError
from apps.users.models import User
from apps.users.selectors.users import get_user_by_email, get_user_by_id
from apps.wallet.services.wallet import get_or_create_wallet


PROFILE_WHITELIST = {'city', 'location'}
PROFILE_FORBIDDEN = {
    'email',
    'phone',
    'role',
    'status',
    'id_type',
    'id_number',
    'password',
    'full_name',
    'profile_photo_url',
}


@transaction.atomic
def register_user(data: dict, ip_address=None) -> User:
    from django.conf import settings

    email = (data.get('email') or '').strip().lower()
    if not email:
        raise ValidationError('El email es obligatorio')
    if get_user_by_email(email) is not None:
        raise ConflictError('El email ya está registrado')
    if User.objects.filter(id_type=data['id_type'], id_number=data['id_number']).exists():
        raise ConflictError('El documento de identidad ya está registrado')

    user = User(
        email=email,
        full_name=data['full_name'],
        id_type=data['id_type'],
        id_number=data['id_number'],
        phone=data['phone'],
        city=data['city'],
        status=UserStatus.PENDING,
        role=UserRole.USER,
    )
    if data.get('location') is not None:
        user.location = data['location']
    user.set_password(data['password'])
    if getattr(settings, 'AUTO_VERIFY_EMAIL', False):
        user.email_verified_at = timezone.now()
    user.save()

    get_or_create_wallet(user)

    if not user.email_verified_at:
        from apps.authn.services.email_verification import send_verification_email

        send_verification_email(user)
    else:
        log_audit_event(
            actor_user=user,
            action='EMAIL_AUTO_VERIFIED',
            entity='User',
            entity_id=user.id,
            metadata={'reason': 'AUTO_VERIFY_EMAIL'},
        )

    log_audit_event(
        actor_user=None,
        action='USER_REGISTERED',
        entity='User',
        entity_id=user.id,
        ip_address=ip_address,
    )
    return user


@transaction.atomic
def activate_user_after_verification(user: User) -> User:
    if user.email_verified_at and user.phone_verified_at:
        user.status = UserStatus.ACTIVE
        user.save(update_fields=['status', 'updated_at'])
        get_or_create_wallet(user)
        log_audit_event(
            actor_user=user,
            action='USER_ACTIVATED',
            entity='User',
            entity_id=user.id,
        )
    return user


@transaction.atomic
def update_self_profile(user: User, data: dict) -> User:
    forbidden = PROFILE_FORBIDDEN.intersection(data.keys())
    if forbidden:
        raise ValidationError(f'Campos no permitidos: {", ".join(sorted(forbidden))}')
    unknown = set(data.keys()) - PROFILE_WHITELIST
    if unknown:
        raise ValidationError(f'Campos desconocidos: {", ".join(sorted(unknown))}')

    for field, value in data.items():
        setattr(user, field, value)
    user.save(update_fields=[*data.keys(), 'updated_at'])
    log_audit_event(
        actor_user=user,
        action='USER_UPDATED_SELF',
        entity='User',
        entity_id=user.id,
        metadata={'fields': list(data.keys())},
    )
    return user


def update_email_request(user: User, new_email: str) -> None:
    new_email = new_email.strip().lower()
    if get_user_by_email(new_email) is not None:
        raise ConflictError('El email ya está en uso')
    from apps.authn.services.email_verification import send_verification_email

    send_verification_email(user, new_email=new_email)
    log_audit_event(
        actor_user=user,
        action='USER_EMAIL_CHANGE_REQUESTED',
        entity='User',
        entity_id=user.id,
        metadata={'new_email_domain': new_email.split('@')[-1]},
    )


def update_phone_request(user: User, new_phone: str, channel='WHATSAPP') -> None:
    from apps.authn.services.otp import request_otp

    request_otp(user, channel=channel, new_phone=new_phone)
    log_audit_event(
        actor_user=user,
        action='USER_PHONE_CHANGE_REQUESTED',
        entity='User',
        entity_id=user.id,
    )


@transaction.atomic
def suspend_user(target_user_id, actor_user: User, reason: str) -> User:
    if actor_user.role != UserRole.ADMIN:
        raise PermissionError('Solo administradores pueden suspender')
    target = get_user_by_id(target_user_id)
    target.status = UserStatus.SUSPENDED
    target.save(update_fields=['status', 'updated_at'])
    log_audit_event(
        actor_user=actor_user,
        action='USER_SUSPENDED',
        entity='User',
        entity_id=target.id,
        metadata={'reason': reason, 'actor_id': str(actor_user.id)},
    )
    return target


@transaction.atomic
def activate_user_by_admin(target_user_id, actor_user: User) -> User:
    if actor_user.role != UserRole.ADMIN:
        raise PermissionError('Solo administradores pueden reactivar')
    target = get_user_by_id(target_user_id)
    target.status = UserStatus.ACTIVE
    target.save(update_fields=['status', 'updated_at'])
    get_or_create_wallet(target)
    log_audit_event(
        actor_user=actor_user,
        action='USER_REACTIVATED',
        entity='User',
        entity_id=target.id,
    )
    return target


@transaction.atomic
def admin_verify_user(
    target_user_id,
    actor_user: User,
    *,
    email: bool = False,
    phone: bool = False,
) -> User:
    if actor_user.role not in (UserRole.ADMIN, UserRole.MODERATOR):
        raise PermissionError()
    if not email and not phone:
        raise ValidationError('Indicá email y/o phone para verificar')
    target = get_user_by_id(target_user_id)
    fields = ['updated_at']
    now = timezone.now()
    if email:
        target.email_verified_at = now
        fields.append('email_verified_at')
    if phone:
        target.phone_verified_at = now
        fields.append('phone_verified_at')
    if target.status == UserStatus.PENDING and target.email_verified_at and target.phone_verified_at:
        target.status = UserStatus.ACTIVE
        fields.append('status')
        get_or_create_wallet(target)
    target.save(update_fields=fields)
    log_audit_event(
        actor_user=actor_user,
        action='USER_VERIFICATION_OVERRIDE',
        entity='User',
        entity_id=target.id,
        metadata={'email': email, 'phone': phone},
    )
    return target


@transaction.atomic
def admin_set_user_role(target_user_id, actor_user: User, role: str) -> User:
    if actor_user.role != UserRole.ADMIN:
        raise PermissionError('Solo administradores pueden cambiar roles')
    if role not in {c[0] for c in UserRole.choices}:
        raise ValidationError('Rol inválido')
    target = get_user_by_id(target_user_id)
    target.role = role
    target.save(update_fields=['role', 'updated_at'])
    log_audit_event(
        actor_user=actor_user,
        action='USER_ROLE_CHANGED',
        entity='User',
        entity_id=target.id,
        metadata={'role': role},
    )
    return target
