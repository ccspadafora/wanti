from rest_framework import serializers

from apps.reviews.models import Review, ReviewDispute, ReviewTag


class ReviewTagSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewTag
        fields = ('code', 'label', 'for_role')
        read_only_fields = fields


class ReviewerBriefSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    full_name = serializers.CharField()


class ReviewCreateSerializer(serializers.Serializer):
    rating = serializers.IntegerField(min_value=1, max_value=5)
    comment = serializers.CharField(required=False, allow_blank=True, default='')
    tags = serializers.ListField(
        child=serializers.CharField(max_length=50),
        required=False,
        default=list,
    )


class ReviewDisputeCreateSerializer(serializers.Serializer):
    reason = serializers.CharField()


class ReviewSerializer(serializers.ModelSerializer):
    reviewer = ReviewerBriefSerializer(read_only=True)
    reviewee = ReviewerBriefSerializer(read_only=True)

    class Meta:
        model = Review
        fields = (
            'id',
            'contact_unlock',
            'reviewer',
            'reviewee',
            'rating',
            'comment',
            'tags',
            'status',
            'created_at',
            'updated_at',
        )
        read_only_fields = fields


class ReviewPublicSerializer(serializers.ModelSerializer):
    reviewer = ReviewerBriefSerializer(read_only=True)

    class Meta:
        model = Review
        fields = ('id', 'reviewer', 'rating', 'comment', 'tags', 'created_at')
        read_only_fields = fields


class ReviewDisputeSerializer(serializers.ModelSerializer):
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
