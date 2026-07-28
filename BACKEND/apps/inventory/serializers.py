from rest_framework import serializers

from apps.common.constants import AssetType, InventoryStatus
from apps.common.utils import point_from_coords, point_to_latlng
from apps.inventory.models import InventoryImage, InventoryItem, PropertyItem, VehicleItem


class LatLngField(serializers.Field):
    def to_internal_value(self, data):
        point = point_from_coords(data)
        if point is None:
            raise serializers.ValidationError('Se requieren latitude y longitude')
        return point

    def to_representation(self, value):
        return point_to_latlng(value)


class InventoryImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = InventoryImage
        fields = ('id', 'image_url', 'is_ai_generated', 'source_prompt', 'order')
        read_only_fields = fields


class VehicleItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = VehicleItem
        exclude = ('item',)


class PropertyItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = PropertyItem
        exclude = ('item',)


class InventoryImageInputSerializer(serializers.Serializer):
    image_url = serializers.URLField(max_length=500)
    is_ai_generated = serializers.BooleanField(required=False, default=False)
    source_prompt = serializers.CharField(required=False, allow_blank=True, default='')
    order = serializers.IntegerField(required=False, default=0)


class InventoryCreateSerializer(serializers.Serializer):
    asset_type = serializers.ChoiceField(choices=AssetType.choices)
    title = serializers.CharField(max_length=150)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    price_cop = serializers.DecimalField(max_digits=15, decimal_places=2, min_value=0)
    city = serializers.CharField(max_length=100)
    location = LatLngField()
    detail = serializers.DictField(required=False, default=dict)
    images = InventoryImageInputSerializer(many=True, required=False, default=list)

    def to_service_data(self):
        return {
            'asset_type': self.validated_data['asset_type'],
            'title': self.validated_data['title'],
            'description': self.validated_data.get('description', ''),
            'price_cop': self.validated_data['price_cop'],
            'city': self.validated_data['city'],
            'location': self.validated_data['location'],
            'detail': self.validated_data.get('detail') or {},
            'images': self.validated_data.get('images') or [],
        }


class InventoryUpdateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150, required=False)
    description = serializers.CharField(required=False, allow_blank=True)
    price_cop = serializers.DecimalField(
        max_digits=15, decimal_places=2, min_value=0, required=False
    )
    city = serializers.CharField(max_length=100, required=False)
    location = LatLngField(required=False)
    status = serializers.ChoiceField(choices=InventoryStatus.choices, required=False)
    detail = serializers.DictField(required=False)

    def to_service_data(self):
        return dict(self.validated_data)


class GenerateAIImageSerializer(serializers.Serializer):
    prompt = serializers.CharField()
    count = serializers.IntegerField(required=False, default=3, min_value=1, max_value=6)


class SelectAIImagesSerializer(serializers.Serializer):
    image_ids = serializers.ListField(
        child=serializers.UUIDField(),
        required=False,
        default=list,
    )
    image_urls = serializers.ListField(
        child=serializers.URLField(max_length=500),
        required=False,
        default=list,
    )


class InventoryItemSerializer(serializers.ModelSerializer):
    location = LatLngField()
    images = InventoryImageSerializer(many=True, read_only=True)
    vehicle = VehicleItemSerializer(read_only=True)
    property = PropertyItemSerializer(read_only=True)
    detail = serializers.SerializerMethodField()

    class Meta:
        model = InventoryItem
        fields = (
            'id',
            'asset_type',
            'title',
            'description',
            'price_cop',
            'city',
            'location',
            'status',
            'views_count',
            'unlock_count',
            'images',
            'vehicle',
            'property',
            'detail',
            'created_at',
            'updated_at',
        )
        read_only_fields = fields

    def get_detail(self, obj):
        if obj.asset_type == AssetType.VEHICLE and hasattr(obj, 'vehicle'):
            return VehicleItemSerializer(obj.vehicle).data
        if obj.asset_type == AssetType.PROPERTY and hasattr(obj, 'property'):
            return PropertyItemSerializer(obj.property).data
        return None


class InventoryListSerializer(serializers.ModelSerializer):
    location = LatLngField()
    images = InventoryImageSerializer(many=True, read_only=True)
    vehicle = VehicleItemSerializer(read_only=True)
    property = PropertyItemSerializer(read_only=True)

    class Meta:
        model = InventoryItem
        fields = (
            'id',
            'asset_type',
            'title',
            'price_cop',
            'city',
            'location',
            'status',
            'unlock_count',
            'images',
            'vehicle',
            'property',
            'created_at',
        )
        read_only_fields = fields


class InventoryStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = InventoryItem
        fields = ('id', 'status')
        read_only_fields = fields
