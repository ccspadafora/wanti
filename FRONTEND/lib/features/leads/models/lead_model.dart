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
    return LeadModel(
      id: json['id']?.toString() ?? '',
      buyerName: buyer?['full_name']?.toString() ?? 'Comprador',
      buyerPhone: buyer?['phone']?.toString(),
      stage: json['stage']?.toString() ?? 'NEW',
      itemTitle: unlock?['inventory_item_title']?.toString() ?? 'Publicación',
      priceCop: double.tryParse(unlock?['price_cop']?.toString() ?? ''),
      lastActivityAt: DateTime.tryParse(json['last_activity_at']?.toString() ?? ''),
      notesCount: int.tryParse(json['notes_count']?.toString() ?? '0') ?? 0,
    );
  }
}
