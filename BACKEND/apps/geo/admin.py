from django.contrib import admin

from apps.geo.models import GeoCity, GeoDepartment


class GeoCityInline(admin.TabularInline):
    model = GeoCity
    extra = 0
    fields = ('name', 'is_capital', 'is_active', 'latitude', 'longitude')


@admin.register(GeoDepartment)
class GeoDepartmentAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'is_active', 'created_at')
    list_filter = ('is_active',)
    search_fields = ('name', 'code')
    inlines = [GeoCityInline]


@admin.register(GeoCity)
class GeoCityAdmin(admin.ModelAdmin):
    list_display = ('name', 'department', 'is_capital', 'is_active')
    list_filter = ('department', 'is_active', 'is_capital')
    search_fields = ('name', 'department__name')
    autocomplete_fields = ('department',)
