from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.constants import ReviewStatus
from apps.common.models import BaseModel


class Review(BaseModel):
    contact_unlock = models.ForeignKey(
        'contacts.ContactUnlock',
        on_delete=models.PROTECT,
        related_name='reviews',
        verbose_name='Desbloqueo de contacto',
    )
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='reviews_given',
        verbose_name='Autor de la reseña',
    )
    reviewee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='reviews_received',
        verbose_name='Usuario reseñado',
    )
    rating = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        verbose_name='Calificación',
    )
    comment = models.TextField(blank=True, verbose_name='Comentario')
    tags = models.JSONField(default=list, blank=True, verbose_name='Etiquetas')
    status = models.CharField(
        max_length=20,
        choices=ReviewStatus.choices,
        default=ReviewStatus.PUBLISHED,
        verbose_name='Estado',
    )

    class Meta:
        db_table = 'reviews'
        verbose_name = 'Reseña'
        verbose_name_plural = 'Reseñas'
        constraints = [
            models.UniqueConstraint(
                fields=['contact_unlock', 'reviewer'],
                name='unique_review_per_reviewer',
            ),
        ]
        indexes = [
            models.Index(fields=['reviewee', 'status']),
            models.Index(fields=['rating']),
        ]

    def __str__(self):
        return f'Review({self.reviewer_id} → {self.reviewee_id}, {self.rating}★)'


class ReviewTag(BaseModel):
    code = models.CharField(max_length=50, unique=True, verbose_name='Código')
    label = models.CharField(max_length=80, verbose_name='Etiqueta')
    for_role = models.CharField(max_length=40, verbose_name='Para rol')
    is_active = models.BooleanField(default=True, verbose_name='Activo')
    order = models.IntegerField(default=0, verbose_name='Orden')

    class Meta:
        db_table = 'review_tags'
        ordering = ['for_role', 'order']
        verbose_name = 'Etiqueta de reseña'
        verbose_name_plural = 'Etiquetas de reseña'

    def __str__(self):
        return f'{self.code}: {self.label}'


class ReviewDispute(BaseModel):
    class Status(models.TextChoices):
        OPEN = 'OPEN', 'Abierta'
        RESOLVED_KEPT = 'RESOLVED_KEPT', 'Resuelta — se mantiene'
        RESOLVED_REMOVED = 'RESOLVED_REMOVED', 'Resuelta — eliminada'

    review = models.OneToOneField(
        Review,
        on_delete=models.PROTECT,
        related_name='dispute',
        verbose_name='Reseña',
    )
    disputed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='review_disputes',
        verbose_name='Disputada por',
    )
    reason = models.TextField(verbose_name='Motivo')
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.OPEN,
        verbose_name='Estado',
    )
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='review_disputes_resolved',
        verbose_name='Resuelta por',
    )
    resolved_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Resuelta el',
    )
    admin_note = models.TextField(blank=True, verbose_name='Nota del administrador')

    class Meta:
        db_table = 'review_disputes'
        verbose_name = 'Disputa de reseña'
        verbose_name_plural = 'Disputas de reseña'

    def __str__(self):
        return f'ReviewDispute({self.review_id}, {self.status})'
