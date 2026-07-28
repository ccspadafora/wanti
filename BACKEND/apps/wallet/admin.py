from django.contrib import admin

from apps.wallet.models import TopupOrder, TopupPackage, Wallet, WalletTransaction


class WalletTransactionInline(admin.TabularInline):
    model = WalletTransaction
    extra = 0
    can_delete = False
    readonly_fields = (
        'transaction_type',
        'amount_wantis',
        'balance_after',
        'related_object_type',
        'related_object_id',
        'note',
        'created_by',
        'created_at',
    )

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = ('user', 'balance_wantis', 'updated_at')
    search_fields = ('user__email', 'user__full_name')
    readonly_fields = ('id', 'created_at', 'updated_at', 'balance_wantis')
    inlines = [WalletTransactionInline]


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = (
        'wallet',
        'transaction_type',
        'amount_wantis',
        'balance_after',
        'created_at',
    )
    list_filter = ('transaction_type',)
    search_fields = ('wallet__user__email', 'note', 'related_object_id')
    readonly_fields = (
        'id',
        'wallet',
        'transaction_type',
        'amount_wantis',
        'balance_after',
        'related_object_type',
        'related_object_id',
        'note',
        'created_by',
        'created_at',
        'updated_at',
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(TopupPackage)
class TopupPackageAdmin(admin.ModelAdmin):
    list_display = (
        'name',
        'wantis_base',
        'wantis_bonus',
        'price_cop',
        'is_popular',
        'is_active',
        'order',
    )
    list_filter = ('is_active', 'is_popular')
    ordering = ('order',)


@admin.register(TopupOrder)
class TopupOrderAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'package',
        'wantis_total',
        'price_cop',
        'status',
        'created_at',
        'completed_at',
    )
    list_filter = ('status',)
    search_fields = ('user__email', 'provider_reference')
    readonly_fields = ('id', 'created_at', 'updated_at')
