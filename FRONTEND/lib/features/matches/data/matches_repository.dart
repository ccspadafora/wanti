import '../../../core/network/api_client.dart';
import '../models/match_model.dart';

class UnlockResult {
  UnlockResult({
    required this.unlockId,
    required this.wantisCharged,
    this.sellerPhone,
  });

  final String unlockId;
  final int wantisCharged;
  final String? sellerPhone;
}

class MatchesRepository {
  MatchesRepository(this._api);

  final ApiClient _api;

  Future<List<MatchModel>> listBuyer({String? needId}) async {
    final data = await _api.get(
      '/matches/',
      query: {
        'role': 'buyer',
        if (needId != null) 'need_id': needId,
      },
    );
    return _parseList(data);
  }

  Future<List<MatchModel>> listSeller({String? inventoryItemId}) async {
    final data = await _api.get(
      '/matches/',
      query: {
        'role': 'seller',
        if (inventoryItemId != null) 'inventory_item_id': inventoryItemId,
      },
    );
    return _parseList(data);
  }

  Future<MatchModel> detail(String id) async {
    final data = await _api.get('/matches/$id/');
    return MatchModel.fromJson(data);
  }

  Future<UnlockResult> unlock(String id) async {
    final data = await _api.post('/matches/$id/unlock/');
    return UnlockResult(
      unlockId: data['unlock_id']?.toString() ?? '',
      wantisCharged: int.tryParse(data['wantis_charged']?.toString() ?? '1') ?? 1,
      sellerPhone: data['seller_phone']?.toString(),
    );
  }

  List<MatchModel> _parseList(Map<String, dynamic> data) {
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => MatchModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
