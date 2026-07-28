from django.utils import timezone
from rest_framework import serializers

from apps.common.constants import LeadStage
from apps.leads.models import Lead, LeadNote


class LeadBuyerSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()
    phone = serializers.CharField()
    rating_average = serializers.FloatField(allow_null=True)


class LeadContactUnlockSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    inventory_item_title = serializers.CharField()
    price_cop = serializers.DecimalField(max_digits=15, decimal_places=2)


class LeadNoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeadNote
        fields = ('id', 'text', 'stage_at_time', 'author', 'created_at')
        read_only_fields = fields


class LeadNoteCreateSerializer(serializers.Serializer):
    text = serializers.CharField()


class LeadChangeStageSerializer(serializers.Serializer):
    stage = serializers.ChoiceField(choices=LeadStage.choices)
    sold_price_cop = serializers.DecimalField(
        max_digits=15,
        decimal_places=2,
        required=False,
        allow_null=True,
    )

    def validate(self, attrs):
        if attrs['stage'] == LeadStage.PURCHASED and attrs.get('sold_price_cop') is None:
            raise serializers.ValidationError(
                {'sold_price_cop': 'Requerido cuando stage=PURCHASED'}
            )
        return attrs


class LeadListSerializer(serializers.ModelSerializer):
    buyer = serializers.SerializerMethodField()
    contact_unlock = serializers.SerializerMethodField()
    days_until_expiry = serializers.SerializerMethodField()
    notes_count = serializers.SerializerMethodField()

    class Meta:
        model = Lead
        fields = (
            'id',
            'buyer',
            'contact_unlock',
            'stage',
            'last_activity_at',
            'expires_at',
            'days_until_expiry',
            'notes_count',
            'sold_price_cop',
            'created_at',
        )
        read_only_fields = fields

    def get_buyer(self, obj):
        return LeadBuyerSerializer(
            {
                'id': obj.buyer.id,
                'full_name': obj.buyer.full_name,
                'phone': obj.buyer.phone,
                'rating_average': obj.buyer.rating_average,
            }
        ).data

    def get_contact_unlock(self, obj):
        unlock = obj.contact_unlock
        item = unlock.match.inventory_item
        return LeadContactUnlockSerializer(
            {
                'id': unlock.id,
                'inventory_item_title': item.title,
                'price_cop': item.price_cop,
            }
        ).data

    def get_days_until_expiry(self, obj):
        delta = obj.expires_at - timezone.now()
        return max(delta.days, 0)

    def get_notes_count(self, obj):
        if hasattr(obj, 'notes_count'):
            return obj.notes_count
        return obj.notes.count()


class LeadDetailSerializer(LeadListSerializer):
    notes = LeadNoteSerializer(many=True, read_only=True)

    class Meta(LeadListSerializer.Meta):
        fields = LeadListSerializer.Meta.fields + ('notes',)
