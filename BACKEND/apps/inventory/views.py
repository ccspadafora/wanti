from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.constants import InventoryStatus
from apps.common.exceptions import PermissionError
from apps.common.permissions import IsFullyVerified
from apps.inventory.models import InventoryImage
from apps.inventory.selectors.inventory import get_inventory_item, list_own_inventory
from apps.inventory.serializers import (
    GenerateAIImageSerializer,
    InventoryCreateSerializer,
    InventoryImageSerializer,
    InventoryItemSerializer,
    InventoryListSerializer,
    InventoryStatusSerializer,
    InventoryUpdateSerializer,
    SelectAIImagesSerializer,
)
from apps.inventory.services import inventory as inventory_service


class InventoryListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsFullyVerified()]
        return [IsAuthenticated()]

    def get(self, request):
        qs = list_own_inventory(request.user)
        asset_type = request.query_params.get('asset_type')
        item_status = request.query_params.get('status')
        brand = request.query_params.get('brand')
        model = request.query_params.get('model')
        vehicle_category = request.query_params.get('vehicle_category')
        property_type = request.query_params.get('property_type')
        if asset_type:
            qs = qs.filter(asset_type=asset_type)
        if item_status:
            qs = qs.filter(status=item_status)
        if brand:
            qs = qs.filter(vehicle__brand__iexact=brand.strip())
        if model:
            qs = qs.filter(vehicle__model__iexact=model.strip())
        if vehicle_category:
            qs = qs.filter(vehicle__vehicle_category=vehicle_category)
        if property_type:
            qs = qs.filter(property__property_type=property_type)
        return Response(InventoryListSerializer(qs, many=True).data)

    def post(self, request):
        serializer = InventoryCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        item = inventory_service.create_inventory_item(
            request.user, serializer.to_service_data()
        )
        return Response(InventoryItemSerializer(item).data, status=status.HTTP_201_CREATED)


class InventoryDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, id):
        item = get_inventory_item(id)
        if item.seller_id != request.user.id and item.status != InventoryStatus.AVAILABLE:
            raise PermissionError('Item no disponible')
        return Response(InventoryItemSerializer(item).data)

    def patch(self, request, id):
        item = get_inventory_item(id, seller=request.user)
        serializer = InventoryUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        item = inventory_service.update_inventory_item(
            item, request.user, serializer.to_service_data()
        )
        return Response(InventoryItemSerializer(item).data)

    def delete(self, request, id):
        item = get_inventory_item(id, seller=request.user)
        inventory_service.deactivate(item, request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class InventoryMarkSoldView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        item = get_inventory_item(id, seller=request.user)
        item = inventory_service.mark_as_sold(item, request.user)
        return Response(InventoryStatusSerializer(item).data)


class InventoryReserveView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        item = get_inventory_item(id, seller=request.user)
        item = inventory_service.mark_as_reserved(item, request.user)
        return Response(InventoryStatusSerializer(item).data)


class InventoryReactivateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        item = get_inventory_item(id, seller=request.user)
        item = inventory_service.update_inventory_item(
            item, request.user, {'status': InventoryStatus.AVAILABLE}
        )
        return Response(InventoryStatusSerializer(item).data)


class InventoryGenerateAIImageView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        item = get_inventory_item(id, seller=request.user)
        serializer = GenerateAIImageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        images = inventory_service.generate_ai_images_for_item(
            item,
            prompt=serializer.validated_data['prompt'],
            count=serializer.validated_data.get('count', 3),
        )
        return Response(
            InventoryImageSerializer(images, many=True).data,
            status=status.HTTP_201_CREATED,
        )


class InventorySelectAIImagesView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, id):
        item = get_inventory_item(id, seller=request.user)
        serializer = SelectAIImagesSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        kept = []
        image_ids = serializer.validated_data.get('image_ids') or []
        if image_ids:
            kept.extend(list(item.images.filter(id__in=image_ids)))
        for i, url in enumerate(serializer.validated_data.get('image_urls') or []):
            kept.append(
                InventoryImage.objects.create(
                    item=item,
                    image_url=url,
                    is_ai_generated=True,
                    order=item.images.count() + i,
                )
            )
        return Response(InventoryImageSerializer(kept, many=True).data)
