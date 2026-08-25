class CatalogBrand {
  CatalogBrand({
    required this.id,
    required this.name,
    required this.category,
    required this.isPopular,
  });

  final String id;
  final String name;
  final String category;
  final bool isPopular;

  factory CatalogBrand.fromJson(Map<String, dynamic> json) => CatalogBrand(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'CAR',
        isPopular: json['is_popular'] == true,
      );
}

class CatalogModel {
  CatalogModel({
    required this.id,
    required this.name,
    required this.isPopular,
  });

  final String id;
  final String name;
  final bool isPopular;

  factory CatalogModel.fromJson(Map<String, dynamic> json) => CatalogModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        isPopular: json['is_popular'] == true,
      );
}

class CatalogYear {
  CatalogYear({
    required this.id,
    required this.year,
    required this.isPopular,
  });

  final String id;
  final int year;
  final bool isPopular;

  factory CatalogYear.fromJson(Map<String, dynamic> json) => CatalogYear(
        id: json['id'] as String,
        year: (json['year'] as num).toInt(),
        isPopular: json['is_popular'] == true,
      );
}

class CatalogVersion {
  CatalogVersion({
    required this.id,
    required this.name,
    required this.year,
    required this.brandName,
    required this.modelName,
  });

  final String id;
  final String name;
  final int year;
  final String brandName;
  final String modelName;

  factory CatalogVersion.fromJson(Map<String, dynamic> json) => CatalogVersion(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        year: (json['year'] as num?)?.toInt() ?? 0,
        brandName: json['brand_name'] as String? ?? '',
        modelName: json['model_name'] as String? ?? '',
      );
}

class CatalogVersionSpecs {
  CatalogVersionSpecs({
    required this.versionId,
    required this.versionName,
    required this.allowed,
    required this.locked,
    required this.defaults,
    this.source = 'inferred',
  });

  final String versionId;
  final String versionName;
  final Map<String, dynamic> allowed;
  final Map<String, bool> locked;
  final Map<String, dynamic> defaults;
  final String source;

  factory CatalogVersionSpecs.fromJson(Map<String, dynamic> json) => CatalogVersionSpecs(
        versionId: json['version_id']?.toString() ?? '',
        versionName: json['version_name']?.toString() ?? '',
        allowed: Map<String, dynamic>.from(json['allowed'] as Map? ?? {}),
        locked: {
          for (final e in Map<String, dynamic>.from(json['locked'] as Map? ?? {}).entries)
            e.key: e.value == true,
        },
        defaults: Map<String, dynamic>.from(json['defaults'] as Map? ?? {}),
        source: json['source']?.toString() ?? 'inferred',
      );

  List<String> optionsFor(String key, List<String> fallback) {
    final raw = allowed[key];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return fallback;
  }

  bool isLocked(String key) => locked[key] == true;
}

class VehicleCatalogSelection {
  String? category; // CAR | MOTO
  CatalogBrand? brand;
  CatalogModel? model;
  CatalogYear? year;
  CatalogVersion? version;

  bool get isComplete =>
      category != null &&
      brand != null &&
      model != null &&
      year != null &&
      version != null;

  /// Título canónico: marca + modelo + versión (referencia) + año.
  String get summaryLabel {
    if (!isComplete) return '';
    return vehicleListingTitle(
      brand: brand!.name,
      model: model!.name,
      version: version!.name,
      year: year!.year,
    );
  }

  void clearFrom(String step) {
    switch (step) {
      case 'category':
        brand = null;
        model = null;
        year = null;
        version = null;
      case 'brand':
        model = null;
        year = null;
        version = null;
      case 'model':
        year = null;
        version = null;
      case 'year':
        version = null;
    }
  }
}

String vehicleListingTitle({
  required String brand,
  required String model,
  required String version,
  int? year,
}) {
  return [
    brand,
    model,
    version,
    if (year != null && year > 0) '$year',
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');
}
