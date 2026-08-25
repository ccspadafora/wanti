from rest_framework import serializers

from apps.common.constants import AssetType, MatchStatus
from apps.common.utils import point_to_latlng
from apps.inventory.serializers import (
    InventoryImageSerializer,
    PropertyItemSerializer,
    VehicleItemSerializer,
)
from apps.matching.models import Match, MatchCriterionResult


class PublicUserSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()
    rating_average = serializers.FloatField(allow_null=True)
    is_new_user = serializers.BooleanField()


class MatchCriterionResultSerializer(serializers.ModelSerializer):
    expected = serializers.CharField(source='expected_value')
    actual = serializers.CharField(source='actual_value')

    class Meta:
        model = MatchCriterionResult
        fields = (
            'attribute',
            'mode',
            'expected',
            'actual',
            'met',
            'contribution',
        )


class MatchNeedBriefSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    title = serializers.CharField()
    budget_max_cop = serializers.DecimalField(max_digits=15, decimal_places=2)
    payment_type = serializers.CharField()
    city = serializers.CharField()
    location = serializers.SerializerMethodField()

    def get_location(self, obj):
        return point_to_latlng(obj.location)


class MatchListSerializer(serializers.ModelSerializer):
    inventory_item = serializers.SerializerMethodField()
    need = MatchNeedBriefSerializer(read_only=True)
    seller = PublicUserSerializer(read_only=True)
    buyer = PublicUserSerializer(read_only=True)
    already_unlocked = serializers.SerializerMethodField()
    unlock_cost_wantis = serializers.SerializerMethodField()
    unlock_id = serializers.SerializerMethodField()
    seller_phone = serializers.SerializerMethodField()
    buyer_phone = serializers.SerializerMethodField()
    buyer_email = serializers.SerializerMethodField()
    lead_id = serializers.SerializerMethodField()

    class Meta:
        model = Match
        fields = (
            'id',
            'need_id',
            'inventory_item_id',
            'inventory_item',
            'need',
            'seller',
            'buyer',
            'score',
            'distance_km',
            'unmet_preferences',
            'required_criteria_met',
            'status',
            'already_unlocked',
            'unlock_cost_wantis',
            'unlock_id',
            'seller_phone',
            'buyer_phone',
            'buyer_email',
            'lead_id',
            'created_at',
        )

    def get_inventory_item(self, obj):
        item = obj.inventory_item
        data = {
            'id': item.id,
            'title': item.title,
            'price_cop': item.price_cop,
            'city': item.city,
            'asset_type': item.asset_type,
            'description': item.description or '',
            'images': InventoryImageSerializer(item.images.all(), many=True).data,
            'vehicle': None,
            'property': None,
        }
        if item.asset_type == AssetType.VEHICLE:
            data['vehicle'] = VehicleItemSerializer(item.vehicle).data
        elif item.asset_type == AssetType.PROPERTY:
            data['property'] = PropertyItemSerializer(item.property).data
        return data

    def get_already_unlocked(self, obj):
        return obj.status == MatchStatus.UNLOCKED

    def get_unlock_cost_wantis(self, obj):
        return 1

    def get_unlock_id(self, obj):
        request = self.context.get('request')
        if not request or obj.status != MatchStatus.UNLOCKED:
            return None
        if request.user.id not in (obj.buyer_id, obj.seller_id):
            return None
        unlock = getattr(obj, 'unlock', None)
        return unlock.id if unlock else None

    def get_seller_phone(self, obj):
        request = self.context.get('request')
        if not request or obj.status != MatchStatus.UNLOCKED:
            return None
        if request.user.id != obj.buyer_id:
            return None
        return obj.seller.phone

    def get_buyer_phone(self, obj):
        request = self.context.get('request')
        if not request or obj.status != MatchStatus.UNLOCKED:
            return None
        if request.user.id != obj.seller_id:
            return None
        return obj.buyer.phone

    def get_buyer_email(self, obj):
        request = self.context.get('request')
        if not request or obj.status != MatchStatus.UNLOCKED:
            return None
        if request.user.id != obj.seller_id:
            return None
        return obj.buyer.email

    def get_lead_id(self, obj):
        request = self.context.get('request')
        if not request or obj.status != MatchStatus.UNLOCKED:
            return None
        if request.user.id != obj.seller_id:
            return None
        unlock = getattr(obj, 'unlock', None)
        if not unlock:
            return None
        lead = getattr(unlock, 'lead', None)
        return lead.id if lead else None


class MatchDetailSerializer(MatchListSerializer):
    criteria_results = MatchCriterionResultSerializer(many=True, read_only=True)

    class Meta(MatchListSerializer.Meta):
        fields = MatchListSerializer.Meta.fields + (
            'criteria_results',
            'viewed_at',
            'unlocked_at',
            'discarded_at',
        )


class UnlockContactResponseSerializer(serializers.Serializer):
    unlock_id = serializers.UUIDField()
    wantis_charged = serializers.IntegerField()
    already_unlocked = serializers.BooleanField(required=False, default=False)
    seller_phone = serializers.CharField(allow_null=True)
    buyer_phone = serializers.CharField(allow_null=True)
    buyer_email = serializers.EmailField(allow_null=True)
    lead_id = serializers.UUIDField(allow_null=True)
