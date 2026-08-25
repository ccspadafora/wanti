import '../../../core/network/api_client.dart';
import '../models/vehicle_catalog_models.dart';

class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

    Future<List<CatalogBrand>> brands({required String category, String? search}) async {
    final data = await _api.get(
      '/catalog/vehicle/brands/',
      query: {
        'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = data['results'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => CatalogBrand.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CatalogModel>> models({required String brandId, String? search}) async {
    final data = await _api.get(
      '/catalog/vehicle/models/',
      query: {
        'brand_id': brandId,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = data['results'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => CatalogModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CatalogYear>> years({required String modelId}) async {
    final data = await _api.get(
      '/catalog/vehicle/years/',
      query: {'model_id': modelId},
    );
    final list = data['results'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => CatalogYear.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CatalogVersion>> versions({
    required String modelId,
    required int year,
    String? search,
  }) async {
    final data = await _api.get(
      '/catalog/vehicle/versions/',
      query: {
        'model_id': modelId,
        'year': '$year',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = data['results'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => CatalogVersion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CatalogVersionSpecs> versionSpecs(String versionId) async {
    final data = await _api.get('/catalog/vehicle/versions/$versionId/specs/');
    return CatalogVersionSpecs.fromJson(Map<String, dynamic>.from(data));
  }
}
