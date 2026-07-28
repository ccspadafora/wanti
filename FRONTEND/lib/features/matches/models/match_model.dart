class PartyUser {
  PartyUser({
    required this.id,
    required this.fullName,
    this.ratingAverage,
    this.isNewUser = false,
    this.phone,
  });

  final String id;
  final String fullName;
  final double? ratingAverage;
  final bool isNewUser;
  final String? phone;

  factory PartyUser.fromJson(Map<String, dynamic> json) {
    return PartyUser(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      ratingAverage: double.tryParse(json['rating_average']?.toString() ?? ''),
      isNewUser: json['is_new_user'] == true,
      phone: json['phone']?.toString(),
    );
  }
}

class MatchModel {
  MatchModel({
    required this.id,
    required this.score,
    required this.status,
    required this.alreadyUnlocked,
    required this.unlockCostWantis,
    this.needId,
    this.inventoryItemId,
    this.needTitle,
    this.needBudget,
    this.needCity,
    this.itemTitle,
    this.itemPrice,
    this.itemCity,
    this.itemMileage,
    this.itemFuel,
    this.itemTransmission,
    this.itemTraction,
    this.seller,
    this.buyer,
    this.unmetPreferences = const [],
    this.createdAt,
    this.assetType = 'VEHICLE',
    this.propertySummary,
    this.unlockId,
    this.sellerPhone,
    this.itemDescription,
    this.itemYear,
    this.itemColor,
  });

  final String id;
  final int score;
  final String status;
  final bool alreadyUnlocked;
  final int unlockCostWantis;
  final String? needId;
  final String? inventoryItemId;
  final String? needTitle;
  final double? needBudget;
  final String? needCity;
  final String? itemTitle;
  final double? itemPrice;
  final String? itemCity;
  final int? itemMileage;
  final String? itemFuel;
  final String? itemTransmission;
  final String? itemTraction;
  final PartyUser? seller;
  final PartyUser? buyer;
  final List<String> unmetPreferences;
  final DateTime? createdAt;
  final String assetType;
  final String? propertySummary;
  final String? unlockId;
  final String? sellerPhone;
  final String? itemDescription;
  final int? itemYear;
  final String? itemColor;

  bool get isHighMatch => score >= 85;

  List<String> get buyerMatchTags {
    final tags = <String>[];
    if (assetType == 'PROPERTY') {
      if (propertySummary != null && propertySummary!.isNotEmpty) {
        tags.addAll(propertySummary!.split(' · ').where((e) => e.trim().isNotEmpty));
      }
    } else {
      if (itemFuel != null && itemFuel!.isNotEmpty) tags.add(itemFuel!);
      if (itemTransmission != null && itemTransmission!.isNotEmpty) tags.add(itemTransmission!);
      if (itemTraction != null && itemTraction!.isNotEmpty) tags.add(itemTraction!);
    }
    return tags.take(4).toList();
  }

  List<String> get sellerAlertTags {
    final tags = <String>[...buyerMatchTags];
    if (needBudget != null) tags.add('< ${formatBudgetTag(needBudget!)}');
    if (needCity != null && needCity!.isNotEmpty && !tags.contains(needCity)) {
      tags.add(needCity!);
    }
    return tags.take(4).toList();
  }

  List<String> get tags => buyerMatchTags;

  static String formatBudgetTag(double value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      final f = m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
      return '\$${f}M';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final need = json['need'] is Map ? Map<String, dynamic>.from(json['need'] as Map) : null;
    final item = json['inventory_item'] is Map
        ? Map<String, dynamic>.from(json['inventory_item'] as Map)
        : null;
    final vehicle = item?['vehicle'] is Map
        ? Map<String, dynamic>.from(item!['vehicle'] as Map)
        : null;
    final property = item?['property'] is Map
        ? Map<String, dynamic>.from(item!['property'] as Map)
        : null;

    String? propertySummary;
    if (property != null) {
      final parts = <String>[];
      if (property['bedrooms'] != null) parts.add('${property['bedrooms']} hab');
      if (property['bathrooms'] != null) parts.add('${property['bathrooms']} baños');
      if (property['area_sqm'] != null) parts.add('${property['area_sqm']} m²');
      propertySummary = parts.join(' · ');
    }

    return MatchModel(
      id: json['id']?.toString() ?? '',
      score: int.tryParse(json['score']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'GENERATED',
      alreadyUnlocked: json['already_unlocked'] == true,
      unlockCostWantis: int.tryParse(json['unlock_cost_wantis']?.toString() ?? '1') ?? 1,
      needId: json['need_id']?.toString() ?? need?['id']?.toString(),
      inventoryItemId: json['inventory_item_id']?.toString() ?? item?['id']?.toString(),
      needTitle: need?['title']?.toString(),
      needBudget: double.tryParse(need?['budget_max_cop']?.toString() ?? ''),
      needCity: need?['city']?.toString(),
      itemTitle: item?['title']?.toString(),
      itemPrice: double.tryParse(item?['price_cop']?.toString() ?? ''),
      itemCity: item?['city']?.toString(),
      itemMileage: int.tryParse(vehicle?['mileage_km']?.toString() ?? ''),
      itemFuel: vehicle?['fuel_type']?.toString(),
      itemTransmission: vehicle?['transmission']?.toString(),
      itemTraction: vehicle?['traction']?.toString(),
      seller: json['seller'] is Map
          ? PartyUser.fromJson(Map<String, dynamic>.from(json['seller'] as Map))
          : null,
      buyer: json['buyer'] is Map
          ? PartyUser.fromJson(Map<String, dynamic>.from(json['buyer'] as Map))
          : null,
      unmetPreferences: (json['unmet_preferences'] is List)
          ? (json['unmet_preferences'] as List).map((e) => e.toString()).toList()
          : const [],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      assetType: vehicle != null
          ? 'VEHICLE'
          : property != null
              ? 'PROPERTY'
              : 'VEHICLE',
      propertySummary: propertySummary,
      unlockId: json['unlock_id']?.toString(),
      sellerPhone: json['seller_phone']?.toString(),
      itemDescription: item?['description']?.toString(),
      itemYear: int.tryParse(vehicle?['year']?.toString() ?? ''),
      itemColor: vehicle?['color']?.toString(),
    );
  }
}
