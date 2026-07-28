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
}
