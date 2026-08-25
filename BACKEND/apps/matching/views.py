from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.constants import MatchStatus
from apps.common.exceptions import PermissionError
from apps.contacts.services.contacts import unlock_contact
from apps.matching.models import Match
from apps.matching.selectors.matches import (
    get_match_detail,
    list_alerts_for_seller,
)
from apps.matching.serializers import (
    MatchDetailSerializer,
    MatchListSerializer,
    UnlockContactResponseSerializer,
)


class MatchListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        role = request.query_params.get('role', 'buyer')
        if role == 'seller':
            qs = list_alerts_for_seller(request.user)
            inventory_item_id = request.query_params.get('inventory_item_id')
            if inventory_item_id:
                qs = qs.filter(inventory_item_id=inventory_item_id)
        else:
            qs = (
                Match.objects.filter(buyer=request.user)
                .exclude(status=MatchStatus.DISCARDED)
                .select_related(
                    'inventory_item',
                    'seller',
                    'need',
                    'buyer',
                    'unlock',
                )
                .prefetch_related(
                    'inventory_item__images',
                    'inventory_item__vehicle',
                    'inventory_item__property',
                )
                .order_by('-score')
            )
            need_id = request.query_params.get('need_id')
            if need_id:
                qs = qs.filter(need_id=need_id)

        match_status = request.query_params.get('status')
        if match_status:
            qs = qs.filter(status=match_status)
        min_score = request.query_params.get('min_score')
        if min_score is not None:
            qs = qs.filter(score__gte=int(min_score))
        ordering = request.query_params.get('ordering')
        if ordering and ordering.lstrip('-') in ('score', 'created_at'):
            qs = qs.order_by(ordering)

        return Response(
            MatchListSerializer(qs, many=True, context={'request': request}).data
        )


class MatchDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        match = get_match_detail(id, request.user)
        if (
            request.user.id == match.buyer_id
            and match.status == MatchStatus.GENERATED
        ):
            match.status = MatchStatus.VIEWED
            match.viewed_at = timezone.now()
            match.save(update_fields=['status', 'viewed_at', 'updated_at'])
        return Response(MatchDetailSerializer(match, context={'request': request}).data)


class MatchDiscardView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        match = get_match_detail(id, request.user)
        if request.user.id not in (match.buyer_id, match.seller_id):
            raise PermissionError('Solo las partes del match pueden descartarlo')
        match.status = MatchStatus.DISCARDED
        match.discarded_at = timezone.now()
        match.save(update_fields=['status', 'discarded_at', 'updated_at'])
        return Response(MatchDetailSerializer(match, context={'request': request}).data)


class MatchUnlockView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, match_id):
        match = get_match_detail(match_id, request.user)
        idem = (
            request.headers.get('Idempotency-Key')
            or request.data.get('idempotency_key')
            or ''
        )
        unlock, created = unlock_contact(
            match,
            request.user,
            idempotency_key=str(idem).strip() or None,
        )
        lead = getattr(unlock, 'lead', None)
        payload = {
            'unlock_id': unlock.id,
            'wantis_charged': unlock.wantis_charged if created else 0,
            'already_unlocked': not created,
            'seller_phone': unlock.seller.phone if request.user.id == unlock.buyer_id else None,
            'buyer_phone': unlock.buyer.phone if request.user.id == unlock.seller_id else None,
            'buyer_email': unlock.buyer.email if request.user.id == unlock.seller_id else None,
            'lead_id': lead.id if lead else None,
        }
        return Response(
            UnlockContactResponseSerializer(payload).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )
