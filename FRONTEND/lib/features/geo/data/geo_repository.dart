import '../../../core/network/api_client.dart';
import '../models/geo_models.dart';

class GeoRepository {
  GeoRepository(this._api);

  final ApiClient _api;

  Future<List<GeoDepartment>> departments({String? search}) async {
    final data = await _api.get(
      '/geo/departments/',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = data['results'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => GeoDepartment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<GeoCity>> cities({
    String? departmentId,
    String? departmentName,
    String? search,
  }) async {
    final data = await _api.get(
      '/geo/cities/',
      query: {
        if (departmentId != null && departmentId.isNotEmpty) 'department_id': departmentId,
        if (departmentName != null && departmentName.isNotEmpty) 'department': departmentName,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = data['results'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => GeoCity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
