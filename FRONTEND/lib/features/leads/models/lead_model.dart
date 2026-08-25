class LeadNoteModel {
  LeadNoteModel({
    required this.id,
    required this.text,
    this.authorName,
    this.stageAtTime,
    this.createdAt,
  });

  final String id;
  final String text;
  final String? authorName;
  final String? stageAtTime;
  final DateTime? createdAt;

  factory LeadNoteModel.fromJson(Map<String, dynamic> json) {
    return LeadNoteModel(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      authorName: json['author_name']?.toString(),
      stageAtTime: json['stage_at_time']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class LeadModel {
  LeadModel({
    required this.id,
    required this.buyerName,
    required this.stage,
    required this.itemTitle,
    this.priceCop,
    this.lastActivityAt,
    this.notesCount = 0,
    this.latestNote,
    this.buyerPhone,
    this.buyerEmail,
    this.buyerRating,
    this.needTitle,
    this.needDescription,
    this.needCity,
    this.budgetMaxCop,
    this.score,
    this.matchId,
    this.unlockId,
    this.city,
    this.wantisCharged,
    this.soldPriceCop,
    this.canOpenDispute = true,
    this.notes = const [],
  });

  final String id;
  final String buyerName;
  final String stage;
  final String itemTitle;
  final double? priceCop;
  final DateTime? lastActivityAt;
  final int notesCount;
  final String? latestNote;
  final String? buyerPhone;
  final String? buyerEmail;
  final double? buyerRating;
  final String? needTitle;
  final String? needDescription;
  final String? needCity;
  final double? budgetMaxCop;
  final int? score;
  final String? matchId;
  final String? unlockId;
  final String? city;
  final int? wantisCharged;
  final double? soldPriceCop;
  final bool canOpenDispute;
  final List<LeadNoteModel> notes;

  String get stageLabel {
    switch (stage) {
      case 'NEW':
        return 'Nuevo';
      case 'IN_NEGOTIATION':
        return 'En negociación';
      case 'TO_VISIT':
        return 'Por visitar';
      case 'PURCHASED':
        return 'Comprado';
      case 'DISCARDED':
        return 'Descartado';
      case 'EXPIRED':
        return 'Caducado';
      default:
        return stage;
    }
  }

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    final buyer = json['buyer'] is Map
        ? Map<String, dynamic>.from(json['buyer'] as Map)
        : null;
    final unlock = json['contact_unlock'] is Map
        ? Map<String, dynamic>.from(json['contact_unlock'] as Map)
        : null;
    final notesRaw = json['notes'];
    final notes = notesRaw is List
        ? notesRaw
            .whereType<Map>()
            .map((e) => LeadNoteModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <LeadNoteModel>[];
    return LeadModel(
      id: json['id']?.toString() ?? '',
      buyerName: buyer?['full_name']?.toString() ?? 'Comprador',
      buyerPhone: buyer?['phone']?.toString(),
      buyerEmail: buyer?['email']?.toString(),
      buyerRating: double.tryParse(buyer?['rating_average']?.toString() ?? ''),
      stage: json['stage']?.toString() ?? 'NEW',
      itemTitle: unlock?['inventory_item_title']?.toString() ?? 'Publicación',
      priceCop: double.tryParse(unlock?['price_cop']?.toString() ?? ''),
      city: unlock?['city']?.toString(),
      needTitle: unlock?['need_title']?.toString(),
      needDescription: unlock?['need_description']?.toString(),
      needCity: unlock?['need_city']?.toString(),
      budgetMaxCop: double.tryParse(unlock?['budget_max_cop']?.toString() ?? ''),
      score: int.tryParse(unlock?['score']?.toString() ?? ''),
      matchId: unlock?['match_id']?.toString(),
      unlockId: unlock?['id']?.toString(),
      wantisCharged: int.tryParse(unlock?['wantis_charged']?.toString() ?? ''),
      lastActivityAt: DateTime.tryParse(json['last_activity_at']?.toString() ?? ''),
      notesCount: int.tryParse(json['notes_count']?.toString() ?? '0') ?? notes.length,
      soldPriceCop: double.tryParse(json['sold_price_cop']?.toString() ?? ''),
      canOpenDispute: unlock?['can_open_dispute'] != false,
      notes: notes,
    );
  }
}
