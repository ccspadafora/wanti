from rest_framework import serializers

from apps.common.models import SystemSetting
from apps.disputes.models import Dispute
from apps.inventory.models import InventoryItem
from apps.needs.models import Need
from apps.reviews.models import ReviewDispute
from apps.users.models import User
from apps.wallet.models import TopupOrder


class AdminUserSerializer(serializers.ModelSerializer):
    rating_average = serializers.SerializerMethodField()
    is_fully_verified = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = (
            'id',
            'email',
            'full_name',
            'phone',
            'city',
            'role',
            'status',
            'id_type',
            'id_number',
            'email_verified_at',
            'phone_verified_at',
            'is_fully_verified',
            'rating_average',
            'profile_photo_url',
            'created_at',
            'last_login_at',
        )
        read_only_fields = fields

    def get_rating_average(self, obj):
        return obj.rating_average


class AdminUserDetailSerializer(AdminUserSerializer):
    wallet_balance = serializers.SerializerMethodField()
    disputes_count = serializers.SerializerMethodField()

    class Meta(AdminUserSerializer.Meta):
        fields = AdminUserSerializer.Meta.fields + ('wallet_balance', 'disputes_count')

    def get_wallet_balance(self, obj):
        from apps.wallet.models import Wallet

        wallet = Wallet.objects.filter(user=obj).first()
        return wallet.balance_wantis if wallet else 0

    def get_disputes_count(self, obj):
        return obj.disputes_opened.count()


class SuspendUserSerializer(serializers.Serializer):
    reason = serializers.CharField()


class AdminNeedSerializer(serializers.ModelSerializer):
    class Meta:
        model = Need
        fields = (
            'id',
            'buyer',
            'asset_type',
            'title',
            'budget_max_cop',
            'payment_type',
            'city',
            'status',
            'matches_count',
            'views_count',
            'expires_at',
            'created_at',
        )
        read_only_fields = fields


class FlagNeedSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default='')


class UnpublishNeedSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=[('PAUSED', 'PAUSED'), ('DELETED', 'DELETED')],
        default='PAUSED',
        required=False,
    )


class AdminInventorySerializer(serializers.ModelSerializer):
    class Meta:
        model = InventoryItem
        fields = (
            'id',
            'seller',
            'asset_type',
            'title',
            'price_cop',
            'city',
            'status',
            'views_count',
            'unlock_count',
            'created_at',
        )
        read_only_fields = fields


class AdminDisputeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Dispute
        fields = (
            'id',
            'contact_unlock',
            'opened_by',
            'reason',
            'description',
            'status',
            'resolved_by',
            'resolution_note',
            'resolved_at',
            'created_at',
        )
        read_only_fields = fields


class DisputeResolveSerializer(serializers.Serializer):
    note = serializers.CharField(required=False, allow_blank=True, default='')


class AdminTopupSerializer(serializers.ModelSerializer):
    class Meta:
        model = TopupOrder
        fields = (
            'id',
            'user',
            'package',
            'wantis_total',
            'price_cop',
            'status',
            'provider_reference',
            'completed_at',
            'created_at',
        )
        read_only_fields = fields


class WalletAdjustSerializer(serializers.Serializer):
    amount_wantis = serializers.IntegerField()
    note = serializers.CharField()


class AdminReviewDisputeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewDispute
        fields = (
            'id',
            'review',
            'disputed_by',
            'reason',
            'status',
            'resolved_by',
            'resolved_at',
            'admin_note',
            'created_at',
        )
        read_only_fields = fields


class ResolveReviewDisputeSerializer(serializers.Serializer):
    keep = serializers.BooleanField()
    note = serializers.CharField(required=False, allow_blank=True, default='')


class SystemSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemSetting
        fields = ('key', 'value', 'value_type', 'description', 'updated_at')
        read_only_fields = fields


class SystemSettingUpdateSerializer(serializers.Serializer):
    value = serializers.CharField(max_length=255)
