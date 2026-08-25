from rest_framework import serializers

from apps.common.constants import ContactOutcome, DisputeStatus
from apps.contacts.models import ContactUnlock
from apps.reviews.models import Review


class ContactPartySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()
    phone = serializers.CharField(allow_null=True, required=False)
    email = serializers.EmailField(allow_null=True, required=False)
    rating_average = serializers.FloatField(allow_null=True)
    is_new_user = serializers.BooleanField()


class ContactUnlockInventorySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    title = serializers.CharField()
    price_cop = serializers.DecimalField(max_digits=15, decimal_places=2)
    city = serializers.CharField()
    asset_type = serializers.CharField(required=False, allow_null=True)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    vehicle = serializers.DictField(required=False, allow_null=True)
    property = serializers.DictField(required=False, allow_null=True)


class ContactUnlockSerializer(serializers.ModelSerializer):
    seller = serializers.SerializerMethodField()
    buyer = serializers.SerializerMethodField()
    inventory_item = serializers.SerializerMethodField()
    match_id = serializers.UUIDField(read_only=True)
    score = serializers.SerializerMethodField()
    can_open_dispute = serializers.SerializerMethodField()
    review_pending = serializers.SerializerMethodField()

    class Meta:
        model = ContactUnlock
        fields = (
            'id',
            'match_id',
            'score',
            'seller',
            'buyer',
            'inventory_item',
            'wantis_charged',
            'outcome',
            'outcome_reported_at',
            'whatsapp_opened_at',
            'created_at',
            'can_open_dispute',
            'review_pending',
        )

    def _party(self, user):
        return ContactPartySerializer(
            {
                'id': user.id,
                'full_name': user.full_name,
                'phone': user.phone,
                'email': user.email,
                'rating_average': user.rating_average,
                'is_new_user': user.is_new_user,
            }
        ).data

    def get_seller(self, obj):
        return self._party(obj.seller)

    def get_buyer(self, obj):
        return self._party(obj.buyer)

    def get_score(self, obj):
        return obj.match.score

    def get_inventory_item(self, obj):
        from apps.common.constants import AssetType
        from apps.inventory.serializers import PropertyItemSerializer, VehicleItemSerializer

        item = obj.match.inventory_item
        data = {
            'id': item.id,
            'title': item.title,
            'price_cop': item.price_cop,
            'city': item.city,
            'asset_type': item.asset_type,
            'description': item.description or '',
            'vehicle': None,
            'property': None,
        }
        if item.asset_type == AssetType.VEHICLE and hasattr(item, 'vehicle'):
            data['vehicle'] = VehicleItemSerializer(item.vehicle).data
        elif item.asset_type == AssetType.PROPERTY and hasattr(item, 'property'):
            data['property'] = PropertyItemSerializer(item.property).data
        return ContactUnlockInventorySerializer(data).data

    def get_can_open_dispute(self, obj):
        request = self.context.get('request')
        active = obj.disputes.filter(
            status__in=[
                DisputeStatus.OPEN,
                DisputeStatus.AUTO_REVIEW,
                DisputeStatus.HUMAN_REVIEW,
                DisputeStatus.APPEALED,
            ]
        ).exists()
        if active:
            return False
        if not request or not getattr(request, 'user', None) or not request.user.is_authenticated:
            return False
        # Solo quien gastó Wanti (vendedor / pagador del unlock).
        txn = getattr(obj, 'wallet_transaction', None)
        if txn is not None and getattr(txn, 'wallet', None) is not None:
            return request.user.id == txn.wallet.user_id
        return request.user.id == obj.seller_id

    def get_review_pending(self, obj):
        request = self.context.get('request')
        if not request or obj.outcome not in (
            ContactOutcome.PURCHASED,
            ContactOutcome.NOT_PURCHASED,
        ):
            return False
        return not Review.objects.filter(
            contact_unlock=obj,
            reviewer=request.user,
        ).exists()


class ReportOutcomeSerializer(serializers.Serializer):
    outcome = serializers.ChoiceField(choices=ContactOutcome.choices)


class ContactUnlockReviewCreateSerializer(serializers.Serializer):
    rating = serializers.IntegerField(min_value=1, max_value=5)
    comment = serializers.CharField(required=False, allow_blank=True, default='')
    tags = serializers.ListField(
        child=serializers.CharField(max_length=50),
        required=False,
        default=list,
    )
