from django.contrib.gis.geos import Point
from django.utils import timezone
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status

from apps.admin_panel.selectors.metrics import (
    get_dashboard_metrics,
    get_interactions_report,
    get_matching_report,
    list_open_review_disputes,
)
from apps.admin_panel.serializers import (
    AdminAuditLogSerializer,
    AdminContactUnlockSerializer,
    AdminDisputeSerializer,
    AdminInventoryCreateSerializer,
    AdminInventorySerializer,
    AdminInventoryUpdateSerializer,
    AdminMatchSerializer,
    AdminNeedCreateSerializer,
    AdminNeedSerializer,
    AdminNeedUpdateSerializer,
    AdminNotificationCreateSerializer,
    AdminNotificationSerializer,
    AdminPackageSerializer,
    AdminPackageUpdateSerializer,
    AdminPackageWriteSerializer,
    AdminReviewDisputeSerializer,
    AdminReviewTagSerializer,
    AdminSetRoleSerializer,
    AdminTopupSerializer,
    AdminUserCreateSerializer,
    AdminUserDetailSerializer,
    AdminUserSerializer,
    AdminUserUpdateSerializer,
    AdminVerifyUserSerializer,
    AdminWalletTransactionSerializer,
    DisputeResolveSerializer,
    FlagInventorySerializer,
    FlagNeedSerializer,
    ResolveReviewDisputeSerializer,
    SuspendUserSerializer,
    SystemSettingCreateSerializer,
    SystemSettingSerializer,
    SystemSettingUpdateSerializer,
    UnpublishNeedSerializer,
    WalletAdjustSerializer,
)
from apps.audit.models import AuditLog
from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import AssetType, NeedStatus, NotificationChannel, TransactionType
from apps.common.exceptions import NotFoundError
from apps.common.models import SystemSetting
from apps.common.pagination import StandardPagination
from apps.common.permissions import IsAdmin, IsAdminOrModerator
from apps.common.services.settings_service import invalidate_setting_cache
from apps.contacts.models import ContactUnlock
from apps.disputes.models import Dispute
from apps.disputes.services import disputes as disputes_service
from apps.inventory.models import InventoryItem
from apps.inventory.services import inventory as inventory_service
from apps.matching.models import Match
from apps.needs.models import Need
from apps.needs.services import needs as needs_service
from apps.notifications.models import Notification
from apps.reviews.models import ReviewDispute, ReviewTag
from apps.reviews.services.reviews import resolve_review_dispute
from apps.users.selectors.users import get_user_by_id, list_users
from apps.users.services.users import (
    activate_user_by_admin,
    admin_set_user_role,
    admin_verify_user,
    register_user,
    suspend_user,
)
from apps.wallet.models import TopupOrder, TopupPackage, WalletTransaction
from apps.wallet.services import packages as packages_service
from apps.wallet.services.wallet import apply_transaction, get_or_create_wallet


def _point_from_location(loc: dict | None) -> Point:
    loc = loc or {}
    lat = float(loc.get('latitude', 4.711))
    lng = float(loc.get('longitude', -74.0721))
    return Point(lng, lat, srid=4326)


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

    def post(self, request):
        serializer = AdminUserCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        user = register_user(
            {
                'email': data['email'],
                'password': data['password'],
                'full_name': data['full_name'],
                'id_type': data['id_type'],
                'id_number': data['id_number'],
                'phone': data['phone'],
                'city': data['city'],
            },
            ip_address=request.META.get('REMOTE_ADDR'),
        )
        user.role = data.get('role') or user.role
        user.status = data.get('status') or user.status
        if data.get('verify_email', True):
            user.email_verified_at = timezone.now()
        if data.get('verify_phone', True):
            user.phone_verified_at = timezone.now()
        if user.role in ('ADMIN', 'MODERATOR'):
            user.is_staff = True
        user.save()
        log_audit_event(
            actor_user=request.user,
            action='ADMIN_USER_CREATE',
            entity='User',
            entity_id=user.id,
            metadata={'email': user.email, 'role': user.role},
        )
        return Response(
            AdminUserDetailSerializer(user).data,
            status=status.HTTP_201_CREATED,
        )


class AdminUserDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request, id):
        user = get_user_by_id(id)
        return Response(AdminUserDetailSerializer(user).data)

    def patch(self, request, id):
        user = get_user_by_id(id)
        serializer = AdminUserUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        if data:
            for field, value in data.items():
                setattr(user, field, value)
            user.save(update_fields=[*data.keys(), 'updated_at'])
            log_audit_event(
                actor_user=request.user,
                action='ADMIN_USER_UPDATE',
                entity='User',
                entity_id=user.id,
                metadata={'fields': list(data.keys())},
            )
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


