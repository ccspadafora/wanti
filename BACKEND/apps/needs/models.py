from django.conf import settings
from django.contrib.gis.db import models

from apps.common.constants import (
    AssetType,
    CriterionMode,
    NeedStatus,
    PaymentType,
    VehicleCategory,
)
from apps.common.models import BaseModel


class Need(BaseModel):
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='needs',
        verbose_name='Comprador',
    )
    asset_type = models.CharField(
        max_length=20,
        choices=AssetType.choices,
        verbose_name='Tipo de activo',
    )
    title = models.CharField(max_length=150, verbose_name='Título')
    description = models.TextField(blank=True, verbose_name='Descripción')
    budget_max_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        verbose_name='Presupuesto máximo (COP)',
    )
    payment_type = models.CharField(
        max_length=20,
        choices=PaymentType.choices,
        verbose_name='Tipo de pago principal',
    )
    payment_types = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Tipos de pago aceptados',
    )
    trade_in_description = models.TextField(
        blank=True,
        verbose_name='Descripción de la permuta',
    )
    trade_in_item = models.ForeignKey(
        'inventory.InventoryItem',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='needs_as_trade_in',
        verbose_name='Inventario ofrecido en permuta',
    )
    city = models.CharField(max_length=100, verbose_name='Ciudad')
    department = models.CharField(
        max_length=100,
        blank=True,
        default='',
        verbose_name='Departamento',
    )
    geo_city = models.ForeignKey(
        'geo.GeoCity',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='needs',
        verbose_name='Ciudad (catálogo)',
    )
    willing_to_travel = models.BooleanField(
        default=False,
        verbose_name='Dispuesto a desplazarse a otras ciudades',
    )
    travel_cities = models.ManyToManyField(
        'geo.GeoCity',
        blank=True,
        related_name='needs_as_travel',
        verbose_name='Ciudades de desplazamiento',
    )
    location = models.PointField(
        srid=4326,
        geography=True,
        verbose_name='Ubicación',
    )
    status = models.CharField(
        max_length=20,
        choices=NeedStatus.choices,
        default=NeedStatus.DRAFT,
        verbose_name='Estado',
    )
    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Expira el',
    )
    renewal_reminder_sent_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Recordatorio de renovación enviado el',
    )
    matches_count = models.IntegerField(
        default=0,
        verbose_name='Cantidad de coincidencias',
    )
    views_count = models.IntegerField(default=0, verbose_name='Cantidad de vistas')
    legal_disclaimer_accepted_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Aviso legal aceptado el',
    )

    class Meta:
        db_table = 'needs'
        verbose_name = 'Necesidad'
        verbose_name_plural = 'Necesidades'
        indexes = [
            models.Index(fields=['buyer', 'status']),
            models.Index(fields=['asset_type', 'status']),
            models.Index(fields=['expires_at']),
            models.Index(fields=['city']),
        ]

    def __str__(self):
        return f'{self.title} ({self.status})'


class VehicleNeed(models.Model):
    need = models.OneToOneField(
        Need,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='vehicle',
        verbose_name='Necesidad',
    )
    vehicle_category = models.CharField(
        max_length=20,
        choices=VehicleCategory.choices,
        default=VehicleCategory.CAR,
        verbose_name='Categoría de vehículo',
    )
    brand = models.CharField(max_length=80, verbose_name='Marca')
    model = models.CharField(max_length=80, verbose_name='Modelo')
    line = models.CharField(max_length=120, blank=True, verbose_name='Línea / versión')
    year_min = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Año mínimo',
    )
    year_max = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Año máximo',
    )
    color = models.CharField(max_length=40, blank=True, verbose_name='Color')
    engine_cc = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Cilindraje (cc)',
    )
    fuel_type = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Tipo de combustible',
    )
    body_type = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Tipo de carrocería',
    )
    mileage_max_km = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Kilometraje máximo (km)',
    )
    traction = models.CharField(max_length=20, blank=True, verbose_name='Tracción')
    transmission = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Transmisión',
    )
    steering = models.CharField(
        max_length=30,
        blank=True,
        verbose_name='Dirección',
    )
    doors = models.IntegerField(null=True, blank=True, verbose_name='Puertas')
    single_owner = models.BooleanField(
        null=True,
        blank=True,
        verbose_name='Único dueño',
    )
    owners_max = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Dueños máximos aceptados',
    )
    plate_last_digit = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Último dígito de placa',
    )
    insurance_reports = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Reportes de aseguradora aceptados',
    )
    accessories = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Accesorios',
    )

    class Meta:
        db_table = 'need_vehicles'
        verbose_name = 'Necesidad de vehículo'
        verbose_name_plural = 'Necesidades de vehículo'

    def __str__(self):
        return f'{self.brand} {self.model}'


