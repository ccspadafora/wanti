from django.urls import path

from apps.disputes.views import (
    DisputeAppealView,
    DisputeCancelView,
    DisputeDetailView,
    DisputeListView,
    DisputeRespondAutoView,
)

urlpatterns = [
    path('', DisputeListView.as_view(), name='dispute-list'),
    path('<uuid:id>/', DisputeDetailView.as_view(), name='dispute-detail'),
    path(
        '<uuid:id>/respond-auto/',
        DisputeRespondAutoView.as_view(),
        name='dispute-respond-auto',
    ),
    path('<uuid:id>/cancel/', DisputeCancelView.as_view(), name='dispute-cancel'),
    path('<uuid:id>/appeal/', DisputeAppealView.as_view(), name='dispute-appeal'),
]
