from django.test import SimpleTestCase

from apps.common.integrations.payments.sandbox import (
    normalize_provider_status,
    verify_bolt_webhook_signature,
)


class PaymentProviderHelpersTests(SimpleTestCase):
    def test_normalize_statuses(self):
        assert normalize_provider_status('APPROVED') == 'COMPLETED'
        assert normalize_provider_status('paid') == 'COMPLETED'
        assert normalize_provider_status('REJECTED') == 'FAILED'
        assert normalize_provider_status('CANCELLED') == 'CANCELLED'
        assert normalize_provider_status('canceled') == 'CANCELLED'

    def test_signature_roundtrip(self):
        body = b'{"order_id":"x","status":"APPROVED"}'
        secret = 'test-secret'
        import hashlib
        import hmac

        sig = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
        assert verify_bolt_webhook_signature(body, sig, secret)
        assert verify_bolt_webhook_signature(body, f'sha256={sig}', secret)
        assert not verify_bolt_webhook_signature(body, 'bad', secret)
