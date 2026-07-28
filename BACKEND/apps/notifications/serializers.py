from rest_framework import serializers

from apps.notifications.models import DeviceToken, Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = (
            'id',
            'channel',
            'template_code',
            'title',
            'body',
            'payload',
            'read_at',
            'created_at',
        )
        read_only_fields = fields


class DeviceTokenCreateSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=500)
    platform = serializers.ChoiceField(choices=DeviceToken.Platform.choices)
    device_id = serializers.CharField(max_length=120, required=False, allow_blank=True, default='')


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ('id', 'token', 'platform', 'device_id', 'is_active', 'last_used_at', 'created_at')
        read_only_fields = fields
