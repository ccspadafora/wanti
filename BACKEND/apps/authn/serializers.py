from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from apps.common.constants import IdType, OtpChannel
from apps.common.utils import point_from_coords


def _validate_password(value):
    try:
        validate_password(value)
    except DjangoValidationError as exc:
        raise serializers.ValidationError(list(exc.messages)) from exc
    return value


def _parse_location(value):
    if value is None:
        return None
    if isinstance(value, dict) and 'lat' in value and 'latitude' not in value:
        value = {
            'latitude': value.get('lat'),
            'longitude': value.get('lng', value.get('lon')),
        }
    point = point_from_coords(value)
    if point is None:
        raise serializers.ValidationError(
            'location debe incluir latitude y longitude'
        )
    return point


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    full_name = serializers.CharField(max_length=150)
    id_type = serializers.ChoiceField(choices=IdType.choices)
    id_number = serializers.CharField(max_length=30)
    phone = serializers.CharField(max_length=20)
    city = serializers.CharField(max_length=100)
    location = serializers.JSONField(required=False, allow_null=True)

    def validate_password(self, value):
        return _validate_password(value)

    def validate_location(self, value):
        return _parse_location(value)

    def to_service_data(self):
        return dict(self.validated_data)


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class TokenSerializer(serializers.Serializer):
    token = serializers.CharField()


class OtpRequestSerializer(serializers.Serializer):
    channel = serializers.ChoiceField(
        choices=OtpChannel.choices,
        default=OtpChannel.WHATSAPP,
    )
    new_phone = serializers.CharField(max_length=20, required=False, allow_null=True)


class OtpVerifySerializer(serializers.Serializer):
    code = serializers.CharField(min_length=4, max_length=10)


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True, min_length=8)

    def validate_new_password(self, value):
        return _validate_password(value)


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()
