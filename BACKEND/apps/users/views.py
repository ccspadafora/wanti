from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import ValidationError
from apps.users.selectors.users import get_user_by_id
from apps.users.serializers import (
    ChangeEmailSerializer,
    ChangePasswordSerializer,
    ChangePhoneSerializer,
    UserMeSerializer,
    UserMeUpdateSerializer,
    UserPublicSerializer,
)
from apps.users.services.users import (
    update_email_request,
    update_self_profile,
)


class UserMeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserMeSerializer(request.user).data)

    def patch(self, request):
        serializer = UserMeUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = update_self_profile(request.user, serializer.to_service_data())
        return Response(UserMeSerializer(user).data)


class ChangeEmailView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangeEmailSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if not request.user.check_password(serializer.validated_data['password']):
            raise ValidationError('Contraseña incorrecta')
        new_email = serializer.validated_data['new_email']
        update_email_request(request.user, new_email)
        return Response(
            {'detail': f'Enviamos un correo de confirmación a {new_email}'},
            status=status.HTTP_202_ACCEPTED,
        )


class ChangePhoneView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePhoneSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if not request.user.check_password(serializer.validated_data['password']):
            raise ValidationError('Contraseña incorrecta')
        from apps.authn.services.otp import request_otp
        from django.conf import settings

        new_phone = serializer.validated_data['new_phone']
        channel = serializer.validated_data.get('channel', 'WHATSAPP')
        _otp, code = request_otp(request.user, channel=channel, new_phone=new_phone)
        from apps.audit.services.audit_log import log_audit_event

        log_audit_event(
            actor_user=request.user,
            action='USER_PHONE_CHANGE_REQUESTED',
            entity='User',
            entity_id=request.user.id,
        )
        payload = {'detail': 'Enviamos un OTP al nuevo número'}
        if settings.DEBUG:
            payload['debug_code'] = code
        return Response(payload, status=status.HTTP_202_ACCEPTED)


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if not request.user.check_password(serializer.validated_data['current_password']):
            raise ValidationError('Contraseña actual incorrecta')
        user = request.user
        user.set_password(serializer.validated_data['new_password'])
        user.save(update_fields=['password', 'updated_at'])
        try:
            from rest_framework_simplejwt.token_blacklist.models import (
                BlacklistedToken,
                OutstandingToken,
            )

            for outstanding in OutstandingToken.objects.filter(user=user):
                BlacklistedToken.objects.get_or_create(token=outstanding)
        except Exception:
            pass
        return Response(status=status.HTTP_204_NO_CONTENT)


class UserPublicView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        user = get_user_by_id(id)
        return Response(UserPublicSerializer(user).data)
