from django.db.models import F, Q
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
    list_needs_for_seller_search,
    list_own_needs,
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
            qs = list_needs_for_seller_search(
                request.user,
                asset_type=request.query_params.get('asset_type'),
                city=request.query_params.get('city'),
            )
            search = request.query_params.get('search')
            if search:
                qs = qs.filter(Q(title__icontains=search) | Q(description__icontains=search))
            ordering = request.query_params.get('ordering', '-created_at')
            if ordering.lstrip('-') in ('created_at', 'matches_count', 'budget_max_cop'):
                qs = qs.order_by(ordering)
            serializer = NeedListSerializer(qs, many=True)
        else:
            qs = list_own_needs(request.user)
            serializer = NeedListSerializer(qs, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = NeedCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        need = needs_service.create_need(request.user, serializer.to_service_data())
        return Response(NeedSerializer(need).data, status=status.HTTP_201_CREATED)


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
