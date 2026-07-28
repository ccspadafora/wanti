from django.urls import path

from apps.inventory.views import (
    InventoryDetailView,
    InventoryGenerateAIImageView,
    InventoryListCreateView,
    InventoryMarkSoldView,
    InventoryReactivateView,
    InventoryReserveView,
    InventorySelectAIImagesView,
)

urlpatterns = [
    path('', InventoryListCreateView.as_view(), name='inventory-list-create'),
    path('<uuid:id>/', InventoryDetailView.as_view(), name='inventory-detail'),
    path('<uuid:id>/mark-sold/', InventoryMarkSoldView.as_view(), name='inventory-mark-sold'),
    path('<uuid:id>/reserve/', InventoryReserveView.as_view(), name='inventory-reserve'),
    path('<uuid:id>/reactivate/', InventoryReactivateView.as_view(), name='inventory-reactivate'),
    path(
        '<uuid:id>/generate-ai-image/',
        InventoryGenerateAIImageView.as_view(),
        name='inventory-generate-ai-image',
    ),
    path(
        '<uuid:id>/images/select-ai/',
        InventorySelectAIImagesView.as_view(),
        name='inventory-select-ai',
    ),
]
