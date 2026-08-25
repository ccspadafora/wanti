from rest_framework import serializers

from apps.audit.models import AuditLog
from apps.common.constants import (
    AssetType,
    IdType,
    InventoryStatus,
    NeedStatus,
    PaymentType,
    PropertyType,
    UserRole,
    UserStatus,
    VehicleCategory,
)
from apps.common.models import SystemSetting
from apps.contacts.models import ContactUnlock
from apps.disputes.models import Dispute
from apps.inventory.models import InventoryItem
from apps.matching.models import Match
from apps.needs.models import Need
from apps.notifications.models import Notification
from apps.reviews.models import ReviewDispute, ReviewTag
from apps.users.models import User
from apps.wallet.models import TopupOrder, TopupPackage, WalletTransaction


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


class AdminVerifyUserSerializer(serializers.Serializer):
    email = serializers.BooleanField(required=False, default=False)
    phone = serializers.BooleanField(required=False, default=False)


class AdminSetRoleSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=UserRole.choices)


class AdminUserUpdateSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150, required=False)
    phone = serializers.CharField(max_length=20, required=False)
    city = serializers.CharField(max_length=100, required=False)
    id_type = serializers.ChoiceField(choices=IdType.choices, required=False)
    id_number = serializers.CharField(max_length=30, required=False)
    status = serializers.ChoiceField(choices=UserStatus.choices, required=False)
    profile_photo_url = serializers.URLField(
        max_length=500, required=False, allow_blank=True, allow_null=True
    )


class AdminUserCreateSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    full_name = serializers.CharField(max_length=150)
    id_type = serializers.ChoiceField(choices=IdType.choices, default=IdType.CC)
    id_number = serializers.CharField(max_length=30)
    phone = serializers.CharField(max_length=20)
    city = serializers.CharField(max_length=100)
    role = serializers.ChoiceField(choices=UserRole.choices, required=False, default=UserRole.USER)
    status = serializers.ChoiceField(
        choices=UserStatus.choices, required=False, default=UserStatus.ACTIVE
    )
    verify_email = serializers.BooleanField(required=False, default=True)
    verify_phone = serializers.BooleanField(required=False, default=True)


class AdminLocationSerializer(serializers.Serializer):
    latitude = serializers.FloatField(required=False, default=4.711)
    longitude = serializers.FloatField(required=False, default=-74.0721)


class AdminNeedCreateSerializer(serializers.Serializer):
    buyer_id = serializers.UUIDField()
    asset_type = serializers.ChoiceField(choices=AssetType.choices)
    title = serializers.CharField(max_length=150)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    budget_max_cop = serializers.DecimalField(max_digits=15, decimal_places=2, min_value=0)
    payment_type = serializers.ChoiceField(choices=PaymentType.choices, default=PaymentType.CASH)
    city = serializers.CharField(max_length=100)
    location = AdminLocationSerializer(required=False)
    publish = serializers.BooleanField(required=False, default=True)
    # Vehicle detail
    brand = serializers.CharField(max_length=80, required=False, allow_blank=True, default='')
    model = serializers.CharField(max_length=80, required=False, allow_blank=True, default='')
    vehicle_category = serializers.ChoiceField(
        choices=VehicleCategory.choices, required=False, default=VehicleCategory.CAR
    )
    # Property detail
    property_type = serializers.ChoiceField(
        choices=PropertyType.choices, required=False, default=PropertyType.APTO
    )


class AdminInventoryCreateSerializer(serializers.Serializer):
    seller_id = serializers.UUIDField()
    asset_type = serializers.ChoiceField(choices=AssetType.choices)
    title = serializers.CharField(max_length=150)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    price_cop = serializers.DecimalField(max_digits=15, decimal_places=2, min_value=0)
    city = serializers.CharField(max_length=100)
    location = AdminLocationSerializer(required=False)
    brand = serializers.CharField(max_length=80, required=False, allow_blank=True, default='')
    model = serializers.CharField(max_length=80, required=False, allow_blank=True, default='')
    year = serializers.IntegerField(required=False, default=2020)
    mileage_km = serializers.IntegerField(required=False, default=0, min_value=0)
    vehicle_category = serializers.ChoiceField(
        choices=VehicleCategory.choices, required=False, default=VehicleCategory.CAR
    )
    property_type = serializers.ChoiceField(
        choices=PropertyType.choices, required=False, default=PropertyType.APTO
    )


class AdminNotificationCreateSerializer(serializers.Serializer):
    recipient_id = serializers.UUIDField()
    title = serializers.CharField(max_length=150)
    body = serializers.CharField()
    template_code = serializers.CharField(max_length=80, required=False, default='ADMIN_MANUAL')


