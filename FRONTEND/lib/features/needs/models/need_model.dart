class NeedModel {
  NeedModel({
    required this.id,
    required this.title,
    required this.assetType,
    required this.budgetMaxCop,
    required this.paymentType,
    required this.city,
    required this.status,
    required this.matchesCount,
    this.expiresAt,
    this.description,
    this.vehicle,
    this.canRenew = false,
  });

  final String id;
  final String title;
  final String assetType;
  final double budgetMaxCop;
  final String paymentType;
  final String city;
  final String status;
  final int matchesCount;
  final DateTime? expiresAt;
  final String? description;
  final Map<String, dynamic>? vehicle;
  final bool canRenew;

  int? get daysRemaining {
    if (expiresAt == null) return null;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isRenewable {
    if (canRenew) return true;
    final days = daysRemaining;
    if (days == null) return false;
    return status == 'ACTIVE' || status == 'PAUSED' ? days <= 5 : false;
  }

  factory NeedModel.fromJson(Map<String, dynamic> json) {
    DateTime? expires;
    final raw = json['expires_at'];
    if (raw != null) {
      expires = DateTime.tryParse(raw.toString());
    }
    return NeedModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      assetType: json['asset_type']?.toString() ?? 'VEHICLE',
      budgetMaxCop: double.tryParse(json['budget_max_cop']?.toString() ?? '') ?? 0,
      paymentType: json['payment_type']?.toString() ?? 'CASH',
      city: json['city']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      matchesCount: int.tryParse(json['matches_count']?.toString() ?? '0') ?? 0,
      expiresAt: expires,
      description: json['description']?.toString(),
      vehicle: json['vehicle'] is Map
          ? Map<String, dynamic>.from(json['vehicle'] as Map)
          : json['detail'] is Map
              ? Map<String, dynamic>.from(json['detail'] as Map)
              : null,
      canRenew: json['can_renew'] == true,
    );
  }
}
