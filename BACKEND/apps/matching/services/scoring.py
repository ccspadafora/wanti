from decimal import Decimal

from apps.common.constants import AssetType
from apps.common.services.settings_service import get_setting


def score_pair(
    need,
    need_vehicle_or_property,
    need_criteria,
    item,
    item_vehicle_or_property,
    distance_km,
) -> dict:
    structural_met, structural_results = _check_structural_gates(
        need.asset_type,
        need_vehicle_or_property,
        item_vehicle_or_property,
    )
    if not structural_met:
        return {
            'score': 0,
            'required_met': False,
            'structural_met': False,
            'unmet_preferences': [],
            'criteria_results': structural_results,
        }

    criteria_results = list(structural_results)
    unmet_preferences = []

    if item.price_cop > need.budget_max_cop:
        return {
            'score': 0,
            'required_met': False,
            'structural_met': True,
            'unmet_preferences': [],
            'criteria_results': criteria_results,
        }

    max_radius = float(get_setting('MATCH_RADIUS_KM', 50))
    city_compatible = _cities_compatible(need, item)
    if distance_km > max_radius and not city_compatible:
        return {
            'score': 0,
            'required_met': False,
            'structural_met': True,
            'unmet_preferences': [],
            'criteria_results': criteria_results,
        }

    min_ratio = Decimal(str(get_setting('MIN_BUDGET_RATIO', 0.40)))
    if item.price_cop < need.budget_max_cop * min_ratio:
        return {
            'score': 0,
            'required_met': False,
            'structural_met': True,
            'unmet_preferences': [],
            'criteria_results': criteria_results,
        }

    base = 100
    required_met = True

    for criterion in need_criteria:
        if criterion.attribute in _STRUCTURAL_ATTRIBUTES:
            continue
        expected = getattr(need_vehicle_or_property, criterion.attribute, None)
        actual_attr = _map_attribute(criterion.attribute)
        actual = getattr(item_vehicle_or_property, actual_attr, None)
        if actual is None:
            actual = getattr(item_vehicle_or_property, criterion.attribute, None)
        met = _evaluate_criterion(criterion.attribute, expected, actual)
        contribution = criterion.weight if met else 0
        criteria_results.append(
            {
                'attribute': criterion.attribute,
                'mode': criterion.mode,
                'expected_value': str(expected),
                'actual_value': str(actual),
                'met': met,
                'contribution': contribution,
            }
        )
        if not met:
            if criterion.mode == 'REQUIRED':
                required_met = False
                base = 0
                break
            base -= criterion.weight
            unmet_preferences.append(criterion.attribute)

    if not required_met:
        return {
            'score': 0,
            'required_met': False,
            'structural_met': True,
            'unmet_preferences': [],
            'criteria_results': criteria_results,
        }

    proximity_bonus = int((max_radius - float(distance_km)) / max_radius * 5)
    base = min(100, max(0, base + proximity_bonus))
    return {
        'score': base,
        'required_met': True,
        'structural_met': True,
        'unmet_preferences': unmet_preferences,
        'criteria_results': criteria_results,
    }


_STRUCTURAL_ATTRIBUTES = frozenset(
    {
        'vehicle_category',
        'brand',
        'model',
        'line',
        'year_min',
        'year_max',
        'property_type',
        'listing_intent',
    }
)


def _normalize_text(value) -> str:
    if value is None:
        return ''
    return ' '.join(str(value).strip().lower().split())


def _cities_compatible(need, item) -> bool:
    """True when inventory city matches need primary city or allowed travel cities."""
    item_city = _normalize_text(getattr(item, 'city', ''))
    if not item_city:
        return False
    if item_city == _normalize_text(getattr(need, 'city', '')):
        return True
    if not getattr(need, 'willing_to_travel', False):
        return False
    travel = getattr(need, 'travel_cities', None)
    if travel is None:
        return False
    try:
        names = {_normalize_text(c.name) for c in travel.all()}
    except Exception:
        return False
    return item_city in names


def _structural_result(attribute, expected, actual, met) -> dict:
    return {
        'attribute': attribute,
        'mode': 'REQUIRED',
        'expected_value': str(expected),
        'actual_value': str(actual),
        'met': met,
        'contribution': 30 if met else 0,
    }


