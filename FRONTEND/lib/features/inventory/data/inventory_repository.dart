import '../../../core/network/api_client.dart';
import '../models/inventory_item_model.dart';

class InventoryRepository {
  InventoryRepository(this._api);

  final ApiClient _api;

  Future<List<InventoryItemModel>> listMine({
    String? assetType,
    String? status,
    String? brand,
    String? model,
    String? vehicleCategory,
    String? propertyType,
  }) async {
    final data = await _api.get(
      '/inventory/',
      query: {
        if (assetType != null) 'asset_type': assetType,
        if (status != null) 'status': status,
        if (brand != null && brand.isNotEmpty) 'brand': brand,
        if (model != null && model.isNotEmpty) 'model': model,
        if (vehicleCategory != null && vehicleCategory.isNotEmpty)
          'vehicle_category': vehicleCategory,
        if (propertyType != null && propertyType.isNotEmpty) 'property_type': propertyType,
      },
    );
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => InventoryItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<InventoryItemModel> create(Map<String, dynamic> payload) async {
    final data = await _api.post('/inventory/', body: payload);
    return InventoryItemModel.fromJson(data);
  }

  Future<void> markSold(String id) async {
    await _api.post('/inventory/$id/mark-sold/');
  }

  Future<InventoryItemModel> detail(String id) async {
    final data = await _api.get('/inventory/$id/');
    return InventoryItemModel.fromJson(data);
  }

  Future<InventoryItemModel> update(String id, Map<String, dynamic> payload) async {
    final data = await _api.patch('/inventory/$id/', body: payload);
    return InventoryItemModel.fromJson(data);
  }

  Future<void> reserve(String id) async {
    await _api.post('/inventory/$id/reserve/');
  }

  Future<void> reactivate(String id) async {
    await _api.post('/inventory/$id/reactivate/');
  }

  Future<void> delete(String id) async {
    await _api.delete('/inventory/$id/');
  }
}
