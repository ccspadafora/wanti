from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from apps.common.constants import OtpChannel
from apps.common.utils import point_from_coords, point_to_latlng
from apps.users.models import User


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


class UserMeSerializer(serializers.ModelSerializer):
    location = serializers.SerializerMethodField()
    is_fully_verified = serializers.BooleanField(read_only=True)
    can_publish = serializers.BooleanField(read_only=True)
    rating_average = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id',
            'email',
            'full_name',
            'phone',
            'city',
            'location',
            'role',
            'status',
            'email_verified_at',
            'phone_verified_at',
            'is_fully_verified',
            'can_publish',
            'rating_average',
            'profile_photo_url',
            'created_at',
        )
        read_only_fields = fields

    def get_location(self, obj):
        return point_to_latlng(obj.location)

    def get_rating_average(self, obj):
        return obj.rating_average


class UserMeUpdateSerializer(serializers.Serializer):
    city = serializers.CharField(max_length=100, required=False)
    location = serializers.JSONField(required=False, allow_null=True)

    def validate_location(self, value):
        return _parse_location(value)

    def to_service_data(self):
        return dict(self.validated_data)


class ChangeEmailSerializer(serializers.Serializer):
    new_email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class ChangePhoneSerializer(serializers.Serializer):
    new_phone = serializers.CharField(max_length=20)
    password = serializers.CharField(write_only=True)
    channel = serializers.ChoiceField(
        choices=OtpChannel.choices,
        default=OtpChannel.WHATSAPP,
        required=False,
    )


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)

    def validate_new_password(self, value):
        return _validate_password(value)


class UserPublicSerializer(serializers.ModelSerializer):
    rating_average = serializers.SerializerMethodField()
    is_new_user = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = (
            'id',
            'full_name',
            'city',
            'rating_average',
            'is_new_user',
            'role',
            'profile_photo_url',
        )
        read_only_fields = fields

    def get_rating_average(self, obj):
        return obj.rating_average
