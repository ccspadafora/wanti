from django.db import models

from apps.common.models import BaseModel


class GeoDepartment(BaseModel):
    name = models.CharField(max_length=100, unique=True, verbose_name='Departamento')
    code = models.CharField(max_length=10, blank=True, verbose_name='Código DANE')
    is_active = models.BooleanField(default=True, verbose_name='Activo')

    class Meta:
        db_table = 'geo_departments'
        ordering = ['name']
        verbose_name = 'Departamento'
        verbose_name_plural = 'Departamentos'

    def __str__(self):
        return self.name


class GeoCity(BaseModel):
    department = models.ForeignKey(
        GeoDepartment,
        on_delete=models.CASCADE,
        related_name='cities',
        verbose_name='Departamento',
    )
    name = models.CharField(max_length=120, verbose_name='Ciudad / municipio')
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Latitud',
    )
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        verbose_name='Longitud',
    )
    is_active = models.BooleanField(default=True, verbose_name='Activo')
    is_capital = models.BooleanField(default=False, verbose_name='Capital de departamento')

    class Meta:
        db_table = 'geo_cities'
        ordering = ['name']
        verbose_name = 'Ciudad / municipio'
        verbose_name_plural = 'Ciudades / municipios'
        constraints = [
            models.UniqueConstraint(
                fields=['department', 'name'],
                name='unique_city_per_department',
            ),
        ]
        indexes = [
            models.Index(fields=['department', 'is_active']),
            models.Index(fields=['name']),
        ]

    def __str__(self):
        return f'{self.name} ({self.department.name})'
