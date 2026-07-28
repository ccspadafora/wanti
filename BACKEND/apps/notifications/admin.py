from django.contrib import admin

from apps.notifications.models import DeviceToken, Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = (
        'template_code',
        'recipient',
        'channel',
        'delivery_status',
        'sent_at',
        'read_at',
        'created_at',
    )
    list_filter = ('channel', 'delivery_status', 'template_code')
    search_fields = ('recipient__email', 'title', 'body', 'provider_reference')
    readonly_fields = ('id', 'created_at', 'updated_at')


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'platform', 'is_active', 'device_id', 'last_used_at')
    list_filter = ('platform', 'is_active')
    search_fields = ('user__email', 'token', 'device_id')
    readonly_fields = ('id', 'created_at', 'updated_at', 'last_used_at')
