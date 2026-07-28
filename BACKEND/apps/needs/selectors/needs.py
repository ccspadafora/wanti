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


def list_needs_for_seller_search(seller, *, asset_type=None, city=None):
    qs = Need.objects.filter(status=NeedStatus.ACTIVE).exclude(buyer=seller)
    if asset_type:
        qs = qs.filter(asset_type=asset_type)
    if city:
        qs = qs.filter(city__icontains=city)
    return qs.order_by('-created_at')
