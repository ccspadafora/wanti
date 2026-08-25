from django.conf import settings
from django.db import models

from apps.common.constants import ContactOutcome
from apps.common.models import BaseModel


class ContactUnlock(BaseModel):
    match = models.OneToOneField(
        'matching.Match',
        on_delete=models.PROTECT,
        related_name='unlock',
        verbose_name='Coincidencia',
    )
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='unlocks_as_buyer',
        verbose_name='Comprador',
    )
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='unlocks_as_seller',
        verbose_name='Vendedor',
    )
    wantis_charged = models.IntegerField(default=1, verbose_name='Wanti cobrados')
    wallet_transaction = models.OneToOneField(
        'wallet.WalletTransaction',
        on_delete=models.PROTECT,
        related_name='contact_unlock',
        verbose_name='Transacción de billetera',
    )
    outcome = models.CharField(
        max_length=20,
        choices=ContactOutcome.choices,
        default=ContactOutcome.PENDING,
        verbose_name='Resultado',
    )
    outcome_reported_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Resultado reportado el',
    )
    whatsapp_opened_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='WhatsApp abierto el',
    )

    class Meta:
        db_table = 'contact_unlocks'
        verbose_name = 'Desbloqueo de contacto'
        verbose_name_plural = 'Desbloqueos de contacto'
        indexes = [
            models.Index(fields=['buyer', '-created_at']),
            models.Index(fields=['seller', '-created_at']),
            models.Index(fields=['outcome']),
        ]

    def __str__(self):
        return f'ContactUnlock(match={self.match_id}, outcome={self.outcome})'
