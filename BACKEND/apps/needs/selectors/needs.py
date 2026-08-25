from apps.common.constants import NeedStatus, UserRole
from apps.common.exceptions import NotFoundError
from apps.needs.models import Need


def get_need_by_id(need_id, actor_user=None) -> Need:
    try:
        need = Need.objects.select_related('buyer', 'vehicle', 'property').get(pk=need_id)
    except Need.DoesNotExist as exc:
        raise NotFoundError('Necesidad no encontrada') from exc
    if actor_user is not None:
        is_owner = need.buyer_id == actor_user.id
        is_staff = actor_user.role in (UserRole.ADMIN, UserRole.MODERATOR)
        if not is_owner and not is_staff and need.status != NeedStatus.ACTIVE:
            raise NotFoundError('Necesidad no encontrada')
    return need


def list_own_needs(buyer):
    return Need.objects.filter(buyer=buyer).exclude(status=NeedStatus.DELETED).order_by(
        '-created_at'
    )


def search_active_needs(
    viewer,
    *,
    asset_type=None,
    city=None,
    brand=None,
    model=None,
    line=None,
    year=None,
    vehicle_category=None,
    fuel_type=None,
    transmission=None,
    property_type=None,
    listing_intent=None,
    bedrooms_min=None,
    bathrooms_min=None,
    area_min_sqm=None,
    socioeconomic_stratum=None,
    parking_spots_min=None,
    max_budget=None,
    ordering='-created_at',
):
    """
    Manual search over active public needs using structured metadata only.
    Does not depend on the viewer's inventory — only excludes their own needs.
    """
    qs = (
        Need.objects.filter(status=NeedStatus.ACTIVE)
        .exclude(buyer=viewer)
        .select_related('buyer', 'vehicle', 'property')
        .prefetch_related('images')
    )
    if asset_type:
        qs = qs.filter(asset_type=asset_type)
    if city:
        qs = qs.filter(city__iexact=city.strip())
    if brand:
        qs = qs.filter(vehicle__brand__iexact=brand.strip())
    if model:
        qs = qs.filter(vehicle__model__iexact=model.strip())
    if line:
        qs = qs.filter(vehicle__line__iexact=line.strip())
    if year is not None:
        qs = qs.filter(vehicle__year_min__lte=year, vehicle__year_max__gte=year)
    if vehicle_category:
        qs = qs.filter(vehicle__vehicle_category=vehicle_category)
    if fuel_type:
        qs = qs.filter(vehicle__fuel_type__iexact=fuel_type.strip())
    if transmission:
        qs = qs.filter(vehicle__transmission__iexact=transmission.strip())
    if property_type:
        qs = qs.filter(property__property_type=property_type)
    if listing_intent:
        qs = qs.filter(property__listing_intent__iexact=str(listing_intent).strip())
    if bedrooms_min is not None:
        qs = qs.filter(property__bedrooms_min__gte=bedrooms_min)
    if bathrooms_min is not None:
        qs = qs.filter(property__bathrooms_min__gte=bathrooms_min)
    if area_min_sqm is not None:
        qs = qs.filter(property__area_min_sqm__gte=area_min_sqm)
    if socioeconomic_stratum is not None:
        qs = qs.filter(property__socioeconomic_stratum=socioeconomic_stratum)
    if parking_spots_min is not None:
        qs = qs.filter(property__parking_spots_min__gte=parking_spots_min)
    if max_budget is not None:
        qs = qs.filter(budget_max_cop__lte=max_budget)
    if ordering.lstrip('-') in ('created_at', 'matches_count', 'budget_max_cop'):
        qs = qs.order_by(ordering)
    else:
        qs = qs.order_by('-created_at')
    return qs


def list_needs_for_seller_search(seller, **kwargs):
    """Backward-compatible alias for browse scope."""
    return search_active_needs(seller, **kwargs)
