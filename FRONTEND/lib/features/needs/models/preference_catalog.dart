enum PreferenceInputType { dropdown, multi, text, number, year }

class PreferenceFieldDef {
  const PreferenceFieldDef({
    required this.key,
    required this.label,
    required this.inputType,
    this.options = const [],
    this.hint = '',
    this.categories,
    this.allowOther = false,
    this.core = false,
    this.defaultRequired = false,
  });

  final String key;
  final String label;
  final PreferenceInputType inputType;
  final List<String> options;
  final String hint;
  /// null = all vehicle categories; otherwise subset of MOTO/CAR/OTHER
  final Set<String>? categories;
  final bool allowOther;
  final bool core;
  final bool defaultRequired;

  bool appliesTo(String category) {
    if (categories == null) return true;
    return categories!.contains(category);
  }
}

class PreferenceCatalog {
  PreferenceCatalog._();

  static const vehicleCategories = [
    ('MOTO', 'Moto'),
    ('CAR', 'Automóvil / Camioneta'),
    ('OTHER', 'Otros vehículos'),
  ];

  static const paymentOptions = [
    ('CASH', 'Efectivo'),
    ('TRANSFER', 'Transferencia'),
    ('CREDIT', 'Crédito'),
    ('MORTGAGE', 'Crédito hipotecario'),
    ('TRADE_IN', 'Permuta'),
  ];

  static const propertyPaymentOptions = [
    ('CASH', 'Efectivo'),
    ('MORTGAGE', 'Crédito hipotecario'),
    ('CREDIT', 'Crédito'),
    ('TRADE_IN', 'Permuta'),
  ];

  static const carBrands = [
    'Toyota',
    'Chevrolet',
    'Mazda',
    'Renault',
    'Kia',
    'Hyundai',
    'Nissan',
    'Ford',
    'Volkswagen',
    'Suzuki',
    'Honda',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Jeep',
  ];

  static const motoBrands = [
    'Yamaha',
    'Honda',
    'Suzuki',
    'Bajaj',
    'AKT',
    'Kawasaki',
    'BMW',
    'Hero',
    'TVS',
    'Auteco',
  ];

  static List<String> brandsFor(String category) {
    if (category == 'MOTO') return motoBrands;
    return carBrands;
  }

  static List<String> get years {
    final now = DateTime.now().year;
    return [for (var y = now + 1; y >= 2000; y--) '$y'];
  }

