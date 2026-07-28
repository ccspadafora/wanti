import 'preference_catalog.dart';

class NeedDraft {
  String assetType = 'VEHICLE';
  String vehicleCategory = 'CAR';
  String propertyType = 'APTO';
  String brand = '';
  String model = '';
  String line = '';
  String propertyTitle = '';
  double budgetMaxCop = 0;
  List<String> paymentTypes = ['CASH'];
  String tradeInDescription = '';
  String city = '';
  String description = '';
  bool legalAccepted = false;

  final Map<String, CriterionValue> criteria = {};

  bool get isVehicle => assetType == 'VEHICLE';
  bool get acceptsTradeIn => paymentTypes.contains('TRADE_IN');

  String get title {
    if (isVehicle) {
      final parts = [brand, model, line].where((e) => e.trim().isNotEmpty);
      return parts.join(' ').trim();
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
    final detail = <String, dynamic>{};
    if (isVehicle) {
      detail['vehicle_category'] = vehicleCategory;
      detail['brand'] = brand.trim();
      detail['model'] = model.trim();
      detail['line'] = line.trim();
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
          ? (isVehicle ? 'Necesidad de vehículo' : 'Necesidad de inmueble')
          : title,
      'description': description,
      'budget_max_cop': budgetMaxCop.toStringAsFixed(2),
      'payment_type': paymentTypes.isNotEmpty ? paymentTypes.first : 'CASH',
      'payment_types': paymentTypes,
      'trade_in_description': acceptsTradeIn ? tradeInDescription.trim() : '',
      'city': city,
      'location': {'latitude': latitude, 'longitude': longitude},
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
