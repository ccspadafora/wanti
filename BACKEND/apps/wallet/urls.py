from django.urls import path

from apps.wallet.views import (
    TopupCreateView,
    TopupPackageListView,
    TopupWebhookView,
    WalletBalanceView,
    WalletTransactionListView,
)

urlpatterns = [
    path('', WalletBalanceView.as_view(), name='wallet-balance'),
    path('packages/', TopupPackageListView.as_view(), name='wallet-packages'),
    path('topups/', TopupCreateView.as_view(), name='wallet-topups-create'),
    path('topups/webhook/', TopupWebhookView.as_view(), name='wallet-topups-webhook'),
    path('transactions/', WalletTransactionListView.as_view(), name='wallet-transactions'),
]
