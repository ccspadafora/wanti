from django.conf import settings
from django.db import models

from apps.common.constants import LeadStage
from apps.common.models import BaseModel


class Lead(BaseModel):
    contact_unlock = models.OneToOneField(
        'contacts.ContactUnlock',
        on_delete=models.PROTECT,
        related_name='lead',
        verbose_name='Desbloqueo de contacto',
    )
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='leads',
        verbose_name='Vendedor',
    )
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='leads_as_buyer',
        verbose_name='Comprador',
    )
    stage = models.CharField(
        max_length=20,
        choices=LeadStage.choices,
        default=LeadStage.NEW,
        verbose_name='Etapa',
    )
    last_activity_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Última actividad el',
    )
    expires_at = models.DateTimeField(verbose_name='Expira el')
    sold_price_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Precio de venta (COP)',
    )

    class Meta:
        db_table = 'leads'
        verbose_name = 'Prospecto'
        verbose_name_plural = 'Prospectos'
        indexes = [
            models.Index(fields=['seller', 'stage']),
            models.Index(fields=['expires_at']),
            models.Index(fields=['seller', '-last_activity_at']),
        ]

    def __str__(self):
        return f'Lead({self.seller_id} ← {self.buyer_id}, {self.stage})'


class LeadNote(BaseModel):
    lead = models.ForeignKey(
        Lead,
        on_delete=models.CASCADE,
        related_name='notes',
        verbose_name='Prospecto',
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='lead_notes',
        verbose_name='Autor',
    )
    text = models.TextField(verbose_name='Texto')
    stage_at_time = models.CharField(
        max_length=20,
        choices=LeadStage.choices,
        verbose_name='Etapa al momento',
    )

    class Meta:
        db_table = 'lead_notes'
        ordering = ['-created_at']
        verbose_name = 'Nota de prospecto'
        verbose_name_plural = 'Notas de prospecto'

    def __str__(self):
        return f'LeadNote({self.lead_id}, {self.stage_at_time})'
