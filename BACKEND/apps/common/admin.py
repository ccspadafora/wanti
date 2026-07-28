from django.contrib import admin

from apps.common.models import SystemSetting
from apps.common.services.settings_service import invalidate_setting_cache


@admin.register(SystemSetting)
class SystemSettingAdmin(admin.ModelAdmin):
    list_display = ('key', 'value', 'value_type', 'updated_at')
    list_filter = ('value_type',)
    search_fields = ('key', 'description')
    readonly_fields = ('updated_at',)

    def save_model(self, request, obj, form, change):
        obj.updated_by = request.user
        super().save_model(request, obj, form, change)
        invalidate_setting_cache(obj.key)
