"""Importación masiva de catálogo vehicular desde CSV."""

from __future__ import annotations

import csv
import io
from dataclasses import dataclass, field

from django.db import transaction
from django.utils.text import slugify

from apps.catalog.models import (
    VehicleBrand,
    VehicleModel,
    VehicleModelYear,
    VehicleVersion,
    VehicleVersionSpec,
)
from apps.catalog.services.version_specs import infer_specs_from_name
from apps.common.constants import VehicleCategory

POPULAR_BRANDS = {
    'Chevrolet',
    'Renault',
    'Mazda',
    'Toyota',
    'Kia',
    'Hyundai',
    'Nissan',
    'Ford',
    'Volkswagen',
    'Suzuki',
    'BMW',
    'Mercedes-Benz',
    'Yamaha',
    'Honda',
    'Bajaj',
    'AKT',
}

POPULAR_MODELS = {
    ('Chevrolet', 'Spark'),
    ('Chevrolet', 'Sail'),
    ('Chevrolet', 'Tracker'),
    ('Chevrolet', 'Onix'),
    ('Renault', 'Sandero'),
    ('Renault', 'Duster'),
    ('Mazda', '3'),
    ('Mazda', 'CX-5'),
    ('Toyota', 'Corolla'),
    ('Toyota', 'Fortuner'),
}

_CATEGORY_ALIASES = {
    'CAR': VehicleCategory.CAR,
    'CARROS': VehicleCategory.CAR,
    'CARRO': VehicleCategory.CAR,
    'AUTOMOVIL': VehicleCategory.CAR,
    'AUTOMÓVIL': VehicleCategory.CAR,
    'AUTO': VehicleCategory.CAR,
    'SUV': VehicleCategory.SUV,
    'CAMIONETAS': VehicleCategory.SUV,
    'CAMIONETA': VehicleCategory.SUV,
    'MOTO': VehicleCategory.MOTO,
    'MOTOS': VehicleCategory.MOTO,
    'MOTOCICLETA': VehicleCategory.MOTO,
    'COLLECTION': VehicleCategory.COLLECTION,
    'COLECCION': VehicleCategory.COLLECTION,
    'COLECCIÓN': VehicleCategory.COLLECTION,
    'TRUCK': VehicleCategory.TRUCK,
    'CAMIONES': VehicleCategory.TRUCK,
    'CAMION': VehicleCategory.TRUCK,
    'CAMIÓN': VehicleCategory.TRUCK,
    'NAUTICAL': VehicleCategory.NAUTICAL,
    'NAUTICA': VehicleCategory.NAUTICAL,
    'NÁUTICA': VehicleCategory.NAUTICAL,
    'HEAVY_MACHINERY': VehicleCategory.HEAVY_MACHINERY,
    'MAQUINARIA': VehicleCategory.HEAVY_MACHINERY,
    'MAQUINARIA_PESADA': VehicleCategory.HEAVY_MACHINERY,
    'OTHER': VehicleCategory.OTHER,
    'OTROS': VehicleCategory.OTHER,
}

_FUEL_ALIASES = {
    'gasolina': 'Gasolina',
    'diesel': 'Diésel',
    'diésel': 'Diésel',
    'electrico': 'Eléctrico',
    'eléctrico': 'Eléctrico',
    'hibrido': 'Híbrido',
    'híbrido': 'Híbrido',
}

_TRANS_ALIASES = {
    'mecanica': 'Mecánica',
    'mecánica': 'Mecánica',
    'manual': 'Mecánica',
    'automatica': 'Automática',
    'automática': 'Automática',
    'auto': 'Automática',
    'semi-automatica': 'Semi-automática',
    'semi-automática': 'Semi-automática',
    'semiautomatica': 'Semi-automática',
}

_TRACTION_ALIASES = {
    '4x4': '4x4',
    '4x2': '4x2',
    'awd': 'AWD',
    '2wd': '4x2',
    '4wd': '4x4',
}


@dataclass
class RowError:
    row: int
    field: str
    message: str


@dataclass
class ImportResult:
    dry_run: bool
    total_rows: int = 0
    created_brands: int = 0
    created_models: int = 0
    created_years: int = 0
    created_versions: int = 0
    updated_versions: int = 0
    skipped_duplicates: int = 0
    specs_upserted: int = 0
    errors: list[RowError] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            'dry_run': self.dry_run,
            'total_rows': self.total_rows,
            'created_brands': self.created_brands,
            'created_models': self.created_models,
            'created_years': self.created_years,
            'created_versions': self.created_versions,
            'updated_versions': self.updated_versions,
            'skipped_duplicates': self.skipped_duplicates,
            'specs_upserted': self.specs_upserted,
            'error_count': len(self.errors),
            'errors': [
                {'row': e.row, 'field': e.field, 'message': e.message} for e in self.errors[:200]
            ],
            'errors_truncated': max(0, len(self.errors) - 200),
        }


