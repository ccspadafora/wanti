from apps.common.constants import MatchStatus
from apps.common.exceptions import NotFoundError, PermissionError
from apps.matching.models import Match


def list_matches_for_need(need, buyer):
    if need.buyer_id != buyer.id:
        raise PermissionError()
    return (
        Match.objects.filter(need=need)
        .exclude(status=MatchStatus.DISCARDED)
        .select_related('inventory_item', 'seller')
        .order_by('-score')
    )


def list_alerts_for_seller(seller):
    return (
        Match.objects.filter(seller=seller)
        .exclude(status=MatchStatus.DISCARDED)
        .select_related('need', 'buyer', 'inventory_item')
        .order_by('-created_at')
    )


def get_match_detail(match_id, actor_user) -> Match:
    try:
        match = (
            Match.objects.select_related(
                'need',
                'buyer',
                'seller',
                'inventory_item',
                'inventory_item__vehicle',
                'inventory_item__property',
                'unlock',
            )
            .prefetch_related('inventory_item__images', 'criteria_results')
            .get(pk=match_id)
        )
    except Match.DoesNotExist as exc:
        raise NotFoundError('Match no encontrado') from exc
    if actor_user.id not in (match.buyer_id, match.seller_id):
        raise PermissionError()
    return match
