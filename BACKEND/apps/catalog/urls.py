from django.urls import path

from apps.catalog.views import (
    BrandDetailView,
    BrandListView,
    CatalogImportTemplateView,
    CatalogImportView,
    ModelDetailView,
    ModelListView,
    VersionDetailView,
    VersionListView,
    VersionSpecsView,
    YearDetailView,
    YearListView,
)

urlpatterns = [
    path('vehicle/brands/', BrandListView.as_view(), name='catalog-brands'),
    path('vehicle/brands/<uuid:id>/', BrandDetailView.as_view(), name='catalog-brand-detail'),
    path('vehicle/models/', ModelListView.as_view(), name='catalog-models'),
    path('vehicle/models/<uuid:id>/', ModelDetailView.as_view(), name='catalog-model-detail'),
    path('vehicle/years/', YearListView.as_view(), name='catalog-years'),
    path('vehicle/years/<uuid:id>/', YearDetailView.as_view(), name='catalog-year-detail'),
    path('vehicle/versions/', VersionListView.as_view(), name='catalog-versions'),
    path(
        'vehicle/versions/<uuid:id>/',
        VersionDetailView.as_view(),
        name='catalog-version-detail',
    ),
    path(
        'vehicle/versions/<uuid:id>/specs/',
        VersionSpecsView.as_view(),
        name='catalog-version-specs',
    ),
    path('vehicle/import/', CatalogImportView.as_view(), name='catalog-import'),
    path(
        'vehicle/import/template/',
        CatalogImportTemplateView.as_view(),
        name='catalog-import-template',
    ),
]
