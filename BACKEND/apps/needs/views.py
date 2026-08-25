from decimal import Decimal, InvalidOperation

from django.db.models import F
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.common.permissions import IsFullyVerified
from apps.matching.selectors.matches import list_matches_for_need
from apps.matching.serializers import MatchListSerializer
from apps.needs.models import Need
from apps.needs.selectors.needs import (
    get_need_by_id,
    list_own_needs,
    search_active_needs,
)
from apps.needs.serializers import (
    NeedCreateSerializer,
    NeedListSerializer,
    NeedPublishSerializer,
    NeedSerializer,
    NeedStatusSerializer,
    NeedUpdateSerializer,
)
from apps.needs.services import needs as needs_service


def _parse_int_param(value):
    if value in (None, ''):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _parse_decimal_param(value):
    if value in (None, ''):
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return None


def _search_params(request):
    return {
        'asset_type': request.query_params.get('asset_type'),
        'city': request.query_params.get('city'),
        'brand': request.query_params.get('brand'),
        'model': request.query_params.get('model'),
        'line': request.query_params.get('line'),
        'year': _parse_int_param(request.query_params.get('year')),
        'vehicle_category': request.query_params.get('vehicle_category'),
        'fuel_type': request.query_params.get('fuel_type'),
        'transmission': request.query_params.get('transmission'),
        'property_type': request.query_params.get('property_type'),
        'listing_intent': request.query_params.get('listing_intent'),
        'bedrooms_min': _parse_int_param(request.query_params.get('bedrooms_min')),
        'bathrooms_min': _parse_int_param(request.query_params.get('bathrooms_min')),
        'area_min_sqm': _parse_int_param(request.query_params.get('area_min_sqm')),
        'socioeconomic_stratum': _parse_int_param(
            request.query_params.get('socioeconomic_stratum')
        ),
        'parking_spots_min': _parse_int_param(request.query_params.get('parking_spots_min')),
        'max_budget': _parse_decimal_param(request.query_params.get('max_budget')),
        'ordering': request.query_params.get('ordering', '-created_at'),
    }


class NeedListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsFullyVerified()]
        return [IsAuthenticated()]

    def get_throttles(self):
        if self.request.method == 'POST':
            self.throttle_scope = 'need_create'
            return [ScopedRateThrottle()]
        return []

    def get(self, request):
        scope = request.query_params.get('scope')
        if scope == 'browse':
            qs = search_active_needs(request.user, **_search_params(request))
            serializer = NeedListSerializer(qs, many=True)
        else:
            qs = list_own_needs(request.user).select_related('vehicle', 'property').prefetch_related(
                'images'
            )
            serializer = NeedListSerializer(qs, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = NeedCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        need = needs_service.create_need(request.user, serializer.to_service_data())
        return Response(NeedSerializer(need).data, status=status.HTTP_201_CREATED)


class NeedSearchView(APIView):
    """Structured manual search — independent from matching and viewer inventory."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = search_active_needs(request.user, **_search_params(request))
        return Response(NeedListSerializer(qs, many=True).data)


class NeedDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        if need.buyer_id != request.user.id:
            Need.objects.filter(pk=need.pk).update(views_count=F('views_count') + 1)
            need.views_count += 1
        return Response(NeedSerializer(need).data)

    def patch(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        serializer = NeedUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        need = needs_service.update_need(need, request.user, serializer.to_service_data())
        return Response(NeedSerializer(need).data)

    def delete(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        needs_service.delete_need(need, request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class NeedPublishView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        serializer = NeedPublishSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        need = needs_service.publish_need(
            need,
            request.user,
            legal_accepted=serializer.validated_data['legal_accepted'],
        )
        return Response(NeedStatusSerializer(need).data)


class NeedPauseView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        need = needs_service.pause_need(need, request.user)
        return Response(NeedStatusSerializer(need).data)


class NeedResumeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        need = needs_service.resume_need(need, request.user)
        return Response(NeedStatusSerializer(need).data)


class NeedRenewView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        need = needs_service.renew_need(need, request.user)
        return Response(NeedStatusSerializer(need).data)


class NeedMatchesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        need = get_need_by_id(id, actor_user=request.user)
        matches = list_matches_for_need(need, request.user)
        return Response(MatchListSerializer(matches, many=True).data)
