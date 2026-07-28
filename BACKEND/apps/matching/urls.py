from django.urls import path

from apps.matching.views import (
    MatchDetailView,
    MatchDiscardView,
    MatchListView,
    MatchUnlockView,
)

urlpatterns = [
    path('', MatchListView.as_view(), name='match-list'),
    path('<uuid:id>/', MatchDetailView.as_view(), name='match-detail'),
    path('<uuid:id>/discard/', MatchDiscardView.as_view(), name='match-discard'),
    path('<uuid:match_id>/unlock/', MatchUnlockView.as_view(), name='match-unlock'),
]
