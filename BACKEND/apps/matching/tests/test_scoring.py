from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase

from apps.common.constants import AssetType
from apps.matching.services.scoring import score_pair


def _vehicle_need(**kwargs):
    defaults = {
        'vehicle_category': 'CAR',
        'brand': 'Chevrolet',
        'model': 'Spark',
        'line': 'GT',
        'year_min': 2020,
        'year_max': 2020,
        'fuel_type': 'Gasolina',
        'transmission': 'Automática',
    }
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


def _vehicle_item(**kwargs):
    defaults = {
        'vehicle_category': 'CAR',
        'brand': 'Chevrolet',
        'model': 'Spark',
        'line': 'GT',
        'year': 2020,
        'fuel_type': 'Gasolina',
        'transmission': 'Automática',
        'mileage_km': 45000,
    }
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


class ScoringStructuralGatesTests(SimpleTestCase):
    def setUp(self):
        self.settings_patcher = patch(
            'apps.matching.services.scoring.get_setting',
            side_effect=lambda key, default=None: {
                'MATCH_RADIUS_KM': 50,
                'MIN_BUDGET_RATIO': 0.40,
            }.get(key, default),
        )
        self.settings_patcher.start()

    def tearDown(self):
        self.settings_patcher.stop()

    def _score(self, need_vehicle, item_vehicle, criteria=None):
        need = SimpleNamespace(
            asset_type=AssetType.VEHICLE,
            budget_max_cop=Decimal('75000000'),
        )
        item = SimpleNamespace(price_cop=Decimal('70000000'))
        criteria = criteria or [
            SimpleNamespace(attribute='fuel_type', mode='REQUIRED', weight=20),
            SimpleNamespace(attribute='transmission', mode='REQUIRED', weight=20),
        ]
        return score_pair(
            need,
            need_vehicle,
            criteria,
            item,
            item_vehicle,
            distance_km=5,
        )

    def test_spark_gt_does_not_match_mercedes_with_shared_secondary_attrs(self):
        result = self._score(
            _vehicle_need(),
            _vehicle_item(brand='Mercedes-Benz', model='CLA', line=''),
        )
        self.assertEqual(result['score'], 0)
        self.assertFalse(result['structural_met'])

    def test_spark_gt_does_not_match_chevrolet_onix(self):
        result = self._score(
            _vehicle_need(),
            _vehicle_item(model='Onix', line=''),
        )
        self.assertEqual(result['score'], 0)
        self.assertFalse(result['structural_met'])

    def test_spark_gt_matches_compatible_inventory(self):
        result = self._score(
            _vehicle_need(),
            _vehicle_item(),
        )
        self.assertTrue(result['structural_met'])
        self.assertTrue(result['required_met'])
        self.assertGreater(result['score'], 0)

    def test_secondary_attrs_alone_do_not_create_match(self):
        result = self._score(
            _vehicle_need(brand='Chevrolet', model='Spark', line='GT'),
            _vehicle_item(
                brand='Mercedes-Benz',
                model='CLA',
                line='',
                fuel_type='Gasolina',
                transmission='Automática',
            ),
            criteria=[
                SimpleNamespace(attribute='fuel_type', mode='PREFERRED', weight=10),
                SimpleNamespace(attribute='transmission', mode='PREFERRED', weight=10),
            ],
        )
        self.assertEqual(result['score'], 0)
        self.assertFalse(result['structural_met'])

    def test_property_listing_intent_mismatch_blocks_match(self):
        need = SimpleNamespace(
            asset_type=AssetType.PROPERTY,
            budget_max_cop=Decimal('300000000'),
        )
        item = SimpleNamespace(price_cop=Decimal('250000000'))
        need_d = SimpleNamespace(property_type='APTO', listing_intent='SALE')
        item_d = SimpleNamespace(property_type='APTO', listing_intent='RENT')
        result = score_pair(need, need_d, [], item, item_d, distance_km=2)
        self.assertEqual(result['score'], 0)
        self.assertFalse(result['structural_met'])
