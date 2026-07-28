from rest_framework import serializers

from apps.common.constants import DisputeReason
from apps.disputes.models import Dispute, DisputeAttachment, DisputeEvent


class DisputePartySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()


class DisputeAttachmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = DisputeAttachment
        fields = ('id', 'file_url', 'file_name', 'mime_type', 'created_at')


class DisputeAttachmentInputSerializer(serializers.Serializer):
    url = serializers.URLField(max_length=500)
    name = serializers.CharField(max_length=200)
    mime = serializers.CharField(max_length=80, required=False, default='application/octet-stream')


class DisputeCreateSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(choices=DisputeReason.choices)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    attachments = DisputeAttachmentInputSerializer(many=True, required=False, default=list)


class DisputeEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = DisputeEvent
        fields = ('id', 'event_type', 'payload', 'created_at')


class DisputeListSerializer(serializers.ModelSerializer):
    opened_by = DisputePartySerializer(read_only=True)

    class Meta:
        model = Dispute
        fields = (
            'id',
            'status',
            'reason',
            'opened_by',
            'contact_unlock_id',
            'auto_review_deadline',
            'created_at',
        )


class DisputeDetailSerializer(serializers.ModelSerializer):
    opened_by = DisputePartySerializer(read_only=True)
    attachments = DisputeAttachmentSerializer(many=True, read_only=True)
    events = DisputeEventSerializer(many=True, read_only=True)

    class Meta:
        model = Dispute
        fields = (
            'id',
            'status',
            'reason',
            'description',
            'opened_by',
            'contact_unlock_id',
            'attachments',
            'events',
            'auto_review_deadline',
            'escalated_at',
            'resolved_at',
            'resolution_note',
            'refund_transaction_id',
            'appeal_deadline',
            'buyer_confirmed_purchase',
            'created_at',
            'updated_at',
        )


class DisputeRespondAutoSerializer(serializers.Serializer):
    confirmed_purchase = serializers.BooleanField()


class DisputeAppealSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default='')


class DisputeStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = Dispute
        fields = (
            'id',
            'status',
            'escalated_at',
            'resolved_at',
            'appeal_deadline',
            'updated_at',
        )
