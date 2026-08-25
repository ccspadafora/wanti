from contextlib import contextmanager
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4

from django.test import SimpleTestCase

from apps.common.constants import MatchStatus, UserStatus
from apps.common.exceptions import PermissionError
from apps.contacts.services.contacts import unlock_contact


@contextmanager
def _noop_atomic(*args, **kwargs):
    yield


class UnlockContactIdempotencyTests(SimpleTestCase):
    def _match(self, **kwargs):
        mid = kwargs.pop('id', uuid4())
        buyer = SimpleNamespace(id=uuid4(), full_name='Buyer', phone='300', email='b@x.co')
        seller = SimpleNamespace(id=uuid4(), full_name='Seller', status=UserStatus.ACTIVE)
        item = SimpleNamespace(id=uuid4(), title='Spark GT')
        defaults = {
            'id': mid,
            'pk': mid,
            'seller_id': seller.id,
            'buyer_id': buyer.id,
            'seller': seller,
            'buyer': buyer,
            'inventory_item': item,
            'inventory_item_id': item.id,
            'status': MatchStatus.GENERATED,
        }
        defaults.update(kwargs)
        return SimpleNamespace(**defaults)

    @patch('apps.contacts.services.contacts.transaction.atomic', _noop_atomic)
    @patch('apps.contacts.services.contacts.ContactUnlock')
    @patch('apps.contacts.services.contacts.Match')
    def test_existing_unlock_does_not_charge(self, match_model, unlock_model):
        match = self._match()
        actor = match.seller
        existing = SimpleNamespace(id=uuid4(), wantis_charged=1)
        locked_qs = MagicMock()
        match_model.objects.select_for_update.return_value = locked_qs
        locked_qs.select_related.return_value = locked_qs
        locked_qs.get.return_value = match
        unlock_model.objects.filter.return_value.first.return_value = existing

        with patch('apps.contacts.services.contacts.apply_transaction') as apply_txn:
            unlock, created = unlock_contact(match, actor, idempotency_key='k1')
            apply_txn.assert_not_called()
        assert unlock is existing
        assert created is False

    @patch('apps.contacts.services.contacts.transaction.atomic', _noop_atomic)
    def test_buyer_cannot_unlock(self):
        match = self._match()
        buyer = SimpleNamespace(id=match.buyer_id, status=UserStatus.ACTIVE)
        with self.assertRaises(PermissionError):
            unlock_contact(match, buyer)


class ApplyTransactionIdempotencyTests(SimpleTestCase):
    @patch('apps.wallet.services.wallet.transaction.atomic', _noop_atomic)
    @patch('apps.wallet.services.wallet.log_audit_event')
    @patch('apps.wallet.services.wallet.WalletTransaction')
    @patch('apps.wallet.services.wallet.Wallet')
    def test_same_idempotency_key_returns_existing(self, wallet_model, txn_model, _audit):
        from apps.wallet.services.wallet import apply_transaction

        wallet = SimpleNamespace(pk=uuid4(), balance_wantis=5)
        existing = SimpleNamespace(id=uuid4(), amount_wantis=-1)
        qs = MagicMock()
        txn_model.objects.select_for_update.return_value = qs
        qs.filter.return_value.first.return_value = existing

        result = apply_transaction(
            wallet=wallet,
            transaction_type='UNLOCK',
            amount_wantis=-1,
            idempotency_key='same-key',
        )
        assert result is existing
        txn_model.objects.create.assert_not_called()
        wallet_model.objects.filter.assert_not_called()