class AdminUserVerifyView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        serializer = AdminVerifyUserSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = admin_verify_user(
            id,
            request.user,
            email=serializer.validated_data.get('email', False),
            phone=serializer.validated_data.get('phone', False),
        )
        return Response(AdminUserDetailSerializer(user).data)


class AdminUserSetRoleView(APIView):
    permission_classes = [IsAdmin]

    def post(self, request, id):
        serializer = AdminSetRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = admin_set_user_role(
            id, request.user, role=serializer.validated_data['role']
        )
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

    def post(self, request):
        serializer = AdminNeedCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = dict(serializer.validated_data)
        buyer = get_user_by_id(data.pop('buyer_id'))
        publish = data.pop('publish', True)
        loc = data.pop('location', None)
        brand = data.pop('brand', '') or 'Genérico'
        model = data.pop('model', '') or 'N/A'
        vehicle_category = data.pop('vehicle_category', 'CAR')
        property_type = data.pop('property_type', 'APTO')
        if data['asset_type'] == AssetType.VEHICLE:
            detail = {
                'brand': brand,
                'model': model,
                'vehicle_category': vehicle_category,
            }
        else:
            detail = {'property_type': property_type}
        need = needs_service.create_need(
            buyer,
            {
                **data,
                'location': _point_from_location(loc),
                'detail': detail,
            },
            bypass_verification=True,
        )
        if publish:
            from datetime import timedelta

            from apps.common.services.settings_service import get_setting
            from apps.matching.tasks import run_match_for_need_task

            days = get_setting('NEED_DURATION_DAYS', 30)
            need.status = NeedStatus.ACTIVE
            need.expires_at = timezone.now() + timedelta(days=days)
            need.legal_disclaimer_accepted_at = timezone.now()
            need.save(
                update_fields=[
                    'status',
                    'expires_at',
                    'legal_disclaimer_accepted_at',
                    'updated_at',
                ]
            )
            run_match_for_need_task.delay(str(need.id))
        log_audit_event(
            actor_user=request.user,
            action='ADMIN_NEED_CREATE',
            entity='Need',
            entity_id=need.id,
            metadata={'buyer_id': str(buyer.id), 'publish': publish},
        )
        return Response(AdminNeedSerializer(need).data, status=status.HTTP_201_CREATED)


class AdminNeedDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request, id):
        try:
            need = Need.objects.select_related('buyer').get(pk=id)
        except Need.DoesNotExist as exc:
            raise NotFoundError('Necesidad no encontrada') from exc
        return Response(AdminNeedSerializer(need).data)

    def patch(self, request, id):
        try:
            need = Need.objects.get(pk=id)
        except Need.DoesNotExist as exc:
            raise NotFoundError('Necesidad no encontrada') from exc
        serializer = AdminNeedUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        if data:
            for field, value in data.items():
                setattr(need, field, value)
            need.save(update_fields=[*data.keys(), 'updated_at'])
            log_audit_event(
                actor_user=request.user,
                action='ADMIN_NEED_UPDATE',
                entity='Need',
                entity_id=need.id,
                metadata={'fields': list(data.keys())},
            )
        return Response(AdminNeedSerializer(need).data)


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

    def post(self, request):
        serializer = AdminInventoryCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = dict(serializer.validated_data)
        seller = get_user_by_id(data.pop('seller_id'))
        loc = data.pop('location', None)
        brand = data.pop('brand', '') or 'Genérico'
        model = data.pop('model', '') or 'N/A'
        year = data.pop('year', 2020)
        mileage_km = data.pop('mileage_km', 0)
        vehicle_category = data.pop('vehicle_category', 'CAR')
        property_type = data.pop('property_type', 'APTO')
        if data['asset_type'] == AssetType.VEHICLE:
            detail = {
                'brand': brand,
                'model': model,
                'year': year,
                'mileage_km': mileage_km,
                'vehicle_category': vehicle_category,
            }
        else:
            detail = {'property_type': property_type}
        item = inventory_service.create_inventory_item(
            seller,
            {
                **data,
                'location': _point_from_location(loc),
                'detail': detail,
            },
            bypass_verification=True,
        )
        log_audit_event(
            actor_user=request.user,
            action='ADMIN_INVENTORY_CREATE',
            entity='InventoryItem',
            entity_id=item.id,
            metadata={'seller_id': str(seller.id)},
        )
        return Response(AdminInventorySerializer(item).data, status=status.HTTP_201_CREATED)


class AdminInventoryDetailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request, id):
        try:
            item = InventoryItem.objects.select_related('seller').get(pk=id)
        except InventoryItem.DoesNotExist as exc:
            raise NotFoundError('Inventario no encontrado') from exc
        return Response(AdminInventorySerializer(item).data)

    def patch(self, request, id):
        try:
            item = InventoryItem.objects.get(pk=id)
        except InventoryItem.DoesNotExist as exc:
            raise NotFoundError('Inventario no encontrado') from exc
        serializer = AdminInventoryUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        if data:
            for field, value in data.items():
                setattr(item, field, value)
            item.save(update_fields=[*data.keys(), 'updated_at'])
            log_audit_event(
                actor_user=request.user,
                action='ADMIN_INVENTORY_UPDATE',
                entity='InventoryItem',
                entity_id=item.id,
                metadata={'fields': list(data.keys())},
            )
        return Response(AdminInventorySerializer(item).data)


class AdminInventoryFlagView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            item = InventoryItem.objects.get(pk=id)
        except InventoryItem.DoesNotExist as exc:
            raise NotFoundError('Inventario no encontrado') from exc
        serializer = FlagInventorySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        log_audit_event(
            actor_user=request.user,
            action='INVENTORY_FLAGGED',
            entity='InventoryItem',
            entity_id=item.id,
            metadata={'reason': serializer.validated_data.get('reason', '')},
        )
        return Response(AdminInventorySerializer(item).data)


class AdminInventoryDeactivateView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            item = InventoryItem.objects.get(pk=id)
        except InventoryItem.DoesNotExist as exc:
            raise NotFoundError('Inventario no encontrado') from exc
        serializer = FlagInventorySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = inventory_service.admin_deactivate_item(
            item,
            request.user,
            reason=serializer.validated_data.get('reason', ''),
        )
        return Response(AdminInventorySerializer(item).data)


class AdminInventoryReactivateView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            item = InventoryItem.objects.get(pk=id)
        except InventoryItem.DoesNotExist as exc:
            raise NotFoundError('Inventario no encontrado') from exc
        item = inventory_service.admin_reactivate_item(item, request.user)
        return Response(AdminInventorySerializer(item).data)


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


class AdminTopupFailView(APIView):
    permission_classes = [IsAdminOrModerator]

    def post(self, request, id):
        try:
            order = TopupOrder.objects.select_related('user', 'package').get(pk=id)
        except TopupOrder.DoesNotExist as exc:
            raise NotFoundError('Orden no encontrada') from exc
        order = packages_service.fail_topup_order(
            order, provider_payload={'source': 'admin', 'by': str(request.user.id)}
        )
        return Response(AdminTopupSerializer(order).data)


class AdminTopupCompleteView(APIView):
    permission_classes = [IsAdmin]

    def post(self, request, id):
        try:
            order = TopupOrder.objects.select_related('user', 'package').get(pk=id)
        except TopupOrder.DoesNotExist as exc:
            raise NotFoundError('Orden no encontrada') from exc
        order = packages_service.complete_topup_order(
            order,
            provider_reference=f'admin-{request.user.id}',
            provider_payload={'source': 'admin_manual'},
        )
        return Response(AdminTopupSerializer(order).data)


class AdminPackageListCreateView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = packages_service.list_packages(include_inactive=True)
        return Response(AdminPackageSerializer(qs, many=True).data)

    def post(self, request):
        if request.user.role != 'ADMIN':
            from apps.common.exceptions import PermissionError

            raise PermissionError('Solo ADMIN puede crear paquetes')
        serializer = AdminPackageWriteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        package = packages_service.create_package(request.user, serializer.validated_data)
        return Response(
            AdminPackageSerializer(package).data, status=status.HTTP_201_CREATED
        )


class AdminPackageDetailView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, id):
        try:
            package = TopupPackage.objects.get(pk=id)
        except TopupPackage.DoesNotExist as exc:
            raise NotFoundError('Paquete no encontrado') from exc
        serializer = AdminPackageUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        package = packages_service.update_package(
            package, request.user, serializer.validated_data
        )
        return Response(AdminPackageSerializer(package).data)

    def delete(self, request, id):
        try:
            package = TopupPackage.objects.get(pk=id)
        except TopupPackage.DoesNotExist as exc:
            raise NotFoundError('Paquete no encontrado') from exc
        package = packages_service.deactivate_package(package, request.user)
        return Response(AdminPackageSerializer(package).data)


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


