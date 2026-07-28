from django.conf import settings
from django.db import models

from apps.common.constants import OtpChannel
from apps.common.models import BaseModel


class EmailVerificationToken(BaseModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='email_verification_tokens',
        verbose_name='Usuario',
    )
    token = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        verbose_name='Código de verificación',
    )
    expires_at = models.DateTimeField(verbose_name='Expira el')
    used_at = models.DateTimeField(null=True, blank=True, verbose_name='Usado el')
    context = models.JSONField(default=dict, blank=True, verbose_name='Contexto')

    class Meta:
        db_table = 'email_verification_tokens'
        verbose_name = 'Verificación de correo'
        verbose_name_plural = 'Verificaciones de correo'
        indexes = [
            models.Index(fields=['token']),
            models.Index(fields=['user', 'used_at']),
        ]

    def __str__(self):
        return f'EmailVerificationToken(user={self.user_id})'


class PhoneOtp(BaseModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='phone_otps',
        verbose_name='Usuario',
    )
    code_hash = models.CharField(max_length=128, verbose_name='Código (hash)')
    channel = models.CharField(
        max_length=20,
        choices=OtpChannel.choices,
        verbose_name='Canal (WhatsApp / SMS)',
    )
    expires_at = models.DateTimeField(verbose_name='Expira el')
    attempts = models.IntegerField(default=0, verbose_name='Intentos')
    verified_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Verificado el',
    )
    context = models.JSONField(default=dict, blank=True, verbose_name='Contexto')

    class Meta:
        db_table = 'phone_otps'
        verbose_name = 'Código de verificación (celular)'
        verbose_name_plural = 'Códigos de verificación (celular)'
        indexes = [
            models.Index(fields=['user', 'verified_at']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f'PhoneOtp(user={self.user_id}, channel={self.channel})'


class PasswordResetToken(BaseModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='password_reset_tokens',
        verbose_name='Usuario',
    )
    token = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        verbose_name='Código de restablecimiento',
    )
    expires_at = models.DateTimeField(verbose_name='Expira el')
    used_at = models.DateTimeField(null=True, blank=True, verbose_name='Usado el')
    requested_ip = models.GenericIPAddressField(
        null=True,
        blank=True,
        verbose_name='IP de la solicitud',
    )

    class Meta:
        db_table = 'password_reset_tokens'
        verbose_name = 'Restablecimiento de contraseña'
        verbose_name_plural = 'Restablecimientos de contraseña'
        indexes = [
            models.Index(fields=['token']),
            models.Index(fields=['user', 'used_at']),
        ]

    def __str__(self):
        return f'PasswordResetToken(user={self.user_id})'
