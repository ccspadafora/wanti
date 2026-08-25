from apps.common.exceptions import NotFoundError
from apps.inventory.models import InventoryItem


def get_inventory_item(item_id, seller=None) -> InventoryItem:
    try:
        item = InventoryItem.objects.select_related('seller', 'vehicle', 'property').get(
            pk=item_id
        )
    except InventoryItem.DoesNotExist as exc:
        raise NotFoundError('Item no encontrado') from exc
    if seller is not None and item.seller_id != seller.id:
        raise NotFoundError('Item no encontrado')
    return item


def list_own_inventory(seller):
    from django.db.models import Count, Q

    from apps.common.constants import MatchStatus

    return (
        InventoryItem.objects.filter(seller=seller)
        .select_related('vehicle', 'property')
        .prefetch_related('images')
        .annotate(
            matches_count=Count(
                'matches',
                filter=~Q(matches__status=MatchStatus.DISCARDED),
            )
        )
        .order_by('-created_at')
    )
