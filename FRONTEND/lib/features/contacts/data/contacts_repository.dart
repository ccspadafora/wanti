import '../../../core/network/api_client.dart';
import '../models/contact_unlock_model.dart';

class ContactsRepository {
  ContactsRepository(this._api);

  final ApiClient _api;

  Future<List<ContactUnlockModel>> listUnlocks({String role = 'buyer'}) async {
    final data = await _api.get(
      '/contacts/unlocks/',
      query: {'role': role},
    );
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => ContactUnlockModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ContactUnlockModel?> findUnlock(String unlockId, {String role = 'buyer'}) async {
    final all = await listUnlocks(role: role);
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

  Future<ContactUnlockModel> reportOutcome(String unlockId, String outcome) async {
    final data = await _api.post(
      '/contacts/unlocks/$unlockId/report-outcome/',
      body: {'outcome': outcome},
    );
    return ContactUnlockModel.fromJson(data);
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

  Future<void> createReview(
    String unlockId, {
    required int rating,
    String comment = '',
    List<String> tags = const [],
  }) async {
    await _api.post(
      '/contacts/unlocks/$unlockId/reviews/',
      body: {
        'rating': rating,
        'comment': comment,
        'tags': tags,
      },
    );
  }

  Future<List<({String code, String label})>> reviewTags({String? forRole}) async {
    final data = await _api.get(
      '/reviews/tags/',
      auth: false,
      query: {
        if (forRole != null) 'for_role': forRole,
      },
    );
    final list = data['results'] is List ? data['results'] as List : const [];
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return (
        code: (m['code'] ?? '').toString(),
        label: (m['label'] ?? m['code'] ?? '').toString(),
      );
    }).where((e) => e.code.isNotEmpty).toList();
  }
}
