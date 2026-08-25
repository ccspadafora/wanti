from django.db import transaction
from django.db.models import F

from apps.audit.services.audit_log import log_audit_event
from apps.common.exceptions import InsufficientFundsError, ValidationError
from apps.wallet.models import Wallet, WalletTransaction


def apply_transaction(
    *,
    wallet: Wallet,
    transaction_type: str,
    amount_wantis: int,
    related_object=None,
    note: str = '',
    created_by=None,
    idempotency_key: str | None = None,
) -> WalletTransaction:
    if amount_wantis == 0:
        raise ValidationError('El monto no puede ser cero')

    with transaction.atomic():
        key = (idempotency_key or '').strip() or None
        if key:
            existing = (
                WalletTransaction.objects.select_for_update()
                .filter(idempotency_key=key)
                .first()
            )
            if existing:
                return existing

        wallet = Wallet.objects.select_for_update().get(pk=wallet.pk)
        new_balance = wallet.balance_wantis + amount_wantis
        if new_balance < 0:
            raise InsufficientFundsError(
                f'Saldo insuficiente: {wallet.balance_wantis} Wanti disponibles'
            )

        related_type = related_object.__class__.__name__ if related_object else ''
        related_id = related_object.pk if related_object else None

        # Segundo candado: un UNLOCK por match (evita doble cobro en carrera)
        if (
            transaction_type == 'UNLOCK'
            and related_type
            and related_id is not None
        ):
            prior = (
                WalletTransaction.objects.select_for_update()
                .filter(
                    transaction_type='UNLOCK',
                    related_object_type=related_type,
                    related_object_id=related_id,
                )
                .first()
            )
            if prior:
                return prior

        txn = WalletTransaction.objects.create(
            wallet=wallet,
            transaction_type=transaction_type,
            amount_wantis=amount_wantis,
            balance_after=new_balance,
            related_object_type=related_type,
            related_object_id=related_id,
            idempotency_key=key,
            note=note,
            created_by=created_by,
        )
        Wallet.objects.filter(pk=wallet.pk).update(
            balance_wantis=F('balance_wantis') + amount_wantis
        )
        log_audit_event(
            actor_user=created_by,
            action='WALLET_TRANSACTION',
            entity='Wallet',
            entity_id=wallet.id,
            metadata={
                'transaction_type': transaction_type,
                'amount': amount_wantis,
                'balance_after': new_balance,
                'related_type': related_type,
                'related_id': str(related_id) if related_id else None,
                'idempotency_key': key,
            },
        )
        return txn


def get_or_create_wallet(user) -> Wallet:
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet
