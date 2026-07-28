from django.conf import settings
from django.db import models

from apps.common.constants import NotificationChannel
from apps.common.models import BaseModel


class Notification(BaseModel):
    class DeliveryStatus(models.TextChoices):
        PENDING = 'PENDING', 'Pendiente'
        SENT = 'SENT', 'Enviada'
        DELIVERED = 'DELIVERED', 'Entregada'
        FAILED = 'FAILED', 'Fallida'

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
        verbose_name='Destinatario',
    )
    channel = models.CharField(
        max_length=20,
        choices=NotificationChannel.choices,
        verbose_name='Canal',
    )
    template_code = models.CharField(max_length=80, verbose_name='Código de plantilla')
    title = models.CharField(max_length=150, blank=True, verbose_name='Título')
    body = models.TextField(verbose_name='Cuerpo')
    payload = models.JSONField(default=dict, blank=True, verbose_name='Datos adicionales')
    sent_at = models.DateTimeField(null=True, blank=True, verbose_name='Enviada el')
    read_at = models.DateTimeField(null=True, blank=True, verbose_name='Leída el')
    delivery_status = models.CharField(
        max_length=20,
        choices=DeliveryStatus.choices,
        default=DeliveryStatus.PENDING,
        verbose_name='Estado de entrega',
    )
    provider_reference = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='Referencia del proveedor',
    )
    error_message = models.TextField(blank=True, verbose_name='Mensaje de error')

    class Meta:
        db_table = 'notifications'
        verbose_name = 'Notificación'
        verbose_name_plural = 'Notificaciones'
        indexes = [
            models.Index(fields=['recipient', '-created_at']),
            models.Index(fields=['channel', 'delivery_status']),
            models.Index(fields=['template_code']),
        ]

    def __str__(self):
        return f'{self.template_code} → {self.recipient_id} ({self.delivery_status})'


class DeviceToken(BaseModel):
    class Platform(models.TextChoices):
        IOS = 'IOS', 'iOS'
        ANDROID = 'ANDROID', 'Android'
        WEB = 'WEB', 'Web'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='device_tokens',
        verbose_name='Usuario',
    )
    token = models.CharField(max_length=500, unique=True, verbose_name='Identificador del dispositivo')
    platform = models.CharField(
        max_length=10,
        choices=Platform.choices,
        verbose_name='Plataforma',
    )
    device_id = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='ID del dispositivo',
    )
    is_active = models.BooleanField(default=True, verbose_name='Activo')
    last_used_at = models.DateTimeField(auto_now=True, verbose_name='Último uso el')

    class Meta:
        db_table = 'device_tokens'
        verbose_name = 'Dispositivo para notificaciones'
        verbose_name_plural = 'Dispositivos para notificaciones'
        indexes = [
            models.Index(fields=['user', 'is_active']),
        ]

    def __str__(self):
        return f'{self.platform} token ({self.user_id})'
