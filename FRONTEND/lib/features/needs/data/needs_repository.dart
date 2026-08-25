import '../../../core/network/api_client.dart';
import '../models/need_model.dart';

class NeedsRepository {
  NeedsRepository(this._api);

  final ApiClient _api;

  Future<List<NeedModel>> listMine({String? assetType}) async {
    final data = await _api.get('/needs/');
    final items = data['results'] is List ? data['results'] as List : const [];
    var needs = items
        .whereType<Map>()
        .map((e) => NeedModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (assetType != null) {
      needs = needs.where((n) => n.assetType == assetType).toList();
    }
    return needs
        .where((n) => n.status == 'ACTIVE' || n.status == 'PAUSED' || n.status == 'DRAFT')
        .toList();
  }

  Future<List<NeedModel>> browse({
    String? assetType,
    String? city,
    String? brand,
    String? model,
    int? year,
    String? vehicleCategory,
    String? fuelType,
    String? transmission,
    String? propertyType,
    double? maxBudget,
  }) async {
    return search(
      assetType: assetType,
      city: city,
      brand: brand,
      model: model,
      year: year,
      vehicleCategory: vehicleCategory,
      fuelType: fuelType,
      transmission: transmission,
      propertyType: propertyType,
      maxBudget: maxBudget,
    );
  }

  /// Structured manual search — metadata only, independent from viewer inventory.
  Future<List<NeedModel>> search({
    String? assetType,
    String? city,
    String? brand,
    String? model,
    int? year,
    String? vehicleCategory,
    String? fuelType,
    String? transmission,
    String? propertyType,
    String? listingIntent,
    int? bedroomsMin,
    int? bathroomsMin,
    int? areaMinSqm,
    int? socioeconomicStratum,
    int? parkingSpotsMin,
    double? maxBudget,
  }) async {
    final data = await _api.get(
      '/needs/search/',
      query: {
        if (assetType != null && assetType.isNotEmpty) 'asset_type': assetType,
        if (city != null && city.isNotEmpty) 'city': city,
        if (brand != null && brand.isNotEmpty) 'brand': brand,
        if (model != null && model.isNotEmpty) 'model': model,
        if (year != null) 'year': '$year',
        if (vehicleCategory != null && vehicleCategory.isNotEmpty)
          'vehicle_category': vehicleCategory,
        if (fuelType != null && fuelType.isNotEmpty) 'fuel_type': fuelType,
        if (transmission != null && transmission.isNotEmpty) 'transmission': transmission,
        if (propertyType != null && propertyType.isNotEmpty) 'property_type': propertyType,
        if (listingIntent != null && listingIntent.isNotEmpty) 'listing_intent': listingIntent,
        if (bedroomsMin != null) 'bedrooms_min': '$bedroomsMin',
        if (bathroomsMin != null) 'bathrooms_min': '$bathroomsMin',
        if (areaMinSqm != null) 'area_min_sqm': '$areaMinSqm',
        if (socioeconomicStratum != null) 'socioeconomic_stratum': '$socioeconomicStratum',
        if (parkingSpotsMin != null) 'parking_spots_min': '$parkingSpotsMin',
        if (maxBudget != null && maxBudget > 0) 'max_budget': maxBudget.toStringAsFixed(2),
      },
    );
    final items = data['results'] is List ? data['results'] as List : const [];
    return items
        .whereType<Map>()
        .map((e) => NeedModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<NeedModel> detail(String id) async {
    final data = await _api.get('/needs/$id/');
    return NeedModel.fromJson(data);
  }

  Future<NeedModel> create(Map<String, dynamic> payload) async {
    final data = await _api.post('/needs/', body: payload);
    return NeedModel.fromJson(data);
  }

  Future<NeedModel> publish(String id, {bool legalAccepted = true}) async {
    final data = await _api.post(
      '/needs/$id/publish/',
      body: {'legal_accepted': legalAccepted},
    );
    return NeedModel.fromJson(data);
  }

  Future<NeedModel> renew(String id) async {
    final data = await _api.post('/needs/$id/renew/');
    return NeedModel.fromJson(data);
  }

  Future<NeedModel> pause(String id) async {
    final data = await _api.post('/needs/$id/pause/');
    return NeedModel.fromJson(data);
  }

  Future<NeedModel> resume(String id) async {
    final data = await _api.post('/needs/$id/resume/');
    return NeedModel.fromJson(data);
  }

  Future<NeedModel> update(String id, Map<String, dynamic> payload) async {
    final data = await _api.patch('/needs/$id/', body: payload);
    return NeedModel.fromJson(data);
  }
}
