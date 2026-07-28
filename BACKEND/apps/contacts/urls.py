from django.urls import path

from apps.contacts.views import (
    ContactUnlockListView,
    ContactUnlockReportOutcomeView,
    ContactUnlockReviewCreateView,
    ContactUnlockWhatsAppOpenedView,
)
from apps.disputes.views import DisputeCreateView

urlpatterns = [
    path('unlocks/', ContactUnlockListView.as_view(), name='contact-unlock-list'),
    path(
        'unlocks/<uuid:id>/whatsapp-opened/',
        ContactUnlockWhatsAppOpenedView.as_view(),
        name='contact-unlock-whatsapp-opened',
    ),
    path(
        'unlocks/<uuid:id>/report-outcome/',
        ContactUnlockReportOutcomeView.as_view(),
        name='contact-unlock-report-outcome',
    ),
    path(
        'unlocks/<uuid:id>/disputes/',
        DisputeCreateView.as_view(),
        name='contact-unlock-dispute-create',
    ),
    path(
        'unlocks/<uuid:id>/reviews/',
        ContactUnlockReviewCreateView.as_view(),
        name='contact-unlock-review-create',
    ),
]
