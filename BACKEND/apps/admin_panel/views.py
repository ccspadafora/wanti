from rest_framework.response import Response
from rest_framework.views import APIView

from apps.admin_panel.selectors.metrics import (
    get_dashboard_metrics,
    get_interactions_report,
    get_matching_report,
    list_open_review_disputes,
)
from apps.admin_panel.serializers import (
    AdminDisputeSerializer,
    AdminInventorySerializer,
    AdminNeedSerializer,
    AdminReviewDisputeSerializer,
    AdminTopupSerializer,
    AdminUserDetailSerializer,
    AdminUserSerializer,
    DisputeResolveSerializer,
    FlagNeedSerializer,
    ResolveReviewDisputeSerializer,
    SuspendUserSerializer,
    SystemSettingSerializer,
    SystemSettingUpdateSerializer,
    UnpublishNeedSerializer,
    WalletAdjustSerializer,
)
from apps.audit.models import AuditLog
from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import TransactionType
from apps.common.exceptions import NotFoundError
from apps.common.models import SystemSetting
from apps.common.pagination import StandardPagination
from apps.common.permissions import IsAdmin, IsAdminOrModerator
from apps.common.services.settings_service import invalidate_setting_cache
from apps.disputes.models import Dispute
from apps.disputes.services import disputes as disputes_service
from apps.inventory.models import InventoryItem
from apps.needs.models import Need
from apps.reviews.models import ReviewDispute
from apps.reviews.services.reviews import resolve_review_dispute
from apps.users.selectors.users import get_user_by_id, list_users
from apps.users.services.users import activate_user_by_admin, suspend_user
from apps.wallet.models import TopupOrder
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet


def _paginate(request, view, qs, serializer_class):
    paginator = StandardPagination()
    page = paginator.paginate_queryset(qs, request, view=view)
    return paginator.get_paginated_response(serializer_class(page, many=True).data)


class AdminMetricsView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        return Response(get_dashboard_metrics())


class AdminUserListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = list_users(
            request.user,
            role=request.query_params.get('role'),
            status=request.query_params.get('status'),
            city=request.query_params.get('city'),
            search=request.query_params.get('search'),
        )
        if request.query_params.get('has_disputes', '').lower() in ('true', '1'):
            qs = qs.filter(disputes_opened__isnull=False).distinct()
        return _paginate(request, self, qs, AdminUserSerializer)


class AdminUserDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request, id):
        user = get_user_by_id(id)
        return Response(AdminUserDetailSerializer(user).data)


class AdminUserSuspendView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        serializer = SuspendUserSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = suspend_user(
            id,
            request.user,
            reason=serializer.validated_data['reason'],
        )
        return Response(AdminUserSerializer(user).data)


class AdminUserActivateView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        user = activate_user_by_admin(id, request.user)
        return Response(AdminUserSerializer(user).data)


class AdminNeedListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = Need.objects.select_related('buyer').order_by('-created_at')
        need_status = request.query_params.get('status')
        if need_status:
            qs = qs.filter(status=need_status)
        buyer_id = request.query_params.get('buyer_id')
        if buyer_id:
            qs = qs.filter(buyer_id=buyer_id)
        if request.query_params.get('flagged', '').lower() in ('true', '1'):
            flagged_ids = AuditLog.objects.filter(
                action='NEED_FLAGGED',
                entity='Need',
            ).values_list('entity_id', flat=True)
            qs = qs.filter(id__in=flagged_ids)
        return _paginate(request, self, qs, AdminNeedSerializer)


class AdminNeedFlagView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            need = Need.objects.get(pk=id)
        except Need.DoesNotExist as exc:
            raise NotFoundError('Necesidad no encontrada') from exc
        serializer = FlagNeedSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log_audit_event(
            actor_user=request.user,
            action='NEED_FLAGGED',
            entity='Need',
            entity_id=need.id,
            metadata={'reason': serializer.validated_data.get('reason', '')},
        )
        return Response(AdminNeedSerializer(need).data)


class AdminNeedUnpublishView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            need = Need.objects.get(pk=id)
        except Need.DoesNotExist as exc:
            raise NotFoundError('Necesidad no encontrada') from exc
        serializer = UnpublishNeedSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        need.status = serializer.validated_data.get('status', 'PAUSED')
        need.save(update_fields=['status', 'updated_at'])
        log_audit_event(
            actor_user=request.user,
            action='NEED_UNPUBLISHED',
            entity='Need',
            entity_id=need.id,
            metadata={'status': need.status},
        )
        return Response(AdminNeedSerializer(need).data)


class AdminInventoryListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = InventoryItem.objects.select_related('seller').order_by('-created_at')
        item_status = request.query_params.get('status')
        if item_status:
            qs = qs.filter(status=item_status)
        asset_type = request.query_params.get('asset_type')
        if asset_type:
            qs = qs.filter(asset_type=asset_type)
        return _paginate(request, self, qs, AdminInventorySerializer)


class AdminDisputeListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = Dispute.objects.select_related('opened_by', 'resolved_by').order_by(
            '-created_at'
        )
        dispute_status = request.query_params.get('status')
        if dispute_status:
            qs = qs.filter(status=dispute_status)
        assigned_to = request.query_params.get('assigned_to')
        if assigned_to:
            qs = qs.filter(resolved_by_id=assigned_to)
        return _paginate(request, self, qs, AdminDisputeSerializer)


class AdminDisputeApproveView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            dispute = Dispute.objects.select_related('contact_unlock').get(pk=id)
        except Dispute.DoesNotExist as exc:
            raise NotFoundError('Disputa no encontrada') from exc
        serializer = DisputeResolveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        dispute = disputes_service.approve_dispute(
            dispute,
            request.user,
            resolution_note=serializer.validated_data.get('note', ''),
        )
        return Response(AdminDisputeSerializer(dispute).data)


class AdminDisputeRejectView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            dispute = Dispute.objects.select_related('contact_unlock').get(pk=id)
        except Dispute.DoesNotExist as exc:
            raise NotFoundError('Disputa no encontrada') from exc
        serializer = DisputeResolveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        dispute = disputes_service.reject_dispute(
            dispute,
            request.user,
            resolution_note=serializer.validated_data.get('note', ''),
        )
        return Response(AdminDisputeSerializer(dispute).data)


class AdminTopupListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = TopupOrder.objects.select_related('user', 'package').order_by('-created_at')
        topup_status = request.query_params.get('status')
        if topup_status:
            qs = qs.filter(status=topup_status)
        return _paginate(request, self, qs, AdminTopupSerializer)


class AdminWalletAdjustView(APIView):
    permission_classes = [IsAdmin]

    def post(self, request, user_id):
        user = get_user_by_id(user_id)
        serializer = WalletAdjustSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        wallet = get_or_create_wallet(user)
        txn = apply_transaction(
            wallet=wallet,
            transaction_type=TransactionType.ADJUSTMENT,
            amount_wantis=serializer.validated_data['amount_wantis'],
            related_object=user,
            note=serializer.validated_data['note'],
            created_by=request.user,
        )
        return Response(
            {
                'transaction_id': txn.id,
                'balance_after': txn.balance_after,
                'amount_wantis': txn.amount_wantis,
            }
        )


class AdminReviewDisputeListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = list_open_review_disputes()
        dispute_status = request.query_params.get('status')
        if dispute_status:
            qs = ReviewDispute.objects.filter(status=dispute_status).select_related(
                'review', 'disputed_by'
            )
        return _paginate(request, self, qs, AdminReviewDisputeSerializer)


class AdminReviewDisputeResolveView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            review_dispute = ReviewDispute.objects.select_related('review').get(pk=id)
        except ReviewDispute.DoesNotExist as exc:
            raise NotFoundError('Impugnación no encontrada') from exc
        serializer = ResolveReviewDisputeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        resolve_review_dispute(
            review_dispute,
            request.user,
            keep=serializer.validated_data['keep'],
            note=serializer.validated_data.get('note', ''),
        )
        review_dispute.refresh_from_db()
        return Response(AdminReviewDisputeSerializer(review_dispute).data)


class AdminInteractionsReportView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        return Response(
            get_interactions_report(date_from=date_from, date_to=date_to)
        )


class AdminMatchingReportView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        return Response(get_matching_report())


class AdminSettingsListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = SystemSetting.objects.all().order_by('key')
        return Response(SystemSettingSerializer(qs, many=True).data)


class AdminSettingsUpdateView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, key):
        try:
            setting = SystemSetting.objects.get(key=key)
        except SystemSetting.DoesNotExist as exc:
            raise NotFoundError('Setting no encontrado') from exc
        serializer = SystemSettingUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        setting.value = serializer.validated_data['value']
        setting.updated_by = request.user
        setting.save(update_fields=['value', 'updated_by', 'updated_at'])
        invalidate_setting_cache(key)
        return Response(SystemSettingSerializer(setting).data)
