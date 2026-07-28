from django.conf import settings
from django.db import models

from apps.common.constants import CriterionMode, MatchStatus
from apps.common.models import BaseModel


class Match(BaseModel):
    need = models.ForeignKey(
        'needs.Need',
        on_delete=models.CASCADE,
        related_name='matches',
        verbose_name='Necesidad',
    )
    inventory_item = models.ForeignKey(
        'inventory.InventoryItem',
        on_delete=models.CASCADE,
        related_name='matches',
        verbose_name='Publicación',
    )
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='matches_as_buyer',
        verbose_name='Comprador',
    )
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='matches_as_seller',
        verbose_name='Vendedor',
    )
    score = models.IntegerField(verbose_name='Puntaje')
    distance_km = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        verbose_name='Distancia (km)',
    )
    required_criteria_met = models.BooleanField(
        default=True,
        verbose_name='Criterios requeridos cumplidos',
    )
    unmet_preferences = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Preferencias no cumplidas',
    )
    status = models.CharField(
        max_length=20,
        choices=MatchStatus.choices,
        default=MatchStatus.GENERATED,
        verbose_name='Estado',
    )
    viewed_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Visto el',
    )
    unlocked_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Desbloqueado el',
    )
    discarded_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Descartado el',
    )

    class Meta:
        db_table = 'matches'
        verbose_name = 'Coincidencia'
        verbose_name_plural = 'Coincidencias'
        constraints = [
            models.UniqueConstraint(
                fields=['need', 'inventory_item'],
                name='unique_match_per_pair',
            ),
        ]
        indexes = [
            models.Index(fields=['buyer', 'status']),
            models.Index(fields=['seller', 'status']),
            models.Index(fields=['need', '-score']),
            models.Index(fields=['score']),
        ]

    def __str__(self):
        return f'Match({self.need_id} ↔ {self.inventory_item_id}, score={self.score})'


class MatchCriterionResult(BaseModel):
    match = models.ForeignKey(
        Match,
        on_delete=models.CASCADE,
        related_name='criteria_results',
        verbose_name='Coincidencia',
    )
    attribute = models.CharField(max_length=80, verbose_name='Atributo')
    mode = models.CharField(
        max_length=20,
        choices=CriterionMode.choices,
        verbose_name='Modo',
    )
    expected_value = models.CharField(max_length=150, verbose_name='Valor esperado')
    actual_value = models.CharField(max_length=150, verbose_name='Valor real')
    met = models.BooleanField(verbose_name='Cumplido')
    contribution = models.IntegerField(verbose_name='Contribución')

    class Meta:
        db_table = 'match_criterion_results'
        verbose_name = 'Detalle del match'
        verbose_name_plural = 'Detalles del match'
        indexes = [
            models.Index(fields=['match', 'met']),
        ]

    def __str__(self):
        return f'{self.attribute} met={self.met} (+{self.contribution})'
