from django.contrib import admin

from apps.needs.models import Need, NeedCriterion, NeedImage, PropertyNeed, VehicleNeed


class VehicleNeedInline(admin.StackedInline):
    model = VehicleNeed
    extra = 0
    max_num = 1


class PropertyNeedInline(admin.StackedInline):
    model = PropertyNeed
    extra = 0
    max_num = 1


class NeedCriterionInline(admin.TabularInline):
    model = NeedCriterion
    extra = 0


class NeedImageInline(admin.TabularInline):
    model = NeedImage
    extra = 0


@admin.register(Need)
class NeedAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'buyer',
        'asset_type',
        'status',
        'budget_max_cop',
        'city',
        'created_at',
    )
    list_filter = ('asset_type', 'status', 'payment_type')
    search_fields = ('title', 'city', 'buyer__email', 'buyer__full_name')
    readonly_fields = ('id', 'created_at', 'updated_at', 'matches_count', 'views_count')
    inlines = [VehicleNeedInline, PropertyNeedInline, NeedCriterionInline, NeedImageInline]
