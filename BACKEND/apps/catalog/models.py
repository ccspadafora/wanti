from django.db import models

from apps.common.constants import VehicleCategory
from apps.common.models import BaseModel


class VehicleBrand(BaseModel):
    name = models.CharField(max_length=80, verbose_name='Marca')
    slug = models.SlugField(max_length=100, unique=True)
    category = models.CharField(
        max_length=20,
        choices=VehicleCategory.choices,
        default=VehicleCategory.CAR,
        db_index=True,
        verbose_name='Categoría',
        help_text='Categoría de vehículo asociada a la marca en el catálogo',
    )
    is_popular = models.BooleanField(default=False, verbose_name='Más usada')
    is_active = models.BooleanField(default=True, db_index=True)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = 'catalog_vehicle_brands'
        ordering = ['sort_order', 'name']
        verbose_name = 'Marca'
        verbose_name_plural = 'Marcas'
        constraints = [
            models.UniqueConstraint(
                fields=['name', 'category'],
                name='unique_brand_name_per_category',
            ),
        ]

    def __str__(self):
        return f'{self.name} ({self.category})'


class VehicleModel(BaseModel):
    brand = models.ForeignKey(
        VehicleBrand,
        on_delete=models.CASCADE,
        related_name='models',
        verbose_name='Marca',
    )
    name = models.CharField(max_length=120, verbose_name='Modelo')
    slug = models.SlugField(max_length=140)
    is_popular = models.BooleanField(default=False, verbose_name='Más usado')
    is_active = models.BooleanField(default=True, db_index=True)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = 'catalog_vehicle_models'
        ordering = ['sort_order', 'name']
        unique_together = [('brand', 'slug')]
        verbose_name = 'Modelo'
        verbose_name_plural = 'Modelos'
        indexes = [
            models.Index(fields=['brand', 'is_active']),
        ]

    def __str__(self):
        return f'{self.brand.name} {self.name}'


class VehicleModelYear(BaseModel):
    model = models.ForeignKey(
        VehicleModel,
        on_delete=models.CASCADE,
        related_name='years',
        verbose_name='Modelo',
    )
    year = models.PositiveSmallIntegerField(verbose_name='Año')
    is_popular = models.BooleanField(default=False, verbose_name='Más usado')
    is_active = models.BooleanField(default=True, db_index=True)

    class Meta:
        db_table = 'catalog_vehicle_model_years'
        ordering = ['-year']
        unique_together = [('model', 'year')]
        verbose_name = 'Año de modelo'
        verbose_name_plural = 'Años de modelo'
        indexes = [
            models.Index(fields=['model', 'year']),
        ]

    def __str__(self):
        return f'{self.model} {self.year}'


class VehicleVersion(BaseModel):
    model_year = models.ForeignKey(
        VehicleModelYear,
        on_delete=models.CASCADE,
        related_name='versions',
        verbose_name='Año',
    )
    name = models.CharField(max_length=120, verbose_name='Versión')
    catalog_key = models.CharField(
        max_length=255,
        unique=True,
        verbose_name='Clave de catálogo',
    )
    quality = models.CharField(
        max_length=40,
        blank=True,
        default='catalogo_ampliado',
        verbose_name='Calidad del registro',
    )
    is_active = models.BooleanField(default=True, db_index=True)
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = 'catalog_vehicle_versions'
        ordering = ['sort_order', 'name']
        unique_together = [('model_year', 'name')]
        verbose_name = 'Versión'
        verbose_name_plural = 'Versiones'
        indexes = [
            models.Index(fields=['model_year', 'is_active']),
        ]

    def __str__(self):
        return f'{self.model_year} — {self.name}'

    @property
    def brand_name(self):
        return self.model_year.model.brand.name

    @property
    def model_name(self):
        return self.model_year.model.name

    @property
    def year(self):
        return self.model_year.year


class VehicleVersionSpec(BaseModel):
    """
    Características técnicas conocidas / permitidas para una versión de catálogo.
    Listas vacías = sin restricción conocida (el usuario elige libremente).
    """

    version = models.OneToOneField(
        VehicleVersion,
        on_delete=models.CASCADE,
        related_name='specs',
        verbose_name='Versión',
    )
    fuel_types = models.JSONField(default=list, blank=True, verbose_name='Combustibles permitidos')
    transmissions = models.JSONField(
        default=list, blank=True, verbose_name='Transmisiones permitidas'
    )
    tractions = models.JSONField(default=list, blank=True, verbose_name='Tracciones permitidas')
    body_types = models.JSONField(default=list, blank=True, verbose_name='Carrocerías permitidas')
    engine_cc = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Cilindraje de referencia (cc)',
    )
    source = models.CharField(
        max_length=40,
        default='inferred',
        blank=True,
        verbose_name='Origen',
        help_text='inferred | manual | import',
    )

    class Meta:
        db_table = 'catalog_vehicle_version_specs'
        verbose_name = 'Specs de versión'
        verbose_name_plural = 'Specs de versiones'

    def __str__(self):
        return f'Specs({self.version})'
