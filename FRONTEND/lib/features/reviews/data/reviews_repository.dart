import '../../../core/network/api_client.dart';

class ReviewDisputeInfo {
  ReviewDisputeInfo({
    required this.id,
    required this.status,
    this.reason,
    this.createdAt,
    this.resolvedAt,
    this.adminNote,
  });

  final String id;
  final String status;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? adminNote;

  String get statusLabel {
    switch (status) {
      case 'OPEN':
        return 'Impugnación en revisión';
      case 'RESOLVED_KEPT':
        return 'Resuelta: se mantiene la reseña';
      case 'RESOLVED_REMOVED':
        return 'Resuelta: reseña eliminada';
      default:
        return status;
    }
  }

  factory ReviewDisputeInfo.fromJson(Map<String, dynamic> json) {
    return ReviewDisputeInfo(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      reason: json['reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      resolvedAt: DateTime.tryParse(json['resolved_at']?.toString() ?? ''),
      adminNote: json['admin_note']?.toString(),
    );
  }
}

class ReviewModel {
  ReviewModel({
    required this.id,
    required this.rating,
    this.comment,
    this.otherName,
    this.tags = const [],
    this.createdAt,
    this.status = 'PUBLISHED',
    this.dispute,
  });

  final String id;
  final int rating;
  final String? comment;
  final String? otherName;
  final List<String> tags;
  final DateTime? createdAt;
  final String status;
  final ReviewDisputeInfo? dispute;

  bool get hasDispute => dispute != null;
  bool get canDispute => !hasDispute && status == 'PUBLISHED';

  String get statusLabel {
    switch (status) {
      case 'UNDER_REVIEW':
        return 'En revisión';
      case 'REMOVED':
        return 'Eliminada';
      case 'PUBLISHED':
        return 'Publicada';
      default:
        return status;
    }
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json, {required bool received}) {
    final other = received
        ? (json['reviewer'] is Map ? Map<String, dynamic>.from(json['reviewer'] as Map) : null)
        : (json['reviewee'] is Map ? Map<String, dynamic>.from(json['reviewee'] as Map) : null);
    final tagsRaw = json['tags'];
    final disputeRaw = json['dispute'];
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      rating: int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      comment: json['comment']?.toString(),
      otherName: other?['full_name']?.toString(),
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'PUBLISHED',
      dispute: disputeRaw is Map
          ? ReviewDisputeInfo.fromJson(Map<String, dynamic>.from(disputeRaw))
          : null,
    );
  }
}

class ReviewsRepository {
  ReviewsRepository(this._api);

  final ApiClient _api;

  Future<List<ReviewModel>> mine({String type = 'received'}) async {
    final data = await _api.get('/reviews/mine/', query: {'type': type});
    final list = data['results'] is List ? data['results'] as List : const [];
    return list
        .whereType<Map>()
        .map(
          (e) => ReviewModel.fromJson(
            Map<String, dynamic>.from(e),
            received: type == 'received',
          ),
        )
        .toList();
  }

  Future<void> disputeReview(String id, {required String reason}) async {
    await _api.post('/reviews/$id/dispute/', body: {'reason': reason});
  }
}
