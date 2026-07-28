from django.contrib.gis.db.models.functions import Distance
from django.contrib.gis.measure import D
from django.db import transaction

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import AssetType, InventoryStatus, MatchStatus, NeedStatus
from apps.common.services.settings_service import get_setting
from apps.inventory.models import InventoryItem
from apps.matching.models import Match, MatchCriterionResult
from apps.matching.services.scoring import score_pair
from apps.needs.models import Need


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
    need = Need.objects.select_related('buyer').get(id=need_id)
    if need.status != NeedStatus.ACTIVE:
        return 0

    detail = need.vehicle if need.asset_type == AssetType.VEHICLE else need.property
    criteria = list(need.criteria.all())
    radius_km = get_setting('MATCH_RADIUS_KM', 50)
    candidates = (
        InventoryItem.objects.filter(
            asset_type=need.asset_type,
            status=InventoryStatus.AVAILABLE,
        )
        .exclude(seller=need.buyer)
        .annotate(distance=Distance('location', need.location))
        .filter(location__dwithin=(need.location, D(km=radius_km)))
        .select_related('vehicle', 'property', 'seller')
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
    candidate_needs = (
        Need.objects.filter(asset_type=item.asset_type, status=NeedStatus.ACTIVE)
        .exclude(buyer=item.seller)
        .annotate(distance=Distance('location', item.location))
        .filter(location__dwithin=(item.location, D(km=radius_km)))
        .select_related('vehicle', 'property', 'buyer')
        .prefetch_related('criteria')
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
