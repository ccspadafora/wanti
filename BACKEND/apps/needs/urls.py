from django.urls import path

from apps.needs.views import (
    NeedDetailView,
    NeedListCreateView,
    NeedMatchesView,
    NeedPauseView,
    NeedPublishView,
    NeedRenewView,
    NeedResumeView,
)

urlpatterns = [
    path('', NeedListCreateView.as_view(), name='need-list-create'),
    path('<uuid:id>/', NeedDetailView.as_view(), name='need-detail'),
    path('<uuid:id>/publish/', NeedPublishView.as_view(), name='need-publish'),
    path('<uuid:id>/pause/', NeedPauseView.as_view(), name='need-pause'),
    path('<uuid:id>/resume/', NeedResumeView.as_view(), name='need-resume'),
    path('<uuid:id>/renew/', NeedRenewView.as_view(), name='need-renew'),
    path('<uuid:id>/matches/', NeedMatchesView.as_view(), name='need-matches'),
]
