from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

from apps.users.models import User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    ordering = ('email',)
    list_display = (
        'email',
        'full_name',
        'role',
        'status',
        'is_staff',
        'created_at',
    )
    list_filter = ('role', 'status', 'is_staff')
    search_fields = ('email', 'full_name', 'id_number', 'phone', 'city')
    readonly_fields = ('id', 'created_at', 'updated_at', 'last_login', 'last_login_at')

    fieldsets = (
        (None, {'fields': ('id', 'email', 'password')}),
        (
            'Perfil',
            {
                'fields': (
                    'full_name',
                    'id_type',
                    'id_number',
                    'phone',
                    'city',
                    'location',
                    'profile_photo_url',
                )
            },
        ),
        (
            'Estado y permisos',
            {
                'fields': (
                    'role',
                    'status',
                    'email_verified_at',
                    'phone_verified_at',
                    'is_staff',
                    'is_superuser',
                    'groups',
                    'user_permissions',
                )
            },
        ),
        (
            'Fechas',
            {'fields': ('last_login', 'last_login_at', 'created_at', 'updated_at')},
        ),
    )
    add_fieldsets = (
        (
            'Nuevo usuario',
            {
                'classes': ('wide',),
                'fields': (
                    'email',
                    'full_name',
                    'id_type',
                    'id_number',
                    'phone',
                    'city',
                    'password1',
                    'password2',
                    'role',
                    'status',
                    'is_staff',
                    'is_superuser',
                ),
            },
        ),
    )
