"""Payment providers (sandbox + Bolt)."""

from __future__ import annotations

import hashlib
import hmac
import logging

import requests
from django.conf import settings

from apps.common.integrations.payments.base import PaymentProvider

logger = logging.getLogger(__name__)


class SandboxPaymentProvider(PaymentProvider):
    def create_checkout(self, order) -> dict:
        base = getattr(settings, 'FRONTEND_BASE_URL', 'http://localhost:3000').rstrip('/')
        return {
            'checkout_url': f'{base}/payments/sandbox/{order.id}',
            'provider_reference': f'sandbox-{order.id}',
        }


class BoltPaymentProvider(PaymentProvider):
    """
    Cliente HTTP genérico para la pasarela Bolt.
    Contrato esperado create:
      POST {BOLT_API_URL}/v1/payments
      Authorization: Bearer {BOLT_API_KEY}
      {
        "external_id": "<order_uuid>",
        "amount_cop": 50000,
        "currency": "COP",
        "description": "Wanti topup",
        "customer_email": "...",
        "callback_url": "https://api.../wallet/topups/webhook/"
      }
      → { "id": "pay_xxx", "checkout_url": "https://..." }
    """

    def create_checkout(self, order) -> dict:
        api_url = (getattr(settings, 'BOLT_API_URL', '') or '').rstrip('/')
        api_key = getattr(settings, 'BOLT_API_KEY', '') or ''
        if not api_url or not api_key:
            raise RuntimeError('Bolt no configurado (BOLT_API_URL / BOLT_API_KEY)')

        callback = getattr(settings, 'PAYMENT_WEBHOOK_URL', '') or ''
        payload = {
            'external_id': str(order.id),
            'amount_cop': int(order.price_cop),
            'currency': 'COP',
            'description': f'Recarga Wanti ({order.wantis_total})',
            'customer_email': order.user.email,
            'callback_url': callback,
            'metadata': {
                'order_id': str(order.id),
                'user_id': str(order.user_id),
                'wantis_total': order.wantis_total,
            },
        }
        res = requests.post(
            f'{api_url}/v1/payments',
            headers={
                'Authorization': f'Bearer {api_key}',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            },
            json=payload,
            timeout=20,
        )
        if res.status_code >= 400:
            logger.error('Bolt create_checkout failed: %s %s', res.status_code, res.text[:500])
            res.raise_for_status()
        data = res.json() if res.content else {}
        return {
            'checkout_url': data.get('checkout_url') or data.get('payment_url') or '',
            'provider_reference': str(data.get('id') or data.get('payment_id') or ''),
            'raw': data,
        }


def verify_bolt_webhook_signature(raw_body: bytes, header_value: str, secret: str) -> bool:
    if not secret or not header_value:
        return False
    provided = header_value
    if provided.startswith('sha256='):
        provided = provided[7:]
    expected = hmac.new(secret.encode('utf-8'), raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, provided)


def normalize_provider_status(raw: str) -> str:
    """Mapea estados del proveedor a TopupStatus internos."""
    value = (raw or '').strip().upper()
    approved = {
        'COMPLETED',
        'APPROVED',
        'APPROVED_PAYMENT',
        'SUCCESS',
        'PAID',
        'CAPTURED',
    }
    failed = {'FAILED', 'REJECTED', 'DECLINED', 'ERROR'}
    cancelled = {'CANCELLED', 'CANCELED', 'VOIDED', 'ABANDONED'}
    if value in approved:
        return 'COMPLETED'
    if value in cancelled:
        return 'CANCELLED'
    if value in failed:
        return 'FAILED'
    return value


def get_payment_provider() -> PaymentProvider:
    name = (getattr(settings, 'PAYMENT_PROVIDER', 'sandbox') or 'sandbox').strip().lower()
    if name == 'bolt':
        return BoltPaymentProvider()
    return SandboxPaymentProvider()
