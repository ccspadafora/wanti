from django.db.models import Q
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.common.exceptions import NotFoundError, PermissionError
from apps.contacts.models import ContactUnlock
from apps.disputes.models import Dispute, DisputeAttachment
from apps.disputes.serializers import (
    DisputeAppealSerializer,
    DisputeCreateSerializer,
    DisputeDetailSerializer,
    DisputeListSerializer,
    DisputeRespondAutoSerializer,
    DisputeStatusSerializer,
)
from apps.disputes.services.disputes import (
    appeal_dispute,
    buyer_responds_auto_review,
    cancel_dispute,
    open_dispute,
)


def _get_dispute_for_user(dispute_id, user) -> Dispute:
    try:
        dispute = (
            Dispute.objects.select_related(
                "opened_by",
                "contact_unlock",
                "contact_unlock__buyer",
                "contact_unlock__seller",
            )
            .prefetch_related("attachments", "events")
            .get(pk=dispute_id)
        )
    except Dispute.DoesNotExist as exc:
        raise NotFoundError("Disputa no encontrada") from exc
    unlock = dispute.contact_unlock
    if user.id not in (dispute.opened_by_id, unlock.buyer_id, unlock.seller_id):
        raise PermissionError()
    return dispute


def _get_unlock_for_party(unlock_id, user) -> ContactUnlock:
    try:
        unlock = ContactUnlock.objects.select_related("buyer", "seller", "match").get(
            pk=unlock_id
        )
    except ContactUnlock.DoesNotExist as exc:
        raise NotFoundError("Desbloqueo no encontrado") from exc
    if user.id not in (unlock.buyer_id, unlock.seller_id):
        raise PermissionError()
    return unlock


class DisputeListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = (
            Dispute.objects.filter(
                Q(opened_by=request.user)
                | Q(contact_unlock__buyer=request.user)
                | Q(contact_unlock__seller=request.user)
            )
            .select_related("opened_by", "contact_unlock")
            .distinct()
            .order_by("-created_at")
        )
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        return Response(DisputeListSerializer(qs, many=True).data)


class DisputeDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        dispute = _get_dispute_for_user(id, request.user)
        return Response(DisputeDetailSerializer(dispute).data)


class DisputeCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        unlock = _get_unlock_for_party(id, request.user)
        serializer = DisputeCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        dispute = open_dispute(
            unlock,
            request.user,
            reason=data["reason"],
            description=data.get("description", ""),
        )
        for att in data.get("attachments") or []:
            DisputeAttachment.objects.create(
                dispute=dispute,
                file_url=att["url"],
                file_name=att["name"],
                mime_type=att.get("mime", "application/octet-stream"),
                uploaded_by=request.user,
            )
        dispute = _get_dispute_for_user(dispute.id, request.user)
        return Response(
            DisputeDetailSerializer(dispute).data, status=status.HTTP_201_CREATED
        )


class DisputeRespondAutoView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        dispute = _get_dispute_for_user(id, request.user)
        serializer = DisputeRespondAutoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        dispute = buyer_responds_auto_review(
            dispute,
            request.user,
            confirmed_purchase=serializer.validated_data["confirmed_purchase"],
        )
        return Response(DisputeStatusSerializer(dispute).data)


class DisputeCancelView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        dispute = _get_dispute_for_user(id, request.user)
        dispute = cancel_dispute(dispute, request.user)
        return Response(DisputeStatusSerializer(dispute).data)


class DisputeAppealView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        dispute = _get_dispute_for_user(id, request.user)
        serializer = DisputeAppealSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        dispute = appeal_dispute(
            dispute, request.user, reason=serializer.validated_data.get("reason", "")
        )
        return Response(DisputeStatusSerializer(dispute).data)
