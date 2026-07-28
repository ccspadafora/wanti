from django.contrib import admin

from apps.contacts.models import ContactUnlock


@admin.register(ContactUnlock)
class ContactUnlockAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'match',
        'buyer',
        'seller',
        'wantis_charged',
        'outcome',
        'created_at',
    )
    list_filter = ('outcome',)
    search_fields = ('buyer__email', 'seller__email')
    readonly_fields = ('id', 'created_at', 'updated_at')
