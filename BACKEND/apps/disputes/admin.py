from django.contrib import admin

from apps.disputes.models import Dispute, DisputeAttachment, DisputeEvent


class DisputeAttachmentInline(admin.TabularInline):
    model = DisputeAttachment
    extra = 0
    readonly_fields = ('file_url', 'file_name', 'mime_type', 'uploaded_by', 'created_at')


class DisputeEventInline(admin.TabularInline):
    model = DisputeEvent
    extra = 0
    readonly_fields = ('event_type', 'actor', 'payload', 'created_at')


@admin.register(Dispute)
class DisputeAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'contact_unlock',
        'opened_by',
        'reason',
        'status',
        'created_at',
        'resolved_at',
    )
    list_filter = ('status', 'reason')
    search_fields = ('opened_by__email', 'description', 'resolution_note')
    readonly_fields = ('id', 'created_at', 'updated_at')
    inlines = [DisputeAttachmentInline, DisputeEventInline]
