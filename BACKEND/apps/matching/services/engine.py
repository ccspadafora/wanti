from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.measure import D
from django.db import transaction
from django.db.models import Q

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import AssetType, InventoryStatus, MatchStatus, NeedStatus
from apps.common.services.settings_service import get_setting
from apps.inventory.models import InventoryItem
from apps.matching.models import Match, MatchCriterionResult
from apps.matching.services.scoring import score_pair
from apps.needs.models import Need


def _vehicle_structural_filters(detail):
    """Pre-filter queryset using structured vehicle identity fields."""
    filters = {}
    if not detail:
        return filters
    if detail.brand and str(detail.brand).strip():
        filters['vehicle__brand__iexact'] = detail.brand.strip()
    if detail.model and str(detail.model).strip():
        filters['vehicle__model__iexact'] = detail.model.strip()
    if detail.vehicle_category:
        filters['vehicle__vehicle_category'] = detail.vehicle_category
    return filters


def _need_structural_filters(detail):
    """Pre-filter needs using structured vehicle identity fields."""
    filters = {}
    if not detail:
        return filters
    if detail.brand and str(detail.brand).strip():
        filters['vehicle__brand__iexact'] = detail.brand.strip()
    if detail.model and str(detail.model).strip():
        filters['vehicle__model__iexact'] = detail.model.strip()
    if detail.vehicle_category:
        filters['vehicle__vehicle_category'] = detail.vehicle_category
    return filters


def _allowed_city_names(need):
    names = []
    if need.city:
        names.append(need.city.strip())
    if need.willing_to_travel:
        names.extend([c.name for c in need.travel_cities.all()])
    return names


def _persist_match(need, item, result, distance_km):
    match, created = Match.objects.update_or_create(
        need=need,
        inventory_item=item,
        defaults={
            'buyer': need.buyer,
            'seller': item.seller,
            'score': result['score'],
            'distance_km': round(float(distance_km), 2),
            'required_criteria_met': result['required_met'],
            'unmet_preferences': result['unmet_preferences'],
            'status': MatchStatus.GENERATED,
        },
    )
    if created:
        MatchCriterionResult.objects.bulk_create(
            [MatchCriterionResult(match=match, **cr) for cr in result['criteria_results']]
        )
    else:
        MatchCriterionResult.objects.filter(match=match).delete()
        MatchCriterionResult.objects.bulk_create(
            [MatchCriterionResult(match=match, **cr) for cr in result['criteria_results']]
        )
    return match, created


def run_match_for_need(need_id):
    need = Need.objects.select_related('buyer').prefetch_related('travel_cities').get(id=need_id)
    if need.status != NeedStatus.ACTIVE:
        return 0

    detail = need.vehicle if need.asset_type == AssetType.VEHICLE else need.property
    criteria = list(need.criteria.all())
    radius_km = get_setting('MATCH_RADIUS_KM', 50)
    city_names = _allowed_city_names(need)
    geo_q = Q(location__dwithin=(need.location, D(km=radius_km)))
    if city_names:
        city_q = Q()
        for name in city_names:
            city_q |= Q(city__iexact=name)
        geo_q |= city_q

    candidates = (
        InventoryItem.objects.filter(
            asset_type=need.asset_type,
            status=InventoryStatus.AVAILABLE,
        )
        .exclude(seller=need.buyer)
        .annotate(distance=Distance('location', need.location))
        .filter(geo_q)
        .select_related('vehicle', 'property', 'seller')
        .distinct()
    )
    if need.asset_type == AssetType.VEHICLE:
        candidates = candidates.filter(**_vehicle_structural_filters(detail))
    elif need.asset_type == AssetType.PROPERTY and detail:
        if detail.property_type:
            candidates = candidates.filter(property__property_type=detail.property_type)
        if getattr(detail, 'listing_intent', None) and str(detail.listing_intent).strip():
            candidates = candidates.filter(
                property__listing_intent__iexact=detail.listing_intent.strip()
            )
    min_score = get_setting('MATCH_MIN_SCORE', 50)
    matches_created = 0

    for item in candidates:
        item_detail = item.vehicle if item.asset_type == AssetType.VEHICLE else item.property
        distance_km = item.distance.km if item.distance else 0
        result = score_pair(need, detail, criteria, item, item_detail, distance_km)
        if result['score'] < min_score:
            continue
        with transaction.atomic():
            _, created = _persist_match(need, item, result, distance_km)
            if created:
                matches_created += 1

    count = Match.objects.filter(need=need).exclude(status=MatchStatus.DISCARDED).count()
    Need.objects.filter(id=need.id).update(matches_count=count)
    log_audit_event(
        actor_user=None,
        action='MATCH_ENGINE_RUN',
        entity='Need',
        entity_id=need.id,
        metadata={'matches_created': matches_created},
    )
    from apps.notifications.tasks import notify_matches

    notify_matches.delay(str(need.id))
    return matches_created


def run_match_for_item(item_id):
    item = InventoryItem.objects.select_related('seller').get(id=item_id)
    if item.status != InventoryStatus.AVAILABLE:
        return 0

    detail = item.vehicle if item.asset_type == AssetType.VEHICLE else item.property
    radius_km = get_setting('MATCH_RADIUS_KM', 50)
    geo_q = Q(location__dwithin=(item.location, D(km=radius_km)))
    if item.city:
        geo_q |= Q(city__iexact=item.city.strip()) | Q(
            willing_to_travel=True,
            travel_cities__name__iexact=item.city.strip(),
        )

    candidate_needs = (
        Need.objects.filter(asset_type=item.asset_type, status=NeedStatus.ACTIVE)
        .exclude(buyer=item.seller)
        .annotate(distance=Distance('location', item.location))
        .filter(geo_q)
        .select_related('vehicle', 'property', 'buyer')
        .prefetch_related('criteria', 'travel_cities')
        .distinct()
    )
    if item.asset_type == AssetType.VEHICLE:
        candidate_needs = candidate_needs.filter(**_need_structural_filters(detail))
    elif item.asset_type == AssetType.PROPERTY and detail:
        if detail.property_type:
            candidate_needs = candidate_needs.filter(property__property_type=detail.property_type)
        if getattr(detail, 'listing_intent', None) and str(detail.listing_intent).strip():
            candidate_needs = candidate_needs.filter(
                property__listing_intent__iexact=detail.listing_intent.strip()
            )
    min_score = get_setting('MATCH_MIN_SCORE', 50)
    created_count = 0
    for need in candidate_needs:
        need_detail = need.vehicle if need.asset_type == AssetType.VEHICLE else need.property
        distance_km = need.distance.km if need.distance else 0
        criteria = list(need.criteria.all())
        result = score_pair(need, need_detail, criteria, item, detail, distance_km)
        if result['score'] < min_score:
            continue
        with transaction.atomic():
            _, created = _persist_match(need, item, result, distance_km)
            if created:
                created_count += 1
            count = (
                Match.objects.filter(need=need).exclude(status=MatchStatus.DISCARDED).count()
            )
            Need.objects.filter(id=need.id).update(matches_count=count)
    return created_count
