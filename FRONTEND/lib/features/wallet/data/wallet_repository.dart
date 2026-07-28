import '../../../core/network/api_client.dart';
import '../models/wallet_models.dart';

class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  Future<WalletBalance> balance() async {
    final data = await _api.get('/wallet/');
    return WalletBalance.fromJson(data);
  }

  Future<List<TopupPackage>> packages() async {
    final data = await _api.get('/wallet/packages/');
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => TopupPackage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<WalletTransaction>> transactions() async {
    final data = await _api.get('/wallet/transactions/');
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> topup(String packageId) async {
    return _api.post('/wallet/topups/', body: {'package_id': packageId});
  }
}
