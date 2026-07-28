from apps.common.exceptions import NotFoundError
from apps.wallet.models import TopupPackage, Wallet, WalletTransaction


def get_wallet(user) -> Wallet:
    try:
        return user.wallet
    except Wallet.DoesNotExist as exc:
        raise NotFoundError('Wallet no encontrada') from exc


def list_transactions(user, *, limit=50):
    wallet = get_wallet(user)
    return WalletTransaction.objects.filter(wallet=wallet).order_by('-created_at')[:limit]


def get_active_packages():
    return TopupPackage.objects.filter(is_active=True).order_by('order')
