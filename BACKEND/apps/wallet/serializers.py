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
    order_id = serializers.UUIDField()
    status = serializers.ChoiceField(
        choices=[TopupStatus.COMPLETED, TopupStatus.FAILED],
    )
    provider_reference = serializers.CharField(required=False, allow_blank=True, default='')
    provider_payload = serializers.DictField(required=False, default=dict)


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = (
            'id',
            'transaction_type',
            'amount_wantis',
            'balance_after',
            'note',
            'related_object_type',
            'related_object_id',
            'created_at',
        )
