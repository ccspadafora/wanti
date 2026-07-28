from django.db import transaction

from apps.audit.services.audit_log import log_audit_event
from apps.common.constants import AssetType, InventoryStatus
from apps.common.exceptions import PermissionError, UserNotVerifiedError, ValidationError
from apps.common.integrations.ai_images.base import generate_images
from apps.inventory.models import InventoryImage, InventoryItem, PropertyItem, VehicleItem


@transaction.atomic
def create_inventory_item(seller, data: dict) -> InventoryItem:
    if not seller.can_publish:
        raise UserNotVerifiedError()
    item = InventoryItem.objects.create(
        seller=seller,
        asset_type=data['asset_type'],
        title=data['title'],
        description=data.get('description', ''),
        price_cop=data['price_cop'],
        city=data['city'],
        location=data['location'],
        status=InventoryStatus.AVAILABLE,
    )
    detail = data.get('detail') or {}
    if item.asset_type == AssetType.VEHICLE:
        VehicleItem.objects.create(item=item, **detail)
    else:
        PropertyItem.objects.create(item=item, **detail)
    for image in data.get('images') or []:
        InventoryImage.objects.create(item=item, **image)
    log_audit_event(
        actor_user=seller,
        action='INVENTORY_CREATED',
        entity='InventoryItem',
        entity_id=item.id,
    )
    from apps.matching.tasks import run_match_for_item_task

    run_match_for_item_task.delay(str(item.id))
    return item


@transaction.atomic
def update_inventory_item(item: InventoryItem, seller, data: dict) -> InventoryItem:
    if item.seller_id != seller.id:
        raise PermissionError()
    rematch = False
    for field in ('title', 'description', 'price_cop', 'city', 'location', 'status'):
        if field in data:
            setattr(item, field, data[field])
            if field in ('price_cop', 'location', 'city', 'status'):
                rematch = True
    item.save()
    if 'detail' in data:
        detail = data['detail']
        if item.asset_type == AssetType.VEHICLE and hasattr(item, 'vehicle'):
            for k, v in detail.items():
                setattr(item.vehicle, k, v)
            item.vehicle.save()
            rematch = True
        elif item.asset_type == AssetType.PROPERTY and hasattr(item, 'property'):
            for k, v in detail.items():
                setattr(item.property, k, v)
            item.property.save()
            rematch = True
    log_audit_event(
        actor_user=seller,
        action='INVENTORY_UPDATED',
        entity='InventoryItem',
        entity_id=item.id,
    )
    if rematch and item.status == InventoryStatus.AVAILABLE:
        from apps.matching.tasks import run_match_for_item_task

        run_match_for_item_task.delay(str(item.id))
    return item


@transaction.atomic
def mark_as_sold(item: InventoryItem, seller) -> InventoryItem:
    if item.seller_id != seller.id:
        raise PermissionError()
    item.status = InventoryStatus.SOLD
    item.save(update_fields=['status', 'updated_at'])
    log_audit_event(
        actor_user=seller, action='INVENTORY_SOLD', entity='InventoryItem', entity_id=item.id
    )
    return item


@transaction.atomic
def mark_as_reserved(item: InventoryItem, seller) -> InventoryItem:
    if item.seller_id != seller.id:
        raise PermissionError()
    item.status = InventoryStatus.RESERVED
    item.save(update_fields=['status', 'updated_at'])
    return item


@transaction.atomic
def deactivate(item: InventoryItem, seller) -> InventoryItem:
    if item.seller_id != seller.id:
        raise PermissionError()
    item.status = InventoryStatus.INACTIVE
    item.save(update_fields=['status', 'updated_at'])
    return item


def generate_ai_images_for_item(item: InventoryItem, prompt: str, count: int = 3):
    results = generate_images(prompt=prompt, count=count)
    created = []
    for i, result in enumerate(results):
        created.append(
            InventoryImage.objects.create(
                item=item,
                image_url=result['image_url'],
                is_ai_generated=True,
                source_prompt=result.get('source_prompt', prompt),
                order=i,
            )
        )
    return created
