from celery import shared_task
from django.core.mail import mail_admins
from django.db.models import Sum

from apps.audit.services.audit_log import log_audit_event
from apps.wallet.models import Wallet, WalletTransaction


@shared_task(name='apps.wallet.tasks.reconcile_balances')
def reconcile_balances():
    breaches = 0
    for wallet in Wallet.objects.all().iterator():
        total = (
            WalletTransaction.objects.filter(wallet=wallet).aggregate(
                s=Sum('amount_wantis')
            )['s']
            or 0
        )
        if total != wallet.balance_wantis:
            breaches += 1
            log_audit_event(
                actor_user=None,
                action='WALLET_INTEGRITY_BREACH',
                entity='Wallet',
                entity_id=wallet.id,
                metadata={
                    'ledger_sum': total,
                    'balance_wantis': wallet.balance_wantis,
                },
            )
            mail_admins(
                subject='Wanti WALLET_INTEGRITY_BREACH',
                message=f'Wallet {wallet.id}: ledger={total} balance={wallet.balance_wantis}',
                fail_silently=True,
            )
    return {'breaches': breaches}
