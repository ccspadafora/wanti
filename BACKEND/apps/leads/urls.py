from django.urls import path

from apps.leads.views import (
    LeadChangeStageView,
    LeadDetailView,
    LeadListView,
    LeadNotesListCreateView,
)

urlpatterns = [
    path('', LeadListView.as_view(), name='lead-list'),
    path('<uuid:id>/', LeadDetailView.as_view(), name='lead-detail'),
    path('<uuid:id>/change-stage/', LeadChangeStageView.as_view(), name='lead-change-stage'),
    path('<uuid:id>/notes/', LeadNotesListCreateView.as_view(), name='lead-notes'),
]
