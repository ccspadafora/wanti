from django.db.models import Q, QuerySet

from apps.common.constants import UserRole
from apps.common.exceptions import NotFoundError, PermissionError
from apps.users.models import User


def get_user_by_id(user_id) -> User:
    try:
        return User.objects.get(pk=user_id)
    except User.DoesNotExist as exc:
        raise NotFoundError('Usuario no encontrado') from exc


def get_user_by_email(email: str) -> User | None:
    return User.objects.filter(email__iexact=email.strip()).first()


def list_users(
    actor_user: User,
    *,
    role=None,
    status=None,
    city=None,
    search=None,
) -> QuerySet[User]:
    if actor_user.role not in (UserRole.ADMIN, UserRole.MODERATOR):
        raise PermissionError('Sin permisos para listar usuarios')
    qs = User.objects.all().order_by('-created_at')
    if role:
        qs = qs.filter(role=role)
    if status:
        qs = qs.filter(status=status)
    if city:
        qs = qs.filter(city__icontains=city)
    if search:
        qs = qs.filter(
            Q(full_name__icontains=search)
            | Q(email__icontains=search)
            | Q(phone__icontains=search)
            | Q(id_number__icontains=search)
        )
    return qs
