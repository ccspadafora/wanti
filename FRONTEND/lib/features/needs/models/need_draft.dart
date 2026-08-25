import 'preference_catalog.dart';
import '../../catalog/models/vehicle_catalog_models.dart';

class NeedDraft {
  String assetType = 'VEHICLE';
  String vehicleCategory = 'CAR';
  String propertyType = 'APTO';
  String brand = '';
  String model = '';
  String line = '';
  int? year;
  String catalogVersionId = '';
  String propertyTitle = '';
  double budgetMaxCop = 0;
  List<String> paymentTypes = ['CASH'];
  String tradeInDescription = '';
  String? tradeInInventoryId;
  String? tradeInInventoryTitle;
  String city = '';
  String department = '';
  String geoCityId = '';
  double? latitude;
  double? longitude;
  bool willingToTravel = false;
  final List<({String id, String name, String department})> travelCities = [];
  String description = '';
  bool legalAccepted = false;
  CatalogVersionSpecs? versionSpecs;

  final Map<String, CriterionValue> criteria = {};

  bool get isVehicle => assetType == 'VEHICLE';
  bool get acceptsTradeIn => paymentTypes.contains('TRADE_IN');

  void applyVersionSpecs(CatalogVersionSpecs specs) {
    versionSpecs = specs;
    for (final entry in specs.defaults.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (criteria.containsKey(entry.key)) {
        setCriterionValue(entry.key, value);
      }
    }
  }

  List<String> optionsForCriterion(String key, List<String> fallback) {
    final specs = versionSpecs;
    if (specs == null) return fallback;
    return specs.optionsFor(key, fallback);
  }

  bool isCriterionLocked(String key) => versionSpecs?.isLocked(key) == true;

  String get title {
    if (isVehicle) {
      return vehicleListingTitle(
        brand: brand,
        model: model,
        version: line,
        year: year,
      );
    }
    if (propertyTitle.trim().isNotEmpty) return propertyTitle.trim();
    final type = PreferenceCatalog.propertyTypeLabel(propertyType);
    return type;
  }

  void syncVehicleCriteriaSlots() {
    final defs = PreferenceCatalog.vehicleFieldsFor(vehicleCategory);
    final keep = defs.map((d) => d.key).toSet();
    criteria.removeWhere((k, _) => !keep.contains(k));
    for (final def in defs) {
      criteria.putIfAbsent(
        def.key,
        () => CriterionValue(
          label: def.label,
          displayValue: 'Sin definir',
          value: null,
          required: def.defaultRequired,
          field: def,
        ),
      );
      criteria[def.key]!.field = def;
      criteria[def.key]!.label = def.label;
    }
  }

  void syncPropertyCriteriaSlots() {
    final defs = PreferenceCatalog.propertyFieldsFor(propertyType);
    final keep = defs.map((d) => d.key).toSet();
    criteria.removeWhere((k, _) => !keep.contains(k));
    for (final def in defs) {
      criteria.putIfAbsent(
        def.key,
        () => CriterionValue(
          label: def.label,
          displayValue: 'Sin definir',
          value: null,
          required: def.defaultRequired,
          field: def,
        ),
      );
      criteria[def.key]!.field = def;
      criteria[def.key]!.label = def.label;
    }
  }

  void setCriterionValue(String key, dynamic raw) {
    final current = criteria[key];
    if (current == null || current.field == null) return;
    final value = PreferenceCatalog.coerceValue(current.field!, raw);
    current
      ..value = value
      ..displayValue = PreferenceCatalog.displayOf(current.field!, value);
  }

  Map<String, dynamic> toCreatePayload({
    required double latitude,
    required double longitude,
  }) {
    final lat = this.latitude ?? latitude;
    final lng = this.longitude ?? longitude;
    final detail = <String, dynamic>{};
    if (isVehicle) {
      detail['vehicle_category'] = vehicleCategory;
      detail['brand'] = brand.trim();
      detail['model'] = model.trim();
      detail['line'] = line.trim();
      if (catalogVersionId.isNotEmpty) {
        detail['catalog_version_id'] = catalogVersionId;
      }
      if (year != null) {
        detail['year_min'] = year;
        detail['year_max'] = year;
      }
    } else {
      detail['property_type'] = propertyType;
    }

    for (final entry in criteria.entries) {
      final key = entry.key;
      final value = entry.value.value;
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      detail[key] = value;
      if (key == 'owners_max' && value is int) {
        detail['single_owner'] = value == 1;
      }
      if (key == 'social_amenities' && value is List) {
        detail['has_pool'] = value.contains('Piscina');
        detail['has_sports_courts'] = value.contains('Gym') || value.contains('Juegos');
        detail['has_social_area'] = value.isNotEmpty;
      }
    }

    return {
      'asset_type': assetType,
      'title': title.isEmpty
          ? (isVehicle ? 'Sueño de vehículo' : 'Sueño de inmueble')
          : title,
      'description': description,
      'budget_max_cop': budgetMaxCop.toStringAsFixed(2),
      'payment_type': paymentTypes.isNotEmpty ? paymentTypes.first : 'CASH',
      'payment_types': paymentTypes,
      'trade_in_description': acceptsTradeIn ? tradeInDescription.trim() : '',
      if (acceptsTradeIn && tradeInInventoryId != null)
        'trade_in_inventory_id': tradeInInventoryId,
      'city': city,
      'department': department,
      if (geoCityId.isNotEmpty) 'geo_city_id': geoCityId,
      'willing_to_travel': willingToTravel,
      'travel_city_ids': willingToTravel ? travelCities.map((e) => e.id).toList() : [],
      'location': {'latitude': lat, 'longitude': lng},
      'detail': detail,
      'criteria': criteria.entries
          .where((e) => e.value.value != null)
          .where((e) => !(e.value.value is String && (e.value.value as String).isEmpty))
          .where((e) => !(e.value.value is List && (e.value.value as List).isEmpty))
          .map(
            (e) => {
              'attribute': e.key,
              'mode': e.value.required ? 'REQUIRED' : 'PREFERRED',
              'weight': e.value.required ? 20 : 10,
            },
          )
          .toList(),
    };
  }
}

class CriterionValue {
  CriterionValue({
    required this.label,
    required this.displayValue,
    required this.value,
    this.required = false,
    this.field,
  });

  String label;
  String displayValue;
  dynamic value;
  bool required;
  PreferenceFieldDef? field;
}

Map<String, List<double>> get cityCoordinates => {
      'bogotá': [4.7110, -74.0721],
      'bogota': [4.7110, -74.0721],
      'medellín': [6.2476, -75.5658],
      'medellin': [6.2476, -75.5658],
      'cali': [3.4516, -76.5320],
      'barranquilla': [10.9685, -74.7813],
      'cartagena': [10.3910, -75.4794],
      'bucaramanga': [7.1193, -73.1227],
    };

List<double> coordsForCity(String city) {
  final key = city.trim().toLowerCase();
  return cityCoordinates[key] ?? [4.7110, -74.0721];
}
