from django.contrib import admin

from apps.reviews.models import Review, ReviewDispute, ReviewTag


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'reviewer',
        'reviewee',
        'rating',
        'status',
        'created_at',
    )
    list_filter = ('status', 'rating')
    search_fields = ('reviewer__email', 'reviewee__email', 'comment')
    readonly_fields = ('id', 'created_at', 'updated_at')


@admin.register(ReviewTag)
class ReviewTagAdmin(admin.ModelAdmin):
    list_display = ('code', 'label', 'for_role', 'is_active', 'order')
    list_filter = ('for_role', 'is_active')
    ordering = ('for_role', 'order')


@admin.register(ReviewDispute)
class ReviewDisputeAdmin(admin.ModelAdmin):
    list_display = ('id', 'review', 'disputed_by', 'status', 'created_at', 'resolved_at')
    list_filter = ('status',)
    search_fields = ('disputed_by__email', 'reason', 'admin_note')
    readonly_fields = ('id', 'created_at', 'updated_at')
