from rest_framework.permissions import BasePermission, SAFE_METHODS

from apps.common.constants import UserRole


class IsFullyVerified(BasePermission):
    message = 'Debes verificar email y teléfono'

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.is_fully_verified)


class IsAdminOrModerator(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.role in (UserRole.ADMIN, UserRole.MODERATOR)
        )


class IsAdmin(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role == UserRole.ADMIN)