def _check_structural_gates(asset_type, need_detail, item_detail) -> tuple[bool, list]:
    if need_detail is None or item_detail is None:
        return False, []

    results = []

    if asset_type == AssetType.VEHICLE:
        checks = (
            ('vehicle_category', need_detail.vehicle_category, item_detail.vehicle_category),
            ('brand', need_detail.brand, item_detail.brand),
            ('model', need_detail.model, item_detail.model),
        )
        for attribute, expected, actual in checks:
            if not expected or not str(expected).strip():
                continue
            met = _normalize_text(expected) == _normalize_text(actual)
            results.append(_structural_result(attribute, expected, actual, met))
            if not met:
                return False, results

        need_line = getattr(need_detail, 'line', '') or ''
        if need_line.strip():
            item_line = getattr(item_detail, 'line', '') or ''
            met = _normalize_text(need_line) == _normalize_text(item_line)
            results.append(_structural_result('line', need_line, item_line, met))
            if not met:
                return False, results

        year_min = getattr(need_detail, 'year_min', None)
        if year_min is not None:
            actual_year = getattr(item_detail, 'year', None)
            met = actual_year is not None and actual_year >= year_min
            results.append(_structural_result('year_min', year_min, actual_year, met))
            if not met:
                return False, results

        year_max = getattr(need_detail, 'year_max', None)
        if year_max is not None:
            actual_year = getattr(item_detail, 'year', None)
            met = actual_year is not None and actual_year <= year_max
            results.append(_structural_result('year_max', year_max, actual_year, met))
            if not met:
                return False, results

    elif asset_type == AssetType.PROPERTY:
        expected_type = getattr(need_detail, 'property_type', '') or ''
        if expected_type.strip():
            actual_type = getattr(item_detail, 'property_type', '') or ''
            met = _normalize_text(expected_type) == _normalize_text(actual_type)
            results.append(_structural_result('property_type', expected_type, actual_type, met))
            if not met:
                return False, results

        expected_intent = getattr(need_detail, 'listing_intent', '') or ''
        if expected_intent.strip():
            actual_intent = getattr(item_detail, 'listing_intent', '') or ''
            met = _normalize_text(expected_intent) == _normalize_text(actual_intent)
            results.append(
                _structural_result('listing_intent', expected_intent, actual_intent, met)
            )
            if not met:
                return False, results

    return True, results


def _map_attribute(attribute: str) -> str:
    mapping = {
        'mileage_max_km': 'mileage_km',
        'year_min': 'year',
        'year_max': 'year',
        'owners_max': 'owners_count',
        'area_min_sqm': 'area_sqm',
        'bedrooms_min': 'bedrooms',
        'bathrooms_min': 'bathrooms',
        'parking_spots_min': 'parking_spots',
        'floors_min': 'floors',
        'admin_fee_max_cop': 'admin_fee_cop',
        'utilities_max_cop': 'utilities_avg_cop',
        'required_utilities': 'available_utilities',
        'max_construction_age_years': 'construction_year',
        'engine_cc': 'engine_cc',
        'furnished': 'furnished',
        'social_amenities': 'social_amenities',
        'remodeling_features': 'remodeling_features',
    }
    return mapping.get(attribute, attribute)


def _evaluate_criterion(attribute, expected, actual):
    if expected is None or expected == '' or expected == []:
        return True
    if isinstance(expected, str) and expected.lower() in {'no interesa', 'sin restricción', 'sin restriccion'}:
        return True
    if actual is None:
        return True
    if attribute in {'has_elevator', 'furnished'}:
        expected_s = str(expected).strip().lower()
        if expected_s in {'no interesa', ''}:
            return True
        if isinstance(actual, bool):
            if expected_s in {'sí', 'si', 'true', '1'}:
                return actual is True
            if expected_s in {'no', 'false', '0'}:
                return actual is False
        return str(actual).strip().lower() == expected_s
    if attribute.endswith('_max_km') or attribute.endswith('_max_cop'):
        return actual <= expected
    if attribute.endswith('_min_sqm') or attribute.endswith('_min') or attribute == 'bedrooms_min':
        return actual >= expected
    if attribute == 'year_min':
        return actual >= expected
    if attribute == 'year_max':
        return actual <= expected
    if attribute == 'owners_max':
        return int(actual) <= int(expected)
    if attribute == 'engine_cc':
        return int(actual) <= int(expected)
    if attribute == 'floors_min':
        return int(actual) >= int(expected)
    if attribute in {'insurance_reports', 'social_amenities', 'remodeling_features', 'required_utilities'}:
        if not isinstance(expected, list):
            expected = [expected]
        if not isinstance(actual, list):
            actual = [actual] if actual else []
        if attribute == 'insurance_reports' and ('NONE' in expected or 'No acepta' in expected):
            return not actual
        if attribute == 'required_utilities':
            return set(str(x) for x in expected).issubset(set(str(x) for x in actual))
        return set(str(x) for x in expected).issubset(set(str(x) for x in actual))
    if attribute == 'plate_last_digit':
        expected_s = str(expected).strip().lower()
        if expected_s in {'sin restricción', 'sin restriccion', 'cualquiera', ''}:
            return True
        if expected_s in {'par', 'pares'}:
            return str(actual).isdigit() and int(actual) % 2 == 0
        if expected_s in {'impar', 'impares'}:
            return str(actual).isdigit() and int(actual) % 2 == 1
        return str(actual) == str(expected)
    if attribute == 'max_construction_age_years':
        from django.utils import timezone

        age = timezone.now().year - int(actual)
        return age <= int(expected)
    if attribute in {'brand', 'model', 'line', 'fuel_type', 'transmission', 'vehicle_category'}:
        return _normalize_text(expected) == _normalize_text(actual)
    if isinstance(expected, list):
        return actual in expected or set(str(x) for x in (actual if isinstance(actual, list) else [actual])).issubset(
            set(str(x) for x in expected)
        )
    return expected == actual
