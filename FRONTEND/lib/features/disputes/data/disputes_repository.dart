import '../../../core/network/api_client.dart';
import '../dispute_reasons.dart';

class DisputeModel {
  DisputeModel({
    required this.id,
    required this.status,
    required this.reason,
    this.reasonLabel,
    this.openedById,
    this.openedByName,
    this.contactUnlockId,
    this.buyerId,
    this.sellerId,
    this.description,
    this.createdAt,
    this.resolutionNote,
    this.buyerConfirmedPurchase,
  });

  final String id;
  final String status;
  final String reason;
  final String? reasonLabel;
  final String? openedById;
  final String? openedByName;
  final String? contactUnlockId;
  final String? buyerId;
  final String? sellerId;
  final String? description;
  final DateTime? createdAt;
  final String? resolutionNote;
  final bool? buyerConfirmedPurchase;

  String get displayReason => reasonLabel ?? DisputeReasons.labelFor(reason);

  String get statusLabel {
    switch (status) {
      case 'OPEN':
        return 'Abierta';
      case 'AUTO_REVIEW':
        return 'Revisión automática';
      case 'HUMAN_REVIEW':
        return 'En revisión humana';
      case 'APPROVED':
      case 'RESOLVED_REFUND':
        return 'Aprobada · reembolso';
      case 'REJECTED':
      case 'RESOLVED_REJECTED':
        return 'Rechazada';
      case 'CANCELLED':
        return 'Cancelada';
      case 'APPEALED':
        return 'En apelación';
      default:
        return status;
    }
  }

  bool get isRejected => status == 'REJECTED' || status == 'RESOLVED_REJECTED';
  bool get isApproved => status == 'APPROVED' || status == 'RESOLVED_REFUND';
  bool get canAppeal => isRejected || isApproved;

  bool openedBy(String? userId) =>
      userId != null && openedById != null && openedById == userId;

  bool isBuyerParty(String? userId) =>
      userId != null && buyerId != null && buyerId == userId;

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    final opened = json['opened_by'] is Map
        ? Map<String, dynamic>.from(json['opened_by'] as Map)
        : null;
    return DisputeModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      reasonLabel: json['reason_label']?.toString(),
      openedById: opened?['id']?.toString(),
      openedByName: opened?['full_name']?.toString(),
      contactUnlockId: json['contact_unlock_id']?.toString(),
      buyerId: json['buyer_id']?.toString(),
      sellerId: json['seller_id']?.toString(),
      description: json['description']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      resolutionNote: json['resolution_note']?.toString(),
      buyerConfirmedPurchase: json['buyer_confirmed_purchase'] is bool
          ? json['buyer_confirmed_purchase'] as bool
          : null,
    );
  }
}

class DisputesRepository {
  DisputesRepository(this._api);

  final ApiClient _api;

  Future<List<DisputeModel>> list({String? status}) async {
    final data = await _api.get(
      '/disputes/',
      query: {
        if (status != null) 'status': status,
      },
    );
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map((e) => DisputeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DisputeModel> detail(String id) async {
    final data = await _api.get('/disputes/$id/');
    return DisputeModel.fromJson(data);
  }

  Future<void> cancel(String id) async {
    await _api.post('/disputes/$id/cancel/');
  }

  Future<void> appeal(String id, {String reason = ''}) async {
    await _api.post('/disputes/$id/appeal/', body: {'reason': reason});
  }

  Future<void> respondAuto(String id, {required bool confirmedPurchase}) async {
    await _api.post(
      '/disputes/$id/respond-auto/',
      body: {'confirmed_purchase': confirmedPurchase},
    );
  }
}
