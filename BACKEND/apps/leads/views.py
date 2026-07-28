from django.db.models import Count, Q
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import NotFoundError, PermissionError
from apps.common.pagination import StandardPagination
from apps.leads.models import Lead
from apps.leads.serializers import (
    LeadChangeStageSerializer,
    LeadDetailSerializer,
    LeadListSerializer,
    LeadNoteCreateSerializer,
    LeadNoteSerializer,
)
from apps.leads.services import leads as leads_service


def _get_seller_lead(lead_id, seller):
    try:
        lead = (
            Lead.objects.select_related(
                'buyer',
                'contact_unlock',
                'contact_unlock__match',
                'contact_unlock__match__inventory_item',
            )
            .prefetch_related('notes')
            .get(pk=lead_id)
        )
    except Lead.DoesNotExist as exc:
        raise NotFoundError('Lead no encontrado') from exc
    if lead.seller_id != seller.id:
        raise PermissionError()
    return lead


class LeadListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            Lead.objects.filter(seller=request.user)
            .select_related(
                'buyer',
                'contact_unlock',
                'contact_unlock__match',
                'contact_unlock__match__inventory_item',
            )
            .annotate(notes_count=Count('notes'))
        )
        stage = request.query_params.get('stage')
        if stage:
            qs = qs.filter(stage=stage)
        search = request.query_params.get('search')
        if search:
            qs = qs.filter(Q(buyer__full_name__icontains=search))
        ordering = request.query_params.get('ordering', '-last_activity_at')
        if ordering.lstrip('-') in ('last_activity_at', 'created_at', 'expires_at'):
            qs = qs.order_by(ordering)
        else:
            qs = qs.order_by('-last_activity_at')

        paginator = StandardPagination()
        page = paginator.paginate_queryset(qs, request, view=self)
        return paginator.get_paginated_response(LeadListSerializer(page, many=True).data)


class LeadDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        lead = _get_seller_lead(id, request.user)
        return Response(LeadDetailSerializer(lead).data)


class LeadChangeStageView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        lead = _get_seller_lead(id, request.user)
        serializer = LeadChangeStageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        lead = leads_service.change_stage(
            lead,
            request.user,
            stage=serializer.validated_data['stage'],
            sold_price_cop=serializer.validated_data.get('sold_price_cop'),
        )
        lead = _get_seller_lead(lead.id, request.user)
        return Response(LeadDetailSerializer(lead).data)


class LeadNotesListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        lead = _get_seller_lead(id, request.user)
        notes = lead.notes.select_related('author').order_by('-created_at')
        return Response(LeadNoteSerializer(notes, many=True).data)

    def post(self, request, id):
        lead = _get_seller_lead(id, request.user)
        serializer = LeadNoteCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        note = leads_service.add_note(
            lead,
            request.user,
            text=serializer.validated_data['text'],
        )
        return Response(LeadNoteSerializer(note).data, status=status.HTTP_201_CREATED)
