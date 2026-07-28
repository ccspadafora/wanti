from django.urls import path

from apps.reviews.views import UserReviewsListView
from apps.users.views import (
    ChangeEmailView,
    ChangePasswordView,
    ChangePhoneView,
    UserMeView,
    UserPublicView,
)

app_name = 'users'

urlpatterns = [
    path('me/', UserMeView.as_view(), name='me'),
    path('me/change-email/', ChangeEmailView.as_view(), name='change-email'),
    path('me/change-phone/', ChangePhoneView.as_view(), name='change-phone'),
    path('me/change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('<uuid:id>/reviews/', UserReviewsListView.as_view(), name='user-reviews'),
    path('<uuid:id>/', UserPublicView.as_view(), name='public'),
]
