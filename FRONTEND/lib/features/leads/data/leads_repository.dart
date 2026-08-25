import '../../../core/network/api_client.dart';
import '../models/lead_model.dart';

class LeadsRepository {
  LeadsRepository(this._api);

  final ApiClient _api;

  Future<List<LeadModel>> list({String? stage, String? q}) async {
    final data = await _api.get(
      '/leads/',
      query: {
        if (stage != null && stage != 'ALL') 'stage': stage,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => LeadModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<LeadModel> detail(String id) async {
    final data = await _api.get('/leads/$id/');
    return LeadModel.fromJson(data);
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

  Future<LeadNoteModel> addNote(String id, String text) async {
    final data = await _api.post('/leads/$id/notes/', body: {'text': text});
    return LeadNoteModel.fromJson(data);
  }

  Future<List<LeadNoteModel>> listNotes(String id) async {
    final lead = await detail(id);
    return lead.notes;
  }
}