class PropertyNeed(models.Model):
    need = models.OneToOneField(
        Need,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='property',
        verbose_name='Necesidad',
    )
    property_type = models.CharField(max_length=20, verbose_name='Tipo de inmueble')
    listing_intent = models.CharField(
        max_length=10,
        blank=True,
        verbose_name='Arriendo / venta',
    )
    urbanization_type = models.CharField(
        max_length=40,
        blank=True,
        verbose_name='Tipo de ubicación',
    )
    neighborhood = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='Barrio / ubicación',
    )
    area_min_sqm = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Área mínima (m²)',
    )
    bedrooms_min = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Habitaciones mínimas',
    )
    bathrooms_min = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Baños mínimos',
    )
    parking_spots_min = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Parqueaderos mínimos',
    )
    parking_type = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Tipo de parqueadero',
    )
    floors_min = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Número de pisos mínimo',
    )
    has_elevator = models.CharField(
        max_length=20,
        blank=True,
        default='',
        verbose_name='Ascensor',
    )
    furnished = models.CharField(
        max_length=20,
        blank=True,
        default='',
        verbose_name='Amoblado',
    )
    condition = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Condición',
    )
    style = models.CharField(
        max_length=40,
        blank=True,
        verbose_name='Estilo',
    )
    social_amenities = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Zonas sociales',
    )
    remodeling_features = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Remodelación / accesorios',
    )
    has_pool = models.BooleanField(null=True, blank=True, verbose_name='Tiene piscina')
    has_sports_courts = models.BooleanField(
        null=True,
        blank=True,
        verbose_name='Tiene canchas deportivas',
    )
    has_social_area = models.BooleanField(
        null=True,
        blank=True,
        verbose_name='Tiene zona social',
    )
    has_terrace = models.BooleanField(
        null=True,
        blank=True,
        verbose_name='Tiene terraza',
    )
    max_construction_age_years = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Antigüedad máxima de construcción (años)',
    )
    socioeconomic_stratum = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Estrato socioeconómico',
    )
    admin_fee_max_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Administración máxima (COP)',
    )
    utilities_max_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Servicios máximos (COP)',
    )
    required_utilities = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Servicios requeridos',
    )

    class Meta:
        db_table = 'need_properties'
        verbose_name = 'Necesidad de inmueble'
        verbose_name_plural = 'Necesidades de inmueble'

    def __str__(self):
        return f'{self.property_type} — {self.neighborhood or "sin barrio"}'


class NeedCriterion(BaseModel):
    need = models.ForeignKey(
        Need,
        on_delete=models.CASCADE,
        related_name='criteria',
        verbose_name='Necesidad',
    )
    attribute = models.CharField(max_length=80, verbose_name='Atributo')
    mode = models.CharField(
        max_length=20,
        choices=CriterionMode.choices,
        verbose_name='Modo',
    )
    weight = models.IntegerField(default=10, verbose_name='Peso')

    class Meta:
        db_table = 'need_criteria'
        verbose_name = 'Criterio de necesidad'
        verbose_name_plural = 'Criterios de necesidad'
        constraints = [
            models.UniqueConstraint(
                fields=['need', 'attribute'],
                name='unique_criterion_per_need',
            ),
        ]
        indexes = [
            models.Index(fields=['need', 'mode']),
        ]

    def __str__(self):
        return f'{self.attribute} ({self.mode})'


class NeedImage(BaseModel):
    need = models.ForeignKey(
        Need,
        on_delete=models.CASCADE,
        related_name='images',
        verbose_name='Necesidad',
    )
    image_url = models.URLField(max_length=500, verbose_name='URL de imagen')
    caption = models.CharField(max_length=200, blank=True, verbose_name='Leyenda')
    order = models.IntegerField(default=0, verbose_name='Orden')

    class Meta:
        db_table = 'need_images'
        ordering = ['order']
        verbose_name = 'Imagen de necesidad'
        verbose_name_plural = 'Imágenes de necesidad'

    def __str__(self):
        return f'NeedImage({self.need_id}, order={self.order})'