class AdminWalletTransactionsView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request, user_id):
        user = get_user_by_id(user_id)
        wallet = get_or_create_wallet(user)
        qs = WalletTransaction.objects.filter(wallet=wallet).order_by('-created_at')
        return _paginate(request, self, qs, AdminWalletTransactionSerializer)


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


class AdminReviewTagListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = ReviewTag.objects.all().order_by('for_role', 'order')
        return Response(AdminReviewTagSerializer(qs, many=True).data)

    def post(self, request):
        if request.user.role != 'ADMIN':
            from apps.common.exceptions import PermissionError

            raise PermissionError()
        serializer = AdminReviewTagSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        tag = ReviewTag.objects.create(**serializer.validated_data)
        return Response(AdminReviewTagSerializer(tag).data, status=status.HTTP_201_CREATED)


class AdminReviewTagDetailView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, id):
        try:
            tag = ReviewTag.objects.get(pk=id)
        except ReviewTag.DoesNotExist as exc:
            raise NotFoundError('Tag no encontrado') from exc
        serializer = AdminReviewTagSerializer(tag, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        for k, v in serializer.validated_data.items():
            setattr(tag, k, v)
        tag.save()
        return Response(AdminReviewTagSerializer(tag).data)


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

    def post(self, request):
        if request.user.role != 'ADMIN':
            from apps.common.exceptions import PermissionError

            raise PermissionError()
        serializer = SystemSettingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        setting, _ = SystemSetting.objects.update_or_create(
            key=data['key'],
            defaults={
                'value': data['value'],
                'value_type': data.get('value_type', 'string'),
                'description': data.get('description', ''),
                'updated_by': request.user,
            },
        )
        invalidate_setting_cache(setting.key)
        return Response(
            SystemSettingSerializer(setting).data, status=status.HTTP_201_CREATED
        )


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


class AdminAuditLogListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = AuditLog.objects.select_related('actor_user').order_by('-created_at')
        action = request.query_params.get('action')
        entity = request.query_params.get('entity')
        search = request.query_params.get('search')
        if action:
            qs = qs.filter(action__icontains=action)
        if entity:
            qs = qs.filter(entity__icontains=entity)
        if search:
            qs = qs.filter(actor_user__email__icontains=search)
        return _paginate(request, self, qs, AdminAuditLogSerializer)


class AdminNotificationListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = Notification.objects.select_related('recipient').order_by('-created_at')
        delivery_status = request.query_params.get('delivery_status')
        template_code = request.query_params.get('template_code')
        channel = request.query_params.get('channel')
        if delivery_status:
            qs = qs.filter(delivery_status=delivery_status)
        if template_code:
            qs = qs.filter(template_code__icontains=template_code)
        if channel:
            qs = qs.filter(channel=channel)
        return _paginate(request, self, qs, AdminNotificationSerializer)

    def post(self, request):
        serializer = AdminNotificationCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        recipient = get_user_by_id(data['recipient_id'])
        notif = Notification.objects.create(
            recipient=recipient,
            channel=NotificationChannel.PUSH,
            template_code=data.get('template_code') or 'ADMIN_MANUAL',
            title=data['title'],
            body=data['body'],
            payload={'source': 'admin_panel'},
            delivery_status=Notification.DeliveryStatus.SENT,
            sent_at=timezone.now(),
        )
        log_audit_event(
            actor_user=request.user,
            action='ADMIN_NOTIFICATION_CREATE',
            entity='Notification',
            entity_id=notif.id,
            metadata={'recipient_id': str(recipient.id)},
        )
        return Response(
            AdminNotificationSerializer(notif).data,
            status=status.HTTP_201_CREATED,
        )


class AdminMatchListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = Match.objects.select_related('buyer', 'seller', 'need', 'inventory_item').order_by(
            '-created_at'
        )
        match_status = request.query_params.get('status')
        if match_status:
            qs = qs.filter(status=match_status)
        min_score = request.query_params.get('min_score')
        if min_score:
            qs = qs.filter(score__gte=int(min_score))
        return _paginate(request, self, qs, AdminMatchSerializer)


class AdminContactUnlockListView(APIView):
    permission_classes = [IsAdminOrModerator]

    def get(self, request):
        qs = ContactUnlock.objects.select_related('buyer', 'seller', 'match').order_by(
            '-created_at'
        )
        outcome = request.query_params.get('outcome')
        if outcome:
            qs = qs.filter(outcome=outcome)
        return _paginate(request, self, qs, AdminContactUnlockSerializer)
