from django.conf import settings
from django.contrib.gis.db import models

from apps.common.constants import AssetType, InventoryStatus, VehicleCategory
from apps.common.models import BaseModel


class InventoryItem(BaseModel):
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name='inventory',
        verbose_name='Vendedor',
    )
    asset_type = models.CharField(
        max_length=20,
        choices=AssetType.choices,
        verbose_name='Tipo de activo',
    )
    title = models.CharField(max_length=150, verbose_name='Título')
    description = models.TextField(blank=True, verbose_name='Descripción')
    price_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        verbose_name='Precio (COP)',
    )
    city = models.CharField(max_length=100, verbose_name='Ciudad')
    location = models.PointField(
        srid=4326,
        geography=True,
        verbose_name='Ubicación',
    )
    status = models.CharField(
        max_length=20,
        choices=InventoryStatus.choices,
        default=InventoryStatus.AVAILABLE,
        verbose_name='Estado',
    )
    views_count = models.IntegerField(default=0, verbose_name='Cantidad de vistas')
    unlock_count = models.IntegerField(
        default=0,
        verbose_name='Cantidad de desbloqueos',
    )

    class Meta:
        db_table = 'inventory_items'
        verbose_name = 'Publicación'
        verbose_name_plural = 'Publicaciones'
        indexes = [
            models.Index(fields=['seller', 'status']),
            models.Index(fields=['asset_type', 'status']),
            models.Index(fields=['city']),
        ]

    def __str__(self):
        return f'{self.title} ({self.status})'


class VehicleItem(models.Model):
    item = models.OneToOneField(
        InventoryItem,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='vehicle',
        verbose_name='Publicación',
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
    year = models.IntegerField(verbose_name='Año')
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
    mileage_km = models.IntegerField(verbose_name='Kilometraje (km)')
    doors = models.IntegerField(null=True, blank=True, verbose_name='Puertas')
    single_owner = models.BooleanField(
        null=True,
        blank=True,
        verbose_name='Único dueño',
    )
    owners_count = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Cantidad de dueños',
    )
    plate_last_digit = models.CharField(
        max_length=2,
        blank=True,
        verbose_name='Último dígito de placa',
    )
    insurance_reports = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Reportes de aseguradora',
    )
    accessories = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Accesorios',
    )

    class Meta:
        db_table = 'inventory_vehicles'
        verbose_name = 'Datos del vehículo'
        verbose_name_plural = 'Datos de vehículos'

    def __str__(self):
        return f'{self.brand} {self.model} ({self.year})'


class PropertyItem(models.Model):
    item = models.OneToOneField(
        InventoryItem,
        on_delete=models.CASCADE,
        primary_key=True,
        related_name='property',
        verbose_name='Publicación',
    )
    property_type = models.CharField(max_length=20, verbose_name='Tipo de inmueble')
    listing_intent = models.CharField(
        max_length=10,
        blank=True,
        verbose_name='Arriendo / venta',
    )
    neighborhood = models.CharField(
        max_length=120,
        blank=True,
        verbose_name='Barrio',
    )
    area_sqm = models.IntegerField(null=True, blank=True, verbose_name='Área (m²)')
    bedrooms = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Habitaciones',
    )
    bathrooms = models.IntegerField(null=True, blank=True, verbose_name='Baños')
    parking_spots = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Parqueaderos',
    )
    parking_type = models.CharField(
        max_length=20,
        blank=True,
        verbose_name='Tipo de parqueadero',
    )
    floors = models.IntegerField(null=True, blank=True, verbose_name='Número de pisos')
    floor = models.IntegerField(null=True, blank=True, verbose_name='Piso')
    has_elevator = models.BooleanField(
        null=True,
        blank=True,
        verbose_name='Tiene ascensor',
    )
    furnished = models.BooleanField(
        null=True,
        blank=True,
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
    urbanization_type = models.CharField(
        max_length=40,
        blank=True,
        verbose_name='Tipo de ubicación',
    )
    construction_year = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Año de construcción',
    )
    socioeconomic_stratum = models.IntegerField(
        null=True,
        blank=True,
        verbose_name='Estrato socioeconómico',
    )
    admin_fee_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Administración (COP)',
    )
    utilities_avg_cop = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True,
        verbose_name='Servicios promedio (COP)',
    )
    available_utilities = models.JSONField(
        default=list,
        blank=True,
        verbose_name='Servicios disponibles',
    )

    class Meta:
        db_table = 'inventory_properties'
        verbose_name = 'Datos del inmueble'
        verbose_name_plural = 'Datos de inmuebles'

    def __str__(self):
        return f'{self.property_type} — {self.neighborhood or "sin barrio"}'


class InventoryImage(BaseModel):
    item = models.ForeignKey(
        InventoryItem,
        on_delete=models.CASCADE,
        related_name='images',
        verbose_name='Publicación',
    )
    image_url = models.URLField(max_length=500, verbose_name='URL de imagen')
    is_ai_generated = models.BooleanField(
        default=False,
        verbose_name='Generada por IA',
    )
    source_prompt = models.TextField(blank=True, verbose_name='Indicación para IA')
    order = models.IntegerField(default=0, verbose_name='Orden')

    class Meta:
        db_table = 'inventory_images'
        ordering = ['order']
        verbose_name = 'Foto de la publicación'
        verbose_name_plural = 'Fotos de la publicación'

    def __str__(self):
        return f'InventoryImage({self.item_id}, order={self.order})'
