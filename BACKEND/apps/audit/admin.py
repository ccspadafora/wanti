from django.contrib import admin

from apps.audit.models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = (
        'action',
        'entity',
        'entity_id',
        'actor_user',
        'ip_address',
        'created_at',
    )
    list_filter = ('action', 'entity')
    search_fields = ('action', 'entity', 'entity_id', 'actor_user__email')
    readonly_fields = (
        'id',
        'actor_user',
        'action',
        'entity',
        'entity_id',
        'metadata',
        'ip_address',
        'user_agent',
        'created_at',
        'updated_at',
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
