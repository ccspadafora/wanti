import '../../../core/network/api_client.dart';
import '../models/inventory_item_model.dart';

class InventoryRepository {
  InventoryRepository(this._api);

  final ApiClient _api;

  Future<List<InventoryItemModel>> listMine({String? assetType}) async {
    final data = await _api.get(
      '/inventory/',
      query: {
        if (assetType != null) 'asset_type': assetType,
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
}
