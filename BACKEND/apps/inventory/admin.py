from django.contrib import admin

from apps.inventory.models import (
    InventoryImage,
    InventoryItem,
    PropertyItem,
    VehicleItem,
)


class VehicleItemInline(admin.StackedInline):
    model = VehicleItem
    extra = 0
    max_num = 1


class PropertyItemInline(admin.StackedInline):
    model = PropertyItem
    extra = 0
    max_num = 1


class InventoryImageInline(admin.TabularInline):
    model = InventoryImage
    extra = 0


@admin.register(InventoryItem)
class InventoryItemAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'seller',
        'asset_type',
        'status',
        'price_cop',
        'city',
        'created_at',
    )
    list_filter = ('asset_type', 'status')
    search_fields = ('title', 'city', 'seller__email', 'seller__full_name')
    readonly_fields = ('id', 'created_at', 'updated_at', 'views_count', 'unlock_count')
    inlines = [VehicleItemInline, PropertyItemInline, InventoryImageInline]