class AdminNeedSerializer(serializers.ModelSerializer):
    class Meta:
        model = Need
        fields = (
            'id',
            'buyer',
            'asset_type',
            'title',
            'description',
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


class AdminNeedUpdateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150, required=False)
    description = serializers.CharField(required=False, allow_blank=True)
    budget_max_cop = serializers.DecimalField(
        max_digits=15, decimal_places=2, min_value=0, required=False
    )
    payment_type = serializers.ChoiceField(choices=PaymentType.choices, required=False)
    city = serializers.CharField(max_length=100, required=False)
    status = serializers.ChoiceField(choices=NeedStatus.choices, required=False)


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
            'description',
            'price_cop',
            'city',
            'status',
            'views_count',
            'unlock_count',
            'created_at',
        )
        read_only_fields = fields


class AdminInventoryUpdateSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=150, required=False)
    description = serializers.CharField(required=False, allow_blank=True)
    price_cop = serializers.DecimalField(
        max_digits=15, decimal_places=2, min_value=0, required=False
    )
    city = serializers.CharField(max_length=100, required=False)
    status = serializers.ChoiceField(choices=InventoryStatus.choices, required=False)


class FlagInventorySerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default='')


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
    user_email = serializers.EmailField(source='user.email', read_only=True)
    package_name = serializers.CharField(source='package.name', read_only=True)

    class Meta:
        model = TopupOrder
        fields = (
            'id',
            'user',
            'user_email',
            'package',
            'package_name',
            'wantis_total',
            'price_cop',
            'status',
            'provider_reference',
            'completed_at',
            'created_at',
        )
        read_only_fields = fields


class AdminPackageSerializer(serializers.ModelSerializer):
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
            'is_active',
            'order',
            'created_at',
            'updated_at',
        )
        read_only_fields = ('id', 'wantis_total', 'created_at', 'updated_at')


class AdminPackageWriteSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=80)
    wantis_base = serializers.IntegerField(min_value=1)
    wantis_bonus = serializers.IntegerField(min_value=0, required=False, default=0)
    price_cop = serializers.DecimalField(max_digits=15, decimal_places=2, min_value=0)
    is_popular = serializers.BooleanField(required=False, default=False)
    is_active = serializers.BooleanField(required=False, default=True)
    order = serializers.IntegerField(required=False, default=0)


class AdminPackageUpdateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=80, required=False)
    wantis_base = serializers.IntegerField(min_value=1, required=False)
    wantis_bonus = serializers.IntegerField(min_value=0, required=False)
    price_cop = serializers.DecimalField(
        max_digits=15, decimal_places=2, min_value=0, required=False
    )
    is_popular = serializers.BooleanField(required=False)
    is_active = serializers.BooleanField(required=False)
    order = serializers.IntegerField(required=False)


class WalletAdjustSerializer(serializers.Serializer):
    amount_wantis = serializers.IntegerField()
    note = serializers.CharField()


class AdminWalletTransactionSerializer(serializers.ModelSerializer):
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
        read_only_fields = fields


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


class AdminReviewTagSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewTag
        fields = ('id', 'code', 'label', 'for_role', 'order', 'is_active')
        read_only_fields = ('id',)


class SystemSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemSetting
        fields = ('key', 'value', 'value_type', 'description', 'updated_at')
        read_only_fields = fields


class SystemSettingUpdateSerializer(serializers.Serializer):
    value = serializers.CharField(max_length=255)


class SystemSettingCreateSerializer(serializers.Serializer):
    key = serializers.CharField(max_length=100)
    value = serializers.CharField(max_length=255)
    value_type = serializers.ChoiceField(
        choices=['INT', 'DECIMAL', 'BOOL', 'STRING'],
        default='STRING',
        required=False,
    )
    description = serializers.CharField(required=False, allow_blank=True, default='')


class AdminAuditLogSerializer(serializers.ModelSerializer):
    actor_email = serializers.SerializerMethodField()

    class Meta:
        model = AuditLog
        fields = (
            'id',
            'actor_user',
            'actor_email',
            'action',
            'entity',
            'entity_id',
            'metadata',
            'ip_address',
            'created_at',
        )
        read_only_fields = fields

    def get_actor_email(self, obj):
        return getattr(obj.actor_user, 'email', None)


class AdminNotificationSerializer(serializers.ModelSerializer):
    recipient_email = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = (
            'id',
            'recipient',
            'recipient_email',
            'channel',
            'template_code',
            'title',
            'body',
            'delivery_status',
            'created_at',
        )
        read_only_fields = fields

    def get_recipient_email(self, obj):
        return getattr(obj.recipient, 'email', None)


class AdminMatchSerializer(serializers.ModelSerializer):
    class Meta:
        model = Match
        fields = (
            'id',
            'need',
            'inventory_item',
            'buyer',
            'seller',
            'score',
            'status',
            'created_at',
            'discarded_at',
        )
        read_only_fields = fields


class AdminContactUnlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = ContactUnlock
        fields = (
            'id',
            'match',
            'buyer',
            'seller',
            'wantis_charged',
            'outcome',
            'created_at',
        )
        read_only_fields = fields
