from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from apps.authn.views import (
    LoginView,
    LogoutView,
    OtpRequestView,
    OtpVerifyView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    RegisterView,
    ResendEmailVerificationView,
    VerifyEmailView,
)

app_name = 'authn'

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('verify-email/', VerifyEmailView.as_view(), name='verify-email'),
    path(
        'resend-email-verification/',
        ResendEmailVerificationView.as_view(),
        name='resend-email-verification',
    ),
    path('otp/request/', OtpRequestView.as_view(), name='otp-request'),
    path('otp/verify/', OtpVerifyView.as_view(), name='otp-verify'),
    path(
        'password/reset-request/',
        PasswordResetRequestView.as_view(),
        name='password-reset-request',
    ),
    path(
        'password/reset-confirm/',
        PasswordResetConfirmView.as_view(),
        name='password-reset-confirm',
    ),
    path('logout/', LogoutView.as_view(), name='logout'),
]
