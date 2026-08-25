from django.conf import settings
from django.db import models

from apps.common.constants import TopupStatus, TransactionType
from apps.common.models import BaseModel


class Wallet(BaseModel):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='wallet',
        verbose_name='Usuario',
    )
    balance_wantis = models.IntegerField(default=0, verbose_name='Saldo en Wanti')

    class Meta:
        db_table = 'wallets'
        verbose_name = 'Billetera'
        verbose_name_plural = 'Billeteras'

    def __str__(self):
        return f'Wallet({self.user_id}, balance={self.balance_wantis})'


class WalletTransaction(BaseModel):
    wallet = models.ForeignKey(
        Wallet,
        on_delete=models.PROTECT,
        related_name='transactions',
        verbose_name='Billetera',
    )
    transaction_type = models.CharField(
        max_length=20,
        choices=TransactionType.choices,
        verbose_name='Tipo de transacción',
    )
    amount_wantis = models.IntegerField(verbose_name='Monto en Wanti')
    balance_after = models.IntegerField(verbose_name='Saldo posterior')
    related_object_type = models.CharField(
        max_length=50,
        blank=True,
        verbose_name='Tipo de objeto relacionado',
    )
    related_object_id = models.UUIDField(
        null=True,
        blank=True,
        verbose_name='ID de objeto relacionado',
    )
    idempotency_key = models.CharField(
        max_length=64,
        null=True,
        blank=True,
        unique=True,
        verbose_name='Clave de idempotencia',
    )
    note = models.TextField(blank=True, verbose_name='Nota')
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='wallet_transactions_created',
        verbose_name='Creado por',
    )

    class Meta:
        db_table = 'wallet_transactions'
        verbose_name = 'Transacción de billetera'
        verbose_name_plural = 'Transacciones de billetera'
        indexes = [
            models.Index(fields=['wallet', '-created_at']),
            models.Index(fields=['transaction_type']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['transaction_type', 'related_object_type', 'related_object_id'],
                condition=models.Q(
                    transaction_type='UNLOCK',
                    related_object_id__isnull=False,
                ),
                name='uniq_unlock_charge_per_related_object',
            ),
        ]

    def __str__(self):
        return f'{self.transaction_type} {self.amount_wantis} → {self.balance_after}'


class TopupPackage(BaseModel):
    name = models.CharField(max_length=80, verbose_name='Nombre')
    wantis_base = models.IntegerField(verbose_name='Wanti base')
    wantis_bonus = models.IntegerField(default=0, verbose_name='Wanti de bonificación')
    price_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        verbose_name='Precio (COP)',
    )
    is_popular = models.BooleanField(default=False, verbose_name='Es popular')
    is_active = models.BooleanField(default=True, verbose_name='Activo')
    order = models.IntegerField(default=0, verbose_name='Orden')

    class Meta:
        db_table = 'topup_packages'
        ordering = ['order']
        verbose_name = 'Paquete de recarga'
        verbose_name_plural = 'Paquetes de recarga'

    def __str__(self):
        return f'{self.name} ({self.wantis_base}+{self.wantis_bonus})'

    @property
    def wantis_total(self):
        return self.wantis_base + self.wantis_bonus


class TopupOrder(BaseModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='topup_orders',
        verbose_name='Usuario',
    )
    package = models.ForeignKey(
        TopupPackage,
        on_delete=models.PROTECT,
        related_name='orders',
        verbose_name='Paquete',
    )
    wantis_total = models.IntegerField(verbose_name='Total de Wanti')
    price_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        verbose_name='Precio (COP)',
    )
    status = models.CharField(
        max_length=20,
        choices=TopupStatus.choices,
        default=TopupStatus.PENDING,
        verbose_name='Estado',
    )
    provider_reference = models.CharField(
        max_length=120,
        blank=True,
        db_index=True,
        verbose_name='Referencia del proveedor',
    )
    provider_payload = models.JSONField(
        default=dict,
        blank=True,
        verbose_name='Respuesta del proveedor de pagos',
    )
    completed_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Completado el',
    )

    class Meta:
        db_table = 'topup_orders'
        verbose_name = 'Orden de recarga'
        verbose_name_plural = 'Órdenes de recarga'
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['status', 'created_at']),
            models.Index(fields=['provider_reference']),
        ]

    def __str__(self):
        return f'TopupOrder({self.user_id}, {self.status}, {self.wantis_total})'
