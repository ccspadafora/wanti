from django.urls import path

from apps.reviews.views import MyReviewsListView, ReviewDisputeView, ReviewTagsListView

urlpatterns = [
    path('tags/', ReviewTagsListView.as_view(), name='review-tags'),
    path('mine/', MyReviewsListView.as_view(), name='review-mine'),
    path('<uuid:id>/dispute/', ReviewDisputeView.as_view(), name='review-dispute'),
]
