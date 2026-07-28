from django.contrib import admin

from apps.leads.models import Lead, LeadNote


class LeadNoteInline(admin.TabularInline):
    model = LeadNote
    extra = 0
    readonly_fields = ('author', 'text', 'stage_at_time', 'created_at')


@admin.register(Lead)
class LeadAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'seller',
        'buyer',
        'stage',
        'last_activity_at',
        'expires_at',
        'sold_price_cop',
    )
    list_filter = ('stage',)
    search_fields = ('seller__email', 'buyer__email')
    readonly_fields = ('id', 'created_at', 'updated_at', 'last_activity_at')
    inlines = [LeadNoteInline]
