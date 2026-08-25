from apps.common.exceptions import ValidationError
from apps.common.utils import point_from_coords
from apps.geo.models import GeoCity


def resolve_geo_location(
    *,
    department: str | None = None,
    city: str | None = None,
    geo_city_id=None,
    location=None,
):
    """
    Resolve structured Colombia location.
    Returns dict with department, city, geo_city, location (Point).
    """
    geo_city = None
    if geo_city_id:
        try:
            geo_city = GeoCity.objects.select_related('department').get(
                pk=geo_city_id,
                is_active=True,
            )
        except GeoCity.DoesNotExist as exc:
            raise ValidationError('Ciudad no encontrada en el catálogo') from exc
    elif department and city:
        geo_city = (
            GeoCity.objects.select_related('department')
            .filter(
                is_active=True,
                department__name__iexact=department.strip(),
                name__iexact=city.strip(),
            )
            .first()
        )
        if geo_city is None:
            # Fallback: city name only (legacy clients)
            geo_city = (
                GeoCity.objects.select_related('department')
                .filter(is_active=True, name__iexact=city.strip())
                .first()
            )

    if geo_city is None and city:
        # Keep free-text city for backwards compatibility, but prefer catalog.
        dept_name = (department or '').strip()
        city_name = city.strip()
        point = location
        if point is None:
            point = point_from_coords({'latitude': 4.711, 'longitude': -74.0721})
        return {
            'department': dept_name,
            'city': city_name,
            'geo_city': None,
            'location': point,
        }

    if geo_city is None:
        raise ValidationError('Debes indicar departamento y ciudad')

    point = location
    if point is None and geo_city.latitude is not None and geo_city.longitude is not None:
        point = point_from_coords(
            {
                'latitude': float(geo_city.latitude),
                'longitude': float(geo_city.longitude),
            }
        )
    if point is None:
        point = point_from_coords({'latitude': 4.711, 'longitude': -74.0721})

    return {
        'department': geo_city.department.name,
        'city': geo_city.name,
        'geo_city': geo_city,
        'location': point,
    }


def resolve_travel_city_ids(city_ids: list | None):
    if not city_ids:
        return []
    qs = GeoCity.objects.filter(id__in=city_ids, is_active=True)
    found = {str(c.id) for c in qs}
    missing = [str(i) for i in city_ids if str(i) not in found]
    if missing:
        raise ValidationError(f'Ciudades de desplazamiento inválidas: {", ".join(missing)}')
    return list(qs)
