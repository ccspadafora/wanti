from django.conf import settings
from django.db import models

from apps.common.constants import DisputeReason, DisputeStatus
from apps.common.models import BaseModel


class Dispute(BaseModel):
    contact_unlock = models.ForeignKey(
        'contacts.ContactUnlock',
        on_delete=models.PROTECT,
        related_name='disputes',
        verbose_name='Desbloqueo de contacto',
    )
    opened_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='disputes_opened',
        verbose_name='Abierta por',
    )
    reason = models.CharField(
        max_length=30,
        choices=DisputeReason.choices,
        verbose_name='Motivo',
    )
    description = models.TextField(blank=True, verbose_name='Descripción')
    status = models.CharField(
        max_length=20,
        choices=DisputeStatus.choices,
        default=DisputeStatus.OPEN,
        verbose_name='Estado',
    )
    auto_review_started_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Revisión automática iniciada el',
    )
    auto_review_deadline = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Fecha límite de revisión automática',
    )
    buyer_confirmed_purchase = models.BooleanField(
        null=True,
        blank=True,
        verbose_name='Comprador confirmó compra',
    )
    escalated_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Escalada el',
    )
    resolved_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Resuelta el',
    )
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='disputes_resolved',
        verbose_name='Resuelta por',
    )
    resolution_note = models.TextField(blank=True, verbose_name='Nota de resolución')
    refund_transaction = models.OneToOneField(
        'wallet.WalletTransaction',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='dispute_refund',
        verbose_name='Transacción de reembolso',
    )
    appeal_deadline = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Fecha límite de apelación',
    )

    class Meta:
        db_table = 'disputes'
        verbose_name = 'Disputa'
        verbose_name_plural = 'Disputas'
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['opened_by', '-created_at']),
            models.Index(fields=['auto_review_deadline']),
        ]

    def __str__(self):
        return f'Dispute({self.id}, {self.status})'


class DisputeAttachment(BaseModel):
    dispute = models.ForeignKey(
        Dispute,
        on_delete=models.CASCADE,
        related_name='attachments',
        verbose_name='Disputa',
    )
    file_url = models.URLField(max_length=500, verbose_name='URL del archivo')
    file_name = models.CharField(max_length=200, verbose_name='Nombre del archivo')
    mime_type = models.CharField(max_length=80, verbose_name='Tipo MIME')
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='dispute_attachments',
        verbose_name='Subido por',
    )

    class Meta:
        db_table = 'dispute_attachments'
        verbose_name = 'Adjunto de disputa'
        verbose_name_plural = 'Adjuntos de disputa'

    def __str__(self):
        return self.file_name


class DisputeEvent(BaseModel):
    dispute = models.ForeignKey(
        Dispute,
        on_delete=models.CASCADE,
        related_name='events',
        verbose_name='Disputa',
    )
    event_type = models.CharField(max_length=50, verbose_name='Tipo de evento')
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='dispute_events',
        verbose_name='Realizado por',
    )
    payload = models.JSONField(default=dict, blank=True, verbose_name='Detalle')

    class Meta:
        db_table = 'dispute_events'
        ordering = ['created_at']
        verbose_name = 'Historividad de la disputa'
        verbose_name_plural = 'Actividad de disputas'

    def __str__(self):
        return f'{self.event_type} @ {self.dispute_id}'
