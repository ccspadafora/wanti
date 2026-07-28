from rest_framework import serializers

from apps.common.constants import AssetType, CriterionMode, PaymentType
from apps.common.utils import point_from_coords, point_to_latlng
from apps.needs.models import Need, NeedCriterion, NeedImage, PropertyNeed, VehicleNeed


class LatLngField(serializers.Field):
    def to_internal_value(self, data):
        point = point_from_coords(data)
        if point is None:
            raise serializers.ValidationError('Se requieren latitude y longitude')
        return point

    def to_representation(self, value):
        return point_to_latlng(value)


class NeedCriterionSerializer(serializers.ModelSerializer):
    class Meta:
        model = NeedCriterion
        fields = ('id', 'attribute', 'mode', 'weight')
        read_only_fields = ('id',)


class NeedImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = NeedImage
        fields = ('id', 'image_url', 'caption', 'order')
        read_only_fields = ('id',)


class VehicleNeedSerializer(serializers.ModelSerializer):
    class Meta:
        model = VehicleNeed
        exclude = ('need',)


class PropertyNeedSerializer(serializers.ModelSerializer):
    class Meta:
        model = PropertyNeed
        exclude = ('need',)


class PublicBuyerSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()
    rating_average = serializers.FloatField(allow_null=True)
    is_new_user = serializers.BooleanField()


class NeedCriterionInputSerializer(serializers.Serializer):
    attribute = serializers.CharField(max_length=80)
    mode = serializers.ChoiceField(choices=CriterionMode.choices)
    weight = serializers.IntegerField(default=10, min_value=0)


class NeedImageInputSerializer(serializers.Serializer):
    image_url = serializers.URLField(max_length=500)
    caption = serializers.CharField(max_length=200, required=False, allow_blank=True, default='')
    order = serializers.IntegerField(required=False, default=0)


class NeedCreateSerializer(serializers.Serializer):
    asset_type = serializers.ChoiceField(choices=AssetType.choices)
    title = serializers.CharField(max_length=150)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    budget_max_cop = serializers.DecimalField(max_digits=15, decimal_places=2, min_value=0)
    payment_type = serializers.ChoiceField(choices=PaymentType.choices, required=False)
    payment_types = serializers.ListField(
        child=serializers.ChoiceField(choices=PaymentType.choices),
        required=False,
        allow_empty=False,
    )
    trade_in_description = serializers.CharField(required=False, allow_blank=True, default='')
    city = serializers.CharField(max_length=100)
    location = LatLngField()
    detail = serializers.DictField(required=False, default=dict)
    criteria = NeedCriterionInputSerializer(many=True, required=False, default=list)
    images = NeedImageInputSerializer(many=True, required=False, default=list)

    def validate(self, attrs):
        payment_types = attrs.get('payment_types') or []
        payment_type = attrs.get('payment_type')
        if not payment_types and not payment_type:
            raise serializers.ValidationError({'payment_type': 'Indicá al menos un tipo de pago'})
        if not payment_types:
            attrs['payment_types'] = [payment_type]
        if not payment_type:
            attrs['payment_type'] = attrs['payment_types'][0]
        return attrs

    def to_service_data(self):
        return {
            'asset_type': self.validated_data['asset_type'],
            'title': self.validated_data['title'],
            'description': self.validated_data.get('description', ''),
            'budget_max_cop': self.validated_data['budget_max_cop'],
            'payment_type': self.validated_data['payment_type'],
            'payment_types': self.validated_data.get('payment_types')
            or [self.validated_data['payment_type']],
            'trade_in_description': self.validated_data.get('trade_in_description', ''),
            'city': self.validated_data['city'],
            'location': self.validated_data['location'],
            'detail': self.validated_data.get('detail') or {},
            'criteria': self.validated_data.get('criteria') or [],
            'images': self.validated_data.get('images') or [],
        }


class NeedUpdateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150, required=False)
    description = serializers.CharField(required=False, allow_blank=True)
    budget_max_cop = serializers.DecimalField(
        max_digits=15, decimal_places=2, min_value=0, required=False
    )
    payment_type = serializers.ChoiceField(choices=PaymentType.choices, required=False)
    city = serializers.CharField(max_length=100, required=False)
    location = LatLngField(required=False)
    criteria = NeedCriterionInputSerializer(many=True, required=False)

    def to_service_data(self):
        data = dict(self.validated_data)
        if 'criteria' in data:
            data['criteria'] = data['criteria'] or []
        return data


class NeedPublishSerializer(serializers.Serializer):
    legal_accepted = serializers.BooleanField(default=True)


class NeedSerializer(serializers.ModelSerializer):
    location = LatLngField()
    criteria = NeedCriterionSerializer(many=True, read_only=True)
    images = NeedImageSerializer(many=True, read_only=True)
    vehicle = VehicleNeedSerializer(read_only=True)
    property = PropertyNeedSerializer(read_only=True)
    buyer = PublicBuyerSerializer(read_only=True)
    detail = serializers.SerializerMethodField()

    class Meta:
        model = Need
        fields = (
            'id',
            'asset_type',
            'title',
            'description',
            'budget_max_cop',
            'payment_type',
            'city',
            'location',
            'status',
            'expires_at',
            'matches_count',
            'views_count',
            'legal_disclaimer_accepted_at',
            'criteria',
            'images',
            'vehicle',
            'property',
            'detail',
            'buyer',
            'created_at',
            'updated_at',
        )
        read_only_fields = fields

    def get_detail(self, obj):
        if obj.asset_type == AssetType.VEHICLE and hasattr(obj, 'vehicle'):
            return VehicleNeedSerializer(obj.vehicle).data
        if obj.asset_type == AssetType.PROPERTY and hasattr(obj, 'property'):
            return PropertyNeedSerializer(obj.property).data
        return None


class NeedListSerializer(serializers.ModelSerializer):
    location = LatLngField()
    buyer = PublicBuyerSerializer(read_only=True)
    can_renew = serializers.SerializerMethodField()
    days_remaining = serializers.SerializerMethodField()

    class Meta:
        model = Need
        fields = (
            'id',
            'asset_type',
            'title',
            'budget_max_cop',
            'payment_type',
            'city',
            'location',
            'status',
            'matches_count',
            'views_count',
            'expires_at',
            'days_remaining',
            'can_renew',
            'created_at',
            'buyer',
        )
        read_only_fields = fields

    def get_days_remaining(self, obj):
        if not obj.expires_at:
            return None
        from django.utils import timezone

        delta = obj.expires_at - timezone.now()
        days = int(delta.total_seconds() // 86400)
        return max(days, 0)

    def get_can_renew(self, obj):
        if obj.status not in ('ACTIVE', 'PAUSED') or not obj.expires_at:
            return False
        from django.utils import timezone

        days_left = (obj.expires_at - timezone.now()).total_seconds() / 86400
        return 0 <= days_left <= 5


class NeedStatusSerializer(serializers.ModelSerializer):
    can_renew = serializers.SerializerMethodField()

    class Meta:
        model = Need
        fields = ('id', 'status', 'expires_at', 'can_renew')
        read_only_fields = fields

    def get_can_renew(self, obj):
        if obj.status not in ('ACTIVE', 'PAUSED') or not obj.expires_at:
            return False
        from django.utils import timezone

        days_left = (obj.expires_at - timezone.now()).total_seconds() / 86400
        return 0 <= days_left <= 5
