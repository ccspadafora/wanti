import '../../../core/network/api_client.dart';
import '../models/lead_model.dart';

class LeadsRepository {
  LeadsRepository(this._api);

  final ApiClient _api;

  Future<List<LeadModel>> list({String? stage}) async {
    final data = await _api.get(
      '/leads/',
      query: {
        if (stage != null && stage != 'ALL') 'stage': stage,
      },
    );
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => LeadModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<LeadModel> changeStage(String id, String stage, {double? soldPrice}) async {
    final data = await _api.post(
      '/leads/$id/change-stage/',
      body: {
        'stage': stage,
        if (soldPrice != null) 'sold_price_cop': soldPrice,
      },
    );
    return LeadModel.fromJson(data);
  }

  Future<void> addNote(String id, String text) async {
    await _api.post('/leads/$id/notes/', body: {'text': text});
  }
}
