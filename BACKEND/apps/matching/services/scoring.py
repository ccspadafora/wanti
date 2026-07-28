from decimal import Decimal

from apps.common.services.settings_service import get_setting


def score_pair(
    need,
    need_vehicle_or_property,
    need_criteria,
    item,
    item_vehicle_or_property,
    distance_km,
) -> dict:
    criteria_results = []
    unmet_preferences = []

    if item.price_cop > need.budget_max_cop:
        return {
            'score': 0,
            'required_met': False,
            'unmet_preferences': [],
            'criteria_results': [],
        }

    max_radius = float(get_setting('MATCH_RADIUS_KM', 50))
    if distance_km > max_radius:
        return {
            'score': 0,
            'required_met': False,
            'unmet_preferences': [],
            'criteria_results': [],
        }

    min_ratio = Decimal(str(get_setting('MIN_BUDGET_RATIO', 0.40)))
    if item.price_cop < need.budget_max_cop * min_ratio:
        return {
            'score': 0,
            'required_met': False,
            'unmet_preferences': [],
            'criteria_results': [],
        }

    base = 100
    required_met = True

    for criterion in need_criteria:
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
            'unmet_preferences': [],
            'criteria_results': criteria_results,
        }

    proximity_bonus = int((max_radius - float(distance_km)) / max_radius * 5)
    base = min(100, max(0, base + proximity_bonus))
    return {
        'score': base,
        'required_met': True,
        'unmet_preferences': unmet_preferences,
        'criteria_results': criteria_results,
    }


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
    if isinstance(expected, list):
        return actual in expected or set(str(x) for x in (actual if isinstance(actual, list) else [actual])).issubset(
            set(str(x) for x in expected)
        )
    return expected == actual
