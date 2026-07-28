from django.urls import path

from apps.notifications.views import (
    DeviceTokenCreateView,
    DeviceTokenDeleteView,
    NotificationListView,
    NotificationMarkAllReadView,
    NotificationMarkReadView,
)

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification-list'),
    path('mark-all-read/', NotificationMarkAllReadView.as_view(), name='notification-mark-all-read'),
    path('<uuid:id>/mark-read/', NotificationMarkReadView.as_view(), name='notification-mark-read'),
    path('device-tokens/', DeviceTokenCreateView.as_view(), name='device-token-create'),
    path(
        'device-tokens/<uuid:id>/',
        DeviceTokenDeleteView.as_view(),
        name='device-token-delete',
    ),
]
