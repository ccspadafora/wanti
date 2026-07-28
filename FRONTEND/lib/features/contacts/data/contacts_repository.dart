import '../../../core/network/api_client.dart';
import '../models/contact_unlock_model.dart';

class ContactsRepository {
  ContactsRepository(this._api);

  final ApiClient _api;

  Future<List<ContactUnlockModel>> listUnlocks() async {
    final data = await _api.get('/contacts/unlocks/');
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => ContactUnlockModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ContactUnlockModel?> findUnlock(String unlockId) async {
    final all = await listUnlocks();
    try {
      return all.firstWhere((e) => e.id == unlockId);
    } catch (_) {
      return null;
    }
  }

  Future<ContactUnlockModel?> findUnlockByMatch(String matchId) async {
    final all = await listUnlocks();
    try {
      return all.firstWhere((e) => e.matchId == matchId);
    } catch (_) {
      return null;
    }
  }

  Future<void> markWhatsappOpened(String unlockId) async {
    await _api.post('/contacts/unlocks/$unlockId/whatsapp-opened/');
  }

  Future<void> reportOutcome(String unlockId, String outcome) async {
    await _api.post(
      '/contacts/unlocks/$unlockId/report-outcome/',
      body: {'outcome': outcome},
    );
  }

  Future<void> createDispute(
    String unlockId, {
    required String reason,
    String details = '',
  }) async {
    await _api.post(
      '/contacts/unlocks/$unlockId/disputes/',
      body: {'reason': reason, 'description': details},
    );
  }
}
