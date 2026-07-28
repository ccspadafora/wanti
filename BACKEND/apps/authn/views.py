from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.authn.serializers import (
    LoginSerializer,
    LogoutSerializer,
    OtpRequestSerializer,
    OtpVerifySerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RegisterSerializer,
    TokenSerializer,
)
from django.conf import settings

from apps.authn.models import EmailVerificationToken
from apps.authn.services.email_verification import (
    send_verification_email,
    verify_email_token,
)
from apps.authn.services.jwt import login_user
from apps.authn.services.otp import request_otp, verify_otp
from apps.authn.services.password_reset import (
    confirm_password_reset,
    request_password_reset,
)
from apps.common.exceptions import ConflictError
from apps.users.services.users import register_user


def _client_ip(request):
    forwarded = request.META.get('HTTP_X_FORWARDED_FOR')
    if forwarded:
        return forwarded.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def _user_basic(user):
    return {
        'id': str(user.id),
        'email': user.email,
        'full_name': user.full_name,
        'role': user.role,
        'status': user.status,
        'email_verified_at': user.email_verified_at,
        'phone_verified_at': user.phone_verified_at,
        'is_fully_verified': user.is_fully_verified,
    }


class RegisterView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'register'

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = register_user(serializer.to_service_data(), ip_address=_client_ip(request))
        payload = {
            'id': str(user.id),
            'email': user.email,
            'full_name': user.full_name,
            'status': user.status,
            'email_verified_at': user.email_verified_at,
            'phone_verified_at': user.phone_verified_at,
            'next_step': 'verify_email',
        }
        if settings.DEBUG:
            token = (
                EmailVerificationToken.objects.filter(user=user, used_at__isnull=True)
                .order_by('-created_at')
                .first()
            )
            if token:
                payload['debug_email_token'] = token.token
        return Response(payload, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'login'

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        result = login_user(
            email=serializer.validated_data['email'],
            password=serializer.validated_data['password'],
            ip_address=_client_ip(request),
        )
        return Response(
            {
                'access': result['access'],
                'refresh': result['refresh'],
                'user': _user_basic(result['user']),
            }
        )


class VerifyEmailView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = TokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = verify_email_token(serializer.validated_data['token'])
        next_step = 'done' if user.phone_verified_at else 'verify_phone'
        return Response(
            {
                'email_verified_at': user.email_verified_at,
                'next_step': next_step,
            }
        )


class ResendEmailVerificationView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'otp_send'

    def post(self, request):
        if request.user.email_verified_at is not None:
            raise ConflictError('El email ya está verificado')
        token = send_verification_email(request.user)
        if settings.DEBUG:
            return Response({'debug_email_token': token.token})
        return Response(status=status.HTTP_204_NO_CONTENT)


class OtpRequestView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'otp_send'

    def post(self, request):
        serializer = OtpRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_phone = serializer.validated_data.get('new_phone')
        if request.user.phone_verified_at is not None and not new_phone:
            raise ConflictError('El teléfono ya está verificado')
        _otp, code = request_otp(
            request.user,
            channel=serializer.validated_data['channel'],
            new_phone=new_phone,
        )
        if not settings.TWILIO_ENABLED:
            return Response({'debug_code': code, 'channel': serializer.validated_data['channel']})
        return Response(status=status.HTTP_204_NO_CONTENT)


class OtpVerifyView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'otp_verify'

    def post(self, request):
        serializer = OtpVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        verify_otp(request.user, serializer.validated_data['code'])
        request.user.refresh_from_db()
        return Response(
            {
                'phone_verified_at': request.user.phone_verified_at,
                'is_fully_verified': request.user.is_fully_verified,
                'status': request.user.status,
            }
        )


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'password_reset'

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        request_password_reset(
            serializer.validated_data['email'],
            ip_address=_client_ip(request),
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        confirm_password_reset(
            serializer.validated_data['token'],
            serializer.validated_data['new_password'],
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            from rest_framework_simplejwt.tokens import RefreshToken

            RefreshToken(serializer.validated_data['refresh']).blacklist()
        except Exception:
            pass
        return Response(status=status.HTTP_204_NO_CONTENT)
