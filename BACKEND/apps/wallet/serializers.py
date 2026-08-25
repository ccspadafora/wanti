from rest_framework import serializers

from apps.common.constants import TopupStatus
from apps.wallet.models import TopupOrder, TopupPackage, WalletTransaction


class WalletBalanceSerializer(serializers.Serializer):
    balance_wantis = serializers.IntegerField()
    wanti_price_cop = serializers.IntegerField()
    balance_equivalent_cop = serializers.DecimalField(max_digits=15, decimal_places=2)


class TopupPackageSerializer(serializers.ModelSerializer):
    wantis_total = serializers.IntegerField(read_only=True)

    class Meta:
        model = TopupPackage
        fields = (
            'id',
            'name',
            'wantis_base',
            'wantis_bonus',
            'wantis_total',
            'price_cop',
            'is_popular',
        )


class TopupCreateSerializer(serializers.Serializer):
    package_id = serializers.UUIDField()


class TopupOrderSerializer(serializers.ModelSerializer):
    order_id = serializers.UUIDField(source='id', read_only=True)
    checkout_url = serializers.CharField(required=False, allow_null=True)

    class Meta:
        model = TopupOrder
        fields = (
            'order_id',
            'status',
            'wantis_total',
            'price_cop',
            'checkout_url',
            'created_at',
        )


class TopupWebhookSerializer(serializers.Serializer):
    order_id = serializers.UUIDField(required=False)
    status = serializers.CharField()
    provider_reference = serializers.CharField(required=False, allow_blank=True, default='')
    provider_payload = serializers.DictField(required=False, default=dict)

    def validate(self, attrs):
        if not attrs.get('order_id') and not (attrs.get('provider_reference') or '').strip():
            raise serializers.ValidationError(
                'Se requiere order_id o provider_reference'
            )
        return attrs


class WalletTransactionSerializer(serializers.ModelSerializer):
    contact_name = serializers.SerializerMethodField()
    inventory_title = serializers.SerializerMethodField()

    class Meta:
        model = WalletTransaction
        fields = (
            'id',
            'transaction_type',
            'amount_wantis',
            'balance_after',
            'note',
            'contact_name',
            'inventory_title',
            'related_object_type',
            'related_object_id',
            'created_at',
        )

    def get_contact_name(self, obj):
        if obj.transaction_type != 'UNLOCK' or not obj.related_object_id:
            return None
        from apps.matching.models import Match

        match = (
            Match.objects.select_related('buyer', 'seller')
            .filter(pk=obj.related_object_id)
            .first()
        )
        if not match:
            return None
        request = self.context.get('request')
        if request and request.user.id == match.buyer_id:
            return match.seller.full_name
        if request and request.user.id == match.seller_id:
            return match.buyer.full_name
        return None

    def get_inventory_title(self, obj):
        if not obj.related_object_id:
            return None
        from apps.matching.models import Match

        match = (
            Match.objects.select_related('inventory_item')
            .filter(pk=obj.related_object_id)
            .first()
        )
        return match.inventory_item.title if match else None
