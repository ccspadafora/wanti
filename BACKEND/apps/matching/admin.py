from django.contrib import admin

from apps.matching.models import Match, MatchCriterionResult


class MatchCriterionResultInline(admin.TabularInline):
    model = MatchCriterionResult
    extra = 0
    readonly_fields = (
        'attribute',
        'mode',
        'expected_value',
        'actual_value',
        'met',
        'contribution',
    )


@admin.register(Match)
class MatchAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'need',
        'inventory_item',
        'buyer',
        'seller',
        'score',
        'status',
        'distance_km',
        'created_at',
    )
    list_filter = ('status', 'required_criteria_met')
    search_fields = (
        'buyer__email',
        'seller__email',
        'need__title',
        'inventory_item__title',
    )
    readonly_fields = ('id', 'created_at', 'updated_at')
    inlines = [MatchCriterionResultInline]
