from django.urls import path

from apps.admin_panel.views import (
    AdminDisputeApproveView,
    AdminDisputeListView,
    AdminDisputeRejectView,
    AdminInteractionsReportView,
    AdminInventoryListView,
    AdminMatchingReportView,
    AdminMetricsView,
    AdminNeedFlagView,
    AdminNeedListView,
    AdminNeedUnpublishView,
    AdminReviewDisputeListView,
    AdminReviewDisputeResolveView,
    AdminSettingsListView,
    AdminSettingsUpdateView,
    AdminTopupListView,
    AdminUserActivateView,
    AdminUserDetailView,
    AdminUserListView,
    AdminUserSuspendView,
    AdminWalletAdjustView,
)

urlpatterns = [
    path('metrics/', AdminMetricsView.as_view(), name='admin-metrics'),
    path('users/', AdminUserListView.as_view(), name='admin-users'),
    path('users/<uuid:id>/', AdminUserDetailView.as_view(), name='admin-user-detail'),
    path('users/<uuid:id>/suspend/', AdminUserSuspendView.as_view(), name='admin-user-suspend'),
    path(
        'users/<uuid:id>/activate/',
        AdminUserActivateView.as_view(),
        name='admin-user-activate',
    ),
    path('needs/', AdminNeedListView.as_view(), name='admin-needs'),
    path('needs/<uuid:id>/flag/', AdminNeedFlagView.as_view(), name='admin-need-flag'),
    path(
        'needs/<uuid:id>/unpublish/',
        AdminNeedUnpublishView.as_view(),
        name='admin-need-unpublish',
    ),
    path('inventory/', AdminInventoryListView.as_view(), name='admin-inventory'),
    path('disputes/', AdminDisputeListView.as_view(), name='admin-disputes'),
    path(
        'disputes/<uuid:id>/approve/',
        AdminDisputeApproveView.as_view(),
        name='admin-dispute-approve',
    ),
    path(
        'disputes/<uuid:id>/reject/',
        AdminDisputeRejectView.as_view(),
        name='admin-dispute-reject',
    ),
    path('topups/', AdminTopupListView.as_view(), name='admin-topups'),
    path(
        'wallets/<uuid:user_id>/adjust/',
        AdminWalletAdjustView.as_view(),
        name='admin-wallet-adjust',
    ),
    path(
        'review-disputes/',
        AdminReviewDisputeListView.as_view(),
        name='admin-review-disputes',
    ),
    path(
        'review-disputes/<uuid:id>/resolve/',
        AdminReviewDisputeResolveView.as_view(),
        name='admin-review-dispute-resolve',
    ),
    path(
        'reports/interactions/',
        AdminInteractionsReportView.as_view(),
        name='admin-reports-interactions',
    ),
    path(
        'reports/matching/',
        AdminMatchingReportView.as_view(),
        name='admin-reports-matching',
    ),
    path('settings/', AdminSettingsListView.as_view(), name='admin-settings'),
    path(
        'settings/<str:key>/',
        AdminSettingsUpdateView.as_view(),
        name='admin-settings-update',
    ),
]
