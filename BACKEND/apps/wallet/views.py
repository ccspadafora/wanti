import hashlib
import hmac
import os
from decimal import Decimal

from django.conf import settings
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.constants import TopupStatus
from apps.common.exceptions import NotFoundError, PermissionError, ValidationError
from apps.common.integrations.payments.sandbox import (
    get_payment_provider,
    normalize_provider_status,
    verify_bolt_webhook_signature,
)
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
    cancel_topup_order,
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
        try:
            checkout = get_payment_provider().create_checkout(order)
        except Exception as exc:
            fail_topup_order(order, provider_payload={'error': str(exc)})
            raise ValidationError(f'No se pudo iniciar el pago: {exc}') from exc

        if checkout.get('provider_reference'):
            order.provider_reference = checkout['provider_reference']
            order.provider_payload = {
                **(order.provider_payload or {}),
                'checkout': {k: v for k, v in checkout.items() if k != 'raw'},
            }
            order.save(update_fields=['provider_reference', 'provider_payload', 'updated_at'])

        # Solo acreditar sin webhook si está explícitamente habilitado (demo).
        auto = getattr(settings, 'PAYMENT_AUTO_COMPLETE', False)
        if auto:
            order = complete_topup_order(
                order,
                provider_reference=order.provider_reference or 'auto-complete',
                provider_payload={'auto_completed': True, 'source': 'PAYMENT_AUTO_COMPLETE'},
            )

        data = TopupOrderSerializer(order).data
        data['checkout_url'] = checkout.get('checkout_url')
        return Response(data, status=status.HTTP_201_CREATED)


class TopupWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        self._verify_signature(request)
        serializer = TopupWebhookSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        order = self._resolve_order(data)
        normalized = normalize_provider_status(data['status'])
        payload = data.get('provider_payload') or {}
        ref = data.get('provider_reference') or order.provider_reference or ''

        if normalized == TopupStatus.COMPLETED:
            complete_topup_order(
                order,
                provider_reference=ref,
                provider_payload=payload,
            )
        elif normalized == TopupStatus.CANCELLED:
            cancel_topup_order(order, provider_payload=payload)
        else:
            fail_topup_order(order, provider_payload=payload)
        return Response({'received': True, 'order_id': str(order.id), 'status': normalized})

    @staticmethod
    def _resolve_order(data) -> TopupOrder:
        order_id = data.get('order_id')
        if order_id:
            try:
                return TopupOrder.objects.get(pk=order_id)
            except TopupOrder.DoesNotExist as exc:
                raise NotFoundError('Orden no encontrada') from exc
        ref = (data.get('provider_reference') or '').strip()
        if ref:
            order = TopupOrder.objects.filter(provider_reference=ref).first()
            if order:
                return order
        raise NotFoundError('Orden no encontrada')

    @staticmethod
    def _verify_signature(request):
        secret = getattr(settings, 'PAYMENT_WEBHOOK_SECRET', '') or os.getenv(
            'PAYMENT_WEBHOOK_SECRET', ''
        )
        if not secret:
            raise PermissionError('Webhook no configurado')
        header = (
            request.headers.get('X-Wanti-Signature')
            or request.headers.get('X-Bolt-Signature')
            or ''
        )
        provider = (getattr(settings, 'PAYMENT_PROVIDER', 'sandbox') or '').lower()
        if provider == 'bolt':
            ok = verify_bolt_webhook_signature(request.body, header, secret)
        else:
            provided = header.removeprefix('sha256=') if header.startswith('sha256=') else header
            expected = hmac.new(
                secret.encode('utf-8'),
                request.body,
                hashlib.sha256,
            ).hexdigest()
            ok = bool(provided) and hmac.compare_digest(expected, provided)
        if not ok:
            raise PermissionError('Firma de webhook inválida')


class WalletTransactionListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        get_or_create_wallet(request.user)
        txns = list_transactions(request.user)
        return Response(
            WalletTransactionSerializer(txns, many=True, context={'request': request}).data
        )
