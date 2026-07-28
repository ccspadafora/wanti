import hashlib
import hmac
import os
from decimal import Decimal

from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.constants import TopupStatus
from apps.common.exceptions import NotFoundError, PermissionError
from apps.common.integrations.payments.sandbox import get_payment_provider
from apps.common.services.settings_service import get_setting
from apps.wallet.models import TopupOrder
from apps.wallet.selectors.wallet import get_active_packages, list_transactions
from apps.wallet.serializers import (
    TopupCreateSerializer,
    TopupOrderSerializer,
    TopupPackageSerializer,
    TopupWebhookSerializer,
    WalletBalanceSerializer,
    WalletTransactionSerializer,
)
from apps.wallet.services.packages import (
    complete_topup_order,
    create_topup_order,
    fail_topup_order,
)
from apps.wallet.services.wallet import get_or_create_wallet


class WalletBalanceView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        price = int(get_setting('WANTI_PRICE_COP', 5000))
        payload = {
            'balance_wantis': wallet.balance_wantis,
            'wanti_price_cop': price,
            'balance_equivalent_cop': Decimal(wallet.balance_wantis) * Decimal(price),
        }
        return Response(WalletBalanceSerializer(payload).data)


class TopupPackageListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        packages = get_active_packages()
        return Response(TopupPackageSerializer(packages, many=True).data)


class TopupCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = TopupCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order = create_topup_order(request.user, serializer.validated_data['package_id'])
        checkout = get_payment_provider().create_checkout(order)
        data = TopupOrderSerializer(order).data
        data['checkout_url'] = checkout.get('checkout_url')
        if checkout.get('provider_reference'):
            order.provider_reference = checkout['provider_reference']
            order.save(update_fields=['provider_reference', 'updated_at'])
        return Response(data, status=status.HTTP_201_CREATED)


class TopupWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        self._verify_signature(request)
        serializer = TopupWebhookSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            order = TopupOrder.objects.get(pk=data['order_id'])
        except TopupOrder.DoesNotExist as exc:
            raise NotFoundError('Orden no encontrada') from exc

        if data['status'] == TopupStatus.COMPLETED:
            complete_topup_order(
                order,
                provider_reference=data.get('provider_reference') or '',
                provider_payload=data.get('provider_payload') or {},
            )
        else:
            fail_topup_order(order, provider_payload=data.get('provider_payload'))
        return Response({'received': True})

    @staticmethod
    def _verify_signature(request):
        secret = os.getenv('PAYMENT_WEBHOOK_SECRET', '')
        if not secret:
            raise PermissionError('Webhook no configurado')
        header = request.headers.get('X-Wanti-Signature', '')
        provided = header.removeprefix('sha256=') if header.startswith('sha256=') else header
        expected = hmac.new(
            secret.encode('utf-8'),
            request.body,
            hashlib.sha256,
        ).hexdigest()
        if not provided or not hmac.compare_digest(expected, provided):
            raise PermissionError('Firma de webhook inválida')


class WalletTransactionListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        get_or_create_wallet(request.user)
        txns = list_transactions(request.user)
        return Response(WalletTransactionSerializer(txns, many=True).data)
