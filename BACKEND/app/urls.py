from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/health/', include('apps.health.urls')),
    path('api/v1/auth/', include('apps.authn.urls')),
    path('api/v1/users/', include('apps.users.urls')),
    path('api/v1/needs/', include('apps.needs.urls')),
    path('api/v1/inventory/', include('apps.inventory.urls')),
    path('api/v1/catalog/', include('apps.catalog.urls')),
    path('api/v1/geo/', include('apps.geo.urls')),
    path('api/v1/matches/', include('apps.matching.urls')),
    path('api/v1/wallet/', include('apps.wallet.urls')),
    path('api/v1/contacts/', include('apps.contacts.urls')),
    path('api/v1/disputes/', include('apps.disputes.urls')),
    path('api/v1/reviews/', include('apps.reviews.urls')),
    path('api/v1/leads/', include('apps.leads.urls')),
    path('api/v1/notifications/', include('apps.notifications.urls')),
    path('api/v1/admin/', include('apps.admin_panel.urls')),
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path(
        'api/docs/',
        SpectacularSwaggerView.as_view(url_name='schema'),
        name='swagger-ui',
    ),
]
