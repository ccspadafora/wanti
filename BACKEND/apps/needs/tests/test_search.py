from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase

from apps.needs.selectors.needs import search_active_needs


class SearchActiveNeedsQueryTests(SimpleTestCase):
    @patch('apps.needs.selectors.needs.Need')
    def test_search_does_not_filter_by_viewer_inventory(self, need_model):
        viewer = SimpleNamespace(id='viewer-id')
        chain = MagicMock()
        need_model.objects.filter.return_value = chain
        chain.exclude.return_value = chain
        chain.select_related.return_value = chain
        chain.prefetch_related.return_value = chain
        chain.filter.return_value = chain
        chain.order_by.return_value = chain

        search_active_needs(viewer, asset_type='VEHICLE', brand='Kawasaki')

        chain.exclude.assert_called_once_with(buyer=viewer)
        filter_kwargs = [c.kwargs for c in chain.filter.call_args_list]
        assert {'asset_type': 'VEHICLE'} in filter_kwargs
        assert {'vehicle__brand__iexact': 'Kawasaki'} in filter_kwargs
        inventory_attrs = [k for c in chain.filter.call_args_list for k in c.kwargs if 'inventory' in k]
        assert inventory_attrs == []

    @patch('apps.needs.selectors.needs.Need')
    def test_property_search_uses_property_filters_only(self, need_model):
        viewer = SimpleNamespace(id='viewer-id')
        chain = MagicMock()
        need_model.objects.filter.return_value = chain
        chain.exclude.return_value = chain
        chain.select_related.return_value = chain
        chain.prefetch_related.return_value = chain
        chain.filter.return_value = chain
        chain.order_by.return_value = chain

        search_active_needs(
            viewer,
            asset_type='PROPERTY',
            property_type='APTO',
            listing_intent='SALE',
            bedrooms_min=3,
            area_min_sqm=80,
            socioeconomic_stratum=4,
        )

        filter_kwargs = [c.kwargs for c in chain.filter.call_args_list]
        assert {'asset_type': 'PROPERTY'} in filter_kwargs
        assert {'property__property_type': 'APTO'} in filter_kwargs
        assert {'property__listing_intent__iexact': 'SALE'} in filter_kwargs
        assert {'property__bedrooms_min__gte': 3} in filter_kwargs
        assert {'property__area_min_sqm__gte': 80} in filter_kwargs
        assert {'property__socioeconomic_stratum': 4} in filter_kwargs
        vehicle_attrs = [
            k for c in chain.filter.call_args_list for k in c.kwargs if k.startswith('vehicle__')
        ]
        assert vehicle_attrs == []
