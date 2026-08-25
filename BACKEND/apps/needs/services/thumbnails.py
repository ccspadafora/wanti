"""Helpers para miniaturas de sueños generadas / catalogadas por IA."""

from __future__ import annotations

from typing import Optional

from apps.common.constants import AssetType
from apps.common.integrations.ai_images.base import generate_images
from apps.needs.models import NeedImage


CATALOG_SCHEMES = {
    'car': 'wanti-ai://catalog/car',
    'suv': 'wanti-ai://catalog/suv',
    'moto': 'wanti-ai://catalog/moto',
    'apto': 'wanti-ai://catalog/apto',
    'casa': 'wanti-ai://catalog/casa',
    'local': 'wanti-ai://catalog/local',
}

_SUV_HINTS = (
    'hilux',
    'prado',
    'rav',
    'tucson',
    'sportage',
    'tracker',
    'duster',
    '4runner',
    'fortuner',
)


def catalog_key_for_need(need) -> str:
    if need.asset_type == AssetType.PROPERTY:
        prop = getattr(need, 'property', None)
        ptype = (getattr(prop, 'property_type', '') or '').upper()
        if ptype in {'CASA', 'LOTE_FINCA'}:
            return 'casa'
        if ptype in {'LOCAL', 'BODEGA', 'CONSULTORIO'}:
            return 'local'
        return 'apto'

    vehicle = getattr(need, 'vehicle', None)
    category = (getattr(vehicle, 'vehicle_category', '') or 'CAR').upper()
    if category == 'MOTO':
        return 'moto'
    model = (getattr(vehicle, 'model', '') or '').lower()
    if any(h in model for h in _SUV_HINTS):
        return 'suv'
    return 'suv' if category == 'OTHER' else 'car'


def catalog_url_for_need(need) -> str:
    return CATALOG_SCHEMES[catalog_key_for_need(need)]


def ensure_need_thumbnail(need) -> Optional[NeedImage]:
    """Asocia una miniatura de catálogo IA si el sueño no tiene imágenes."""
    if need.images.exists():
        return need.images.order_by('order').first()

    key = catalog_key_for_need(need)
    prompt = f'Wanti catalog thumbnail for {need.asset_type} / {key}: {need.title}'
    generated = generate_images(prompt=prompt, count=1)
    image_url = CATALOG_SCHEMES[key]
    caption = generated[0].get('source_prompt') or prompt
    return NeedImage.objects.create(
        need=need,
        image_url=image_url,
        caption=(caption or '')[:200],
        order=0,
    )


def thumbnail_url_for_need(need) -> Optional[str]:
    image = need.images.order_by('order').first()
    if image and image.image_url:
        return image.image_url
    return catalog_url_for_need(need)