  static const vehiclePreferenceFields = <PreferenceFieldDef>[
    PreferenceFieldDef(
      key: 'year_min',
      label: 'Año (desde)',
      inputType: PreferenceInputType.year,
      defaultRequired: true,
    ),
    PreferenceFieldDef(
      key: 'color',
      label: 'Color',
      inputType: PreferenceInputType.dropdown,
      options: [
        'Blanco',
        'Negro',
        'Gris',
        'Plata',
        'Rojo',
        'Azul',
        'Verde',
        'Beige',
        'Multicolor',
      ],
    ),
    PreferenceFieldDef(
      key: 'engine_cc',
      label: 'Cilindraje máximo (cc)',
      inputType: PreferenceInputType.number,
      hint: 'Ej. 1600',
    ),
    PreferenceFieldDef(
      key: 'fuel_type',
      label: 'Combustible',
      inputType: PreferenceInputType.dropdown,
      options: ['Gasolina', 'Diésel', 'Eléctrico', 'Híbrido'],
      defaultRequired: true,
    ),
    PreferenceFieldDef(
      key: 'mileage_max_km',
      label: 'Kilometraje máximo',
      inputType: PreferenceInputType.number,
      hint: 'Ej. 80000',
    ),
    PreferenceFieldDef(
      key: 'body_type',
      label: 'Carrocería',
      inputType: PreferenceInputType.dropdown,
      options: ['Hatchback', 'Sedán', 'Pick-up', 'SUV', 'Coupé', 'Van', 'Camioneta'],
      categories: {'CAR', 'OTHER'},
    ),
    PreferenceFieldDef(
      key: 'traction',
      label: 'Tracción',
      inputType: PreferenceInputType.dropdown,
      options: ['4x4', '4x2', 'AWD'],
      categories: {'CAR', 'OTHER'},
    ),
    PreferenceFieldDef(
      key: 'doors',
      label: 'Puertas',
      inputType: PreferenceInputType.dropdown,
      options: ['2', '3', '4', '5'],
      categories: {'CAR', 'OTHER'},
    ),
    PreferenceFieldDef(
      key: 'transmission',
      label: 'Transmisión',
      inputType: PreferenceInputType.dropdown,
      options: ['Mecánica', 'Automática', 'Semi-automática'],
      categories: {'CAR', 'OTHER'},
    ),
    PreferenceFieldDef(
      key: 'steering',
      label: 'Dirección',
      inputType: PreferenceInputType.dropdown,
      options: ['Hidráulica', 'Mecánica', 'Eléctrica'],
      categories: {'CAR', 'OTHER'},
    ),
    PreferenceFieldDef(
      key: 'plate_last_digit',
      label: 'Último dígito de placa',
      inputType: PreferenceInputType.dropdown,
      options: ['Sin restricción', 'Par', 'Impar', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
    ),
    PreferenceFieldDef(
      key: 'owners_max',
      label: 'Dueños máximos aceptados',
      inputType: PreferenceInputType.dropdown,
      options: ['1', '2', '3', '4', '5'],
    ),
    PreferenceFieldDef(
      key: 'insurance_reports',
      label: 'Reportes de aseguradora',
      inputType: PreferenceInputType.multi,
      options: ['No acepta', 'Menor cuantía', 'Mayor cuantía'],
    ),
  ];

  static const propertyTypes = [
    ('APTO', 'Apartamento'),
    ('CASA', 'Casa'),
    ('LOTE_FINCA', 'Lote / Finca'),
    ('LOCAL', 'Local'),
    ('BODEGA', 'Bodega'),
    ('CONSULTORIO', 'Consultorio'),
  ];

  static const _aptoCasa = {'APTO', 'CASA'};
  static const _aptoCasaLocalBodegaConsultorio = {
    'APTO',
    'CASA',
    'LOCAL',
    'BODEGA',
    'CONSULTORIO',
  };
  static const _aptoCasaLocalConsultorio = {'APTO', 'CASA', 'LOCAL', 'CONSULTORIO'};
  static const _aptoCasaConsultorio = {'APTO', 'CASA', 'CONSULTORIO'};
  static const _casaLocalBodega = {'CASA', 'LOCAL', 'BODEGA'};
  static const _loteBodega = {'LOTE_FINCA', 'BODEGA'};
  static const _aptoCasaLote = {'APTO', 'CASA', 'LOTE_FINCA'};
  static const _remodelacion = {'APTO', 'CASA', 'LOCAL', 'BODEGA', 'CONSULTORIO'};

  static const propertyPreferenceFields = <PreferenceFieldDef>[
    PreferenceFieldDef(
      key: 'urbanization_type',
      label: 'Tipo de ubicación',
      inputType: PreferenceInputType.dropdown,
      options: ['Conjunto cerrado', 'Condominio', 'Barrio'],
      defaultRequired: true,
    ),
    PreferenceFieldDef(
      key: 'listing_intent',
      label: 'Arriendo / venta',
      inputType: PreferenceInputType.dropdown,
      options: ['Venta', 'Arriendo'],
      defaultRequired: true,
    ),
    PreferenceFieldDef(
      key: 'area_min_sqm',
      label: 'Metros cuadrados (mín.)',
      inputType: PreferenceInputType.number,
      hint: 'Ej. 80',
      defaultRequired: true,
    ),
    PreferenceFieldDef(
      key: 'bedrooms_min',
      label: 'Número de habitaciones',
      inputType: PreferenceInputType.dropdown,
      options: ['1', '2', '3', '4', '5', '6'],
      categories: _aptoCasa,
    ),
    PreferenceFieldDef(
      key: 'bathrooms_min',
      label: 'Baños',
      inputType: PreferenceInputType.dropdown,
      options: ['1', '2', '3', '4', '5'],
      categories: _aptoCasaLocalBodegaConsultorio,
    ),
    PreferenceFieldDef(
      key: 'required_utilities',
      label: 'Servicios',
      inputType: PreferenceInputType.multi,
      options: ['Agua', 'Luz', 'Gas', 'Internet'],
      categories: _loteBodega,
    ),
    PreferenceFieldDef(
      key: 'social_amenities',
      label: 'Zonas sociales',
      inputType: PreferenceInputType.multi,
      options: ['Piscina', 'Gym', 'Juegos'],
      categories: _aptoCasa,
    ),
    PreferenceFieldDef(
      key: 'parking_type',
      label: 'Parqueadero (tipo)',
      inputType: PreferenceInputType.dropdown,
      options: ['Comunal', 'Propio'],
      categories: _aptoCasaLocalConsultorio,
    ),
    PreferenceFieldDef(
      key: 'parking_spots_min',
      label: 'Parqueaderos (número)',
      inputType: PreferenceInputType.dropdown,
      options: ['1', '2', '3', '4'],
      categories: _aptoCasaLocalConsultorio,
    ),
    PreferenceFieldDef(
      key: 'max_construction_age_years',
      label: 'Tiempo de construcción máx. (años)',
      inputType: PreferenceInputType.number,
      hint: 'Solo número, ej. 10',
      categories: _aptoCasaLocalBodegaConsultorio,
    ),
    PreferenceFieldDef(
      key: 'floors_min',
      label: 'Número de pisos',
      inputType: PreferenceInputType.dropdown,
      options: ['1', '2', '3', '4', '5'],
      categories: _casaLocalBodega,
    ),
    PreferenceFieldDef(
      key: 'has_elevator',
      label: 'Ascensor',
      inputType: PreferenceInputType.dropdown,
      options: ['Sí', 'No', 'No interesa'],
      categories: {'APTO'},
    ),
    PreferenceFieldDef(
      key: 'furnished',
      label: 'Amoblado',
      inputType: PreferenceInputType.dropdown,
      options: ['Sí', 'No', 'No interesa'],
      categories: _aptoCasaConsultorio,
    ),
    PreferenceFieldDef(
      key: 'condition',
      label: 'Condición',
      inputType: PreferenceInputType.dropdown,
      options: ['Nuevo', 'Usso'],
      categories: _aptoCasaLocalBodegaConsultorio,
    ),
    PreferenceFieldDef(
      key: 'socioeconomic_stratum',
      label: 'Estrato',
      inputType: PreferenceInputType.dropdown,
      options: ['1', '2', '3', '4', '5', '6'],
      categories: _aptoCasaLocalConsultorio,
    ),
    PreferenceFieldDef(
      key: 'style',
      label: 'Estilo',
      inputType: PreferenceInputType.dropdown,
      options: [
        'Penthouse',
        'Dúplex',
        'Campestre',
        'Conjunto cerrado',
        'Condominio',
      ],
      categories: _aptoCasaLote,
    ),
    PreferenceFieldDef(
      key: 'remodeling_features',
      label: 'Remodelación / accesorios',
      inputType: PreferenceInputType.multi,
      options: [
        'Aire acondicionado',
        'Cocina integral',
        'Closet',
        'Calentador',
        'Calefacción',
      ],
      categories: _remodelacion,
    ),
  ];

  static List<PreferenceFieldDef> vehicleFieldsFor(String category) {
    return vehiclePreferenceFields.where((f) => f.appliesTo(category)).toList();
  }

  static List<PreferenceFieldDef> propertyFieldsFor(String propertyType) {
    return propertyPreferenceFields.where((f) => f.appliesTo(propertyType)).toList();
  }

  static String propertyTypeLabel(String code) {
    for (final t in propertyTypes) {
      if (t.$1 == code) return t.$2;
    }
    return code;
  }

  static dynamic coerceValue(PreferenceFieldDef field, dynamic raw) {
    if (raw == null) return null;
    if (field.inputType == PreferenceInputType.multi) {
      if (raw is List) return raw;
      return <String>[];
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (field.key == 'has_elevator' || field.key == 'furnished') {
      if (s == 'No interesa') return null;
      return s;
    }
    if (field.key == 'listing_intent') {
      if (s == 'Venta') return 'SALE';
      if (s == 'Arriendo') return 'RENT';
      return s;
    }
    if (field.inputType == PreferenceInputType.number ||
        field.inputType == PreferenceInputType.year ||
        field.key == 'doors' ||
        field.key == 'owners_max' ||
        field.key == 'bedrooms_min' ||
        field.key == 'bathrooms_min' ||
        field.key == 'parking_spots_min' ||
        field.key == 'socioeconomic_stratum' ||
        field.key == 'max_construction_age_years' ||
        field.key == 'area_min_sqm' ||
        field.key == 'floors_min' ||
        field.key == 'engine_cc' ||
        field.key == 'mileage_max_km' ||
        field.key == 'year_min') {
      return int.tryParse(s.replaceAll(RegExp(r'[^\d]'), ''));
    }
    return s;
  }

  static String displayOf(PreferenceFieldDef field, dynamic value) {
    if (value == null) return 'Sin definir';
    if (value is List) {
      if (value.isEmpty) return 'Sin definir';
      return value.join(', ');
    }
    if (value is bool) return value ? 'Sí' : 'No';
    if (field.key == 'listing_intent') {
      if (value == 'SALE') return 'Venta';
      if (value == 'RENT') return 'Arriendo';
    }
    if (field.key == 'mileage_max_km') return '< $value km';
    if (field.key == 'engine_cc') return '$value cc';
    if (field.key == 'area_min_sqm') return '≥ $value m²';
    if (field.key == 'owners_max') {
      return value == 1 ? 'Único dueño' : 'Hasta $value dueños';
    }
    return value.toString();
  }
}
