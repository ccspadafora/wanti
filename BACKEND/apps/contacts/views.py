from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import NotFoundError, PermissionError
from apps.contacts.models import ContactUnlock
from apps.contacts.serializers import (
    ContactUnlockReviewCreateSerializer,
    ContactUnlockSerializer,
    ReportOutcomeSerializer,
)
from apps.contacts.services.contacts import mark_whatsapp_opened, report_outcome
from apps.reviews.services.reviews import create_review


def _get_unlock(unlock_id) -> ContactUnlock:
    try:
        return ContactUnlock.objects.select_related(
            'seller',
            'buyer',
            'match',
            'match__inventory_item',
            'match__inventory_item__vehicle',
            'match__inventory_item__property',
        ).get(pk=unlock_id)
    except ContactUnlock.DoesNotExist as exc:
        raise NotFoundError('Desbloqueo no encontrado') from exc


class ContactUnlockListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        role = request.query_params.get('role', 'buyer')
        if role == 'seller':
            qs = ContactUnlock.objects.filter(seller=request.user)
        else:
            qs = ContactUnlock.objects.filter(buyer=request.user)
        qs = (
            qs.select_related(
                'seller',
                'buyer',
                'match',
                'match__inventory_item',
                'match__inventory_item__vehicle',
                'match__inventory_item__property',
            )
            .order_by('-created_at')
        )
        inventory_item_id = request.query_params.get('inventory_item_id')
        if inventory_item_id:
            qs = qs.filter(match__inventory_item_id=inventory_item_id)
        outcome = request.query_params.get('outcome')
        if outcome:
            qs = qs.filter(outcome=outcome)
        return Response(
            ContactUnlockSerializer(qs, many=True, context={'request': request}).data
        )


class ContactUnlockWhatsAppOpenedView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        unlock = _get_unlock(id)
        mark_whatsapp_opened(unlock, request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ContactUnlockReportOutcomeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        unlock = _get_unlock(id)
        serializer = ReportOutcomeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        unlock = report_outcome(unlock, request.user, serializer.validated_data['outcome'])
        return Response(
            ContactUnlockSerializer(unlock, context={'request': request}).data
        )


class ContactUnlockReviewCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        unlock = _get_unlock(id)
        if request.user.id not in (unlock.buyer_id, unlock.seller_id):
            raise PermissionError()
        serializer = ContactUnlockReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        reviewee = unlock.seller if request.user.id == unlock.buyer_id else unlock.buyer
        review = create_review(
            unlock,
            reviewer=request.user,
            reviewee=reviewee,
            rating=data['rating'],
            comment=data.get('comment', ''),
            tags=data.get('tags') or [],
        )
        return Response(
            {
                'id': review.id,
                'rating': review.rating,
                'comment': review.comment,
                'tags': review.tags,
                'status': review.status,
                'created_at': review.created_at,
            },
            status=status.HTTP_201_CREATED,
        )