def _norm_header(name: str) -> str:
    return (
        (name or '')
        .strip()
        .lower()
        .replace('á', 'a')
        .replace('é', 'e')
        .replace('í', 'i')
        .replace('ó', 'o')
        .replace('ú', 'u')
        .replace('ñ', 'n')
        .replace(' ', '_')
    )


def _cell(row: dict, *keys: str) -> str:
    for key in keys:
        for raw_key, value in row.items():
            if _norm_header(str(raw_key)) == key:
                return (value or '').strip()
    return ''


def _parse_category(raw: str) -> str | None:
    if not raw:
        return VehicleCategory.CAR
    key = raw.strip().upper().replace(' ', '_')
    return _CATEGORY_ALIASES.get(key)


def _parse_bool(raw: str, default: bool = True) -> bool:
    if raw == '':
        return default
    return raw.strip().lower() in {'1', 'true', 'yes', 'si', 'sí', 'y', 'activo'}


def _normalize_option(raw: str, aliases: dict[str, str]) -> str | None:
    if not raw:
        return None
    key = raw.strip().lower()
    return aliases.get(key) or raw.strip()


def import_vehicle_catalog_csv(
    file_obj,
    *,
    dry_run: bool = False,
    update_existing: bool = True,
    default_category: str = VehicleCategory.CAR,
    max_errors: int = 500,
) -> ImportResult:
    """
    Importa CSV de catálogo.
    Columnas mínimas: marca, modelo, anio, version.
    Opcionales: categoria, combustible, transmision, traccion, activo, clave_catalogo.
    """
    result = ImportResult(dry_run=dry_run)

    raw = file_obj.read()
    if isinstance(raw, bytes):
        text = raw.decode('utf-8-sig')
    else:
        text = str(raw)

    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames:
        result.errors.append(RowError(0, 'csv', 'El archivo no tiene encabezados'))
        return result

    brands: dict[tuple[str, str], VehicleBrand] = {
        (b.name, b.category): b for b in VehicleBrand.objects.all()
    }
    models: dict[tuple[str, str, str], VehicleModel] = {
        (m.brand.name, m.brand.category, m.name): m
        for m in VehicleModel.objects.select_related('brand')
    }
    years: dict[tuple[str, str, str, int], VehicleModelYear] = {
        (y.model.brand.name, y.model.brand.category, y.model.name, y.year): y
        for y in VehicleModelYear.objects.select_related('model__brand')
    }
    versions_by_key: dict[str, VehicleVersion] = {
        v.catalog_key: v for v in VehicleVersion.objects.all()
    }

    pending_versions: list[VehicleVersion] = []
    pending_specs: list[tuple[str, dict]] = []  # catalog_key -> specs payload

    def flush_versions():
        nonlocal pending_versions
        if dry_run or not pending_versions:
            pending_versions = []
            return
        VehicleVersion.objects.bulk_create(pending_versions, ignore_conflicts=True)
        pending_versions = []

    for i, row in enumerate(reader, start=2):  # header = row 1
        result.total_rows += 1
        if len(result.errors) >= max_errors:
            result.errors.append(
                RowError(i, 'csv', f'Se alcanzó el máximo de {max_errors} errores; se detuvo el análisis')
            )
            break

        marca = _cell(row, 'marca', 'brand')
        modelo = _cell(row, 'modelo', 'model')
        version = _cell(row, 'version', 'version_name', 'linea', 'referencia')
        anio_raw = _cell(row, 'anio', 'ano', 'year')
        categoria_raw = _cell(row, 'categoria', 'category', 'tipo') or default_category
        combustible = _normalize_option(_cell(row, 'combustible', 'fuel', 'fuel_type'), _FUEL_ALIASES)
        transmision = _normalize_option(
            _cell(row, 'transmision', 'transmission', 'caja'), _TRANS_ALIASES
        )
        traccion = _normalize_option(
            _cell(row, 'traccion', 'traction', 'drivetrain'), _TRACTION_ALIASES
        )
        activo = _parse_bool(_cell(row, 'activo', 'active', 'estado'), default=True)
        calidad = _cell(row, 'calidad_registro', 'quality') or 'catalogo_ampliado'

        if not marca:
            result.errors.append(RowError(i, 'marca', 'Marca requerida'))
            continue
        if not modelo:
            result.errors.append(RowError(i, 'modelo', 'Modelo requerido'))
            continue
        if not version:
            result.errors.append(RowError(i, 'version', 'Versión requerida'))
            continue

        category = _parse_category(categoria_raw)
        if category is None:
            result.errors.append(
                RowError(i, 'categoria', f'Categoría inválida: {categoria_raw}')
            )
            continue

        try:
            anio = int(anio_raw)
        except (TypeError, ValueError):
            result.errors.append(RowError(i, 'anio', f'Año inválido: {anio_raw!r}'))
            continue
        if anio < 1950 or anio > 2100:
            result.errors.append(RowError(i, 'anio', f'Año fuera de rango: {anio}'))
            continue

        clave = _cell(row, 'clave_catalogo', 'catalog_key') or f'{marca}|{modelo}|{anio}|{version}'
        if category != VehicleCategory.CAR:
            # Evita colisión de keys entre categorías distintas.
            if not clave.startswith(f'{category}|'):
                clave = f'{category}|{clave}'

        existing = versions_by_key.get(clave)
        if existing and not update_existing:
            result.skipped_duplicates += 1
            continue

        brand_key = (marca, category)
        brand = brands.get(brand_key)
        if brand is None:
            if not dry_run:
                slug = slugify(f'{marca}-{category}') or f'marca-{len(brands) + 1}'
                base = slug
                n = 1
                while VehicleBrand.objects.filter(slug=slug).exists():
                    slug = f'{base}-{n}'
                    n += 1
                brand = VehicleBrand.objects.create(
                    name=marca,
                    slug=slug,
                    category=category,
                    is_popular=marca in POPULAR_BRANDS,
                    is_active=True,
                )
            else:
                brand = VehicleBrand(
                    name=marca,
                    category=category,
                    is_popular=marca in POPULAR_BRANDS,
                    is_active=True,
                )
            brands[brand_key] = brand
            result.created_brands += 1

        model_key = (marca, category, modelo)
        model = models.get(model_key)
        if model is None:
            if not dry_run:
                slug = slugify(modelo) or f'modelo-{len(models) + 1}'
                base = slug
                n = 1
                while VehicleModel.objects.filter(brand=brand, slug=slug).exists():
                    slug = f'{base}-{n}'
                    n += 1
                model = VehicleModel.objects.create(
                    brand=brand,
                    name=modelo,
                    slug=slug,
                    is_popular=(marca, modelo) in POPULAR_MODELS,
                    is_active=True,
                )
            else:
                model = VehicleModel(brand=brand, name=modelo, is_active=True)
            models[model_key] = model
            result.created_models += 1

        year_key = (marca, category, modelo, anio)
        model_year = years.get(year_key)
        if model_year is None:
            if not dry_run:
                model_year = VehicleModelYear.objects.create(
                    model=model,
                    year=anio,
                    is_popular=anio >= 2014,
                    is_active=True,
                )
            else:
                model_year = VehicleModelYear(model=model, year=anio, is_active=True)
            years[year_key] = model_year
            result.created_years += 1

        specs_data = infer_specs_from_name(version)
        if combustible:
            specs_data['fuel_types'] = [combustible]
        if transmision:
            specs_data['transmissions'] = [transmision]
        if traccion:
            specs_data['tractions'] = [traccion]

        if existing and update_existing:
            result.updated_versions += 1
            if not dry_run:
                existing.name = version
                existing.quality = calidad
                existing.is_active = activo
                existing.model_year = model_year
                existing.save(
                    update_fields=['name', 'quality', 'is_active', 'model_year', 'updated_at']
                )
                VehicleVersionSpec.objects.update_or_create(
                    version=existing,
                    defaults={**specs_data, 'source': 'import'},
                )
                result.specs_upserted += 1
            continue

        if existing:
            result.skipped_duplicates += 1
            continue

        result.created_versions += 1
        if dry_run:
            versions_by_key[clave] = VehicleVersion(catalog_key=clave, name=version)
            if combustible or transmision or traccion or specs_data.get('fuel_types'):
                result.specs_upserted += 1
            continue

        pending_versions.append(
            VehicleVersion(
                model_year=model_year,
                name=version,
                catalog_key=clave,
                quality=calidad,
                is_active=activo,
            )
        )
        pending_specs.append((clave, {**specs_data, 'source': 'import'}))
        versions_by_key[clave] = pending_versions[-1]

        if len(pending_versions) >= 500:
            flush_versions()

    flush_versions()

    if not dry_run and pending_specs:
        # Resolver versiones recién creadas por catalog_key y upsert specs.
        keys = [k for k, _ in pending_specs]
        found = {
            v.catalog_key: v
            for v in VehicleVersion.objects.filter(catalog_key__in=keys)
        }
        for key, data in pending_specs:
            version = found.get(key)
            if version is None:
                continue
            VehicleVersionSpec.objects.update_or_create(
                version=version,
                defaults=data,
            )
            result.specs_upserted += 1

    return result


@transaction.atomic
def apply_vehicle_catalog_csv(file_obj, **kwargs) -> ImportResult:
    return import_vehicle_catalog_csv(file_obj, dry_run=False, **kwargs)
