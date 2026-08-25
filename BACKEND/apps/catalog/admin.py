from django.contrib import admin

from apps.catalog.models import (
    VehicleBrand,
    VehicleModel,
    VehicleModelYear,
    VehicleVersion,
    VehicleVersionSpec,
)


class VehicleModelInline(admin.TabularInline):
    model = VehicleModel
    extra = 0
    fields = ('name', 'is_popular', 'is_active', 'sort_order')


@admin.register(VehicleBrand)
class VehicleBrandAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'is_popular', 'is_active', 'sort_order')
    list_filter = ('category', 'is_popular', 'is_active')
    search_fields = ('name',)
    inlines = [VehicleModelInline]


class VehicleModelYearInline(admin.TabularInline):
    model = VehicleModelYear
    extra = 0
    fields = ('year', 'is_popular', 'is_active')


@admin.register(VehicleModel)
class VehicleModelAdmin(admin.ModelAdmin):
    list_display = ('name', 'brand', 'is_popular', 'is_active')
    list_filter = ('brand', 'is_popular', 'is_active')
    search_fields = ('name', 'brand__name')
    inlines = [VehicleModelYearInline]


class VehicleVersionInline(admin.TabularInline):
    model = VehicleVersion
    extra = 0
    fields = ('name', 'is_active', 'quality', 'sort_order')


@admin.register(VehicleModelYear)
class VehicleModelYearAdmin(admin.ModelAdmin):
    list_display = ('year', 'model', 'is_popular', 'is_active')
    list_filter = ('year', 'is_active')
    search_fields = ('model__name', 'model__brand__name')
    inlines = [VehicleVersionInline]


@admin.register(VehicleVersion)
class VehicleVersionAdmin(admin.ModelAdmin):
    list_display = ('name', 'model_year', 'is_active', 'quality')
    list_filter = ('is_active', 'quality')
    search_fields = ('name', 'catalog_key', 'model_year__model__name')


@admin.register(VehicleVersionSpec)
class VehicleVersionSpecAdmin(admin.ModelAdmin):
    list_display = ('version', 'fuel_types', 'transmissions', 'tractions', 'engine_cc', 'source')
    search_fields = ('version__name', 'version__catalog_key')
    list_filter = ('source',)
