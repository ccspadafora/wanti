class ContactUnlockModel {
  ContactUnlockModel({
    required this.id,
    required this.wantisCharged,
    required this.outcome,
    this.matchId,
    this.score,
    this.sellerName,
    this.sellerPhone,
    this.sellerRating,
    this.sellerIsNew = false,
    this.itemTitle,
    this.itemPrice,
    this.itemCity,
    this.itemDescription,
    this.assetType = 'VEHICLE',
    this.vehicle,
    this.property,
    this.canOpenDispute = true,
  });

  final String id;
  final int wantisCharged;
  final String outcome;
  final String? matchId;
  final int? score;
  final String? sellerName;
  final String? sellerPhone;
  final double? sellerRating;
  final bool sellerIsNew;
  final String? itemTitle;
  final double? itemPrice;
  final String? itemCity;
  final String? itemDescription;
  final String assetType;
  final Map<String, dynamic>? vehicle;
  final Map<String, dynamic>? property;
  final bool canOpenDispute;

  List<String> get itemTags {
    final tags = <String>[];
    if (assetType == 'PROPERTY' && property != null) {
      if (property!['bedrooms'] != null) tags.add('${property!['bedrooms']} hab');
      if (property!['bathrooms'] != null) tags.add('${property!['bathrooms']} baños');
      if (property!['area_sqm'] != null) tags.add('${property!['area_sqm']} m²');
    } else if (vehicle != null) {
      for (final key in ['fuel_type', 'transmission', 'traction', 'color']) {
        final v = vehicle![key]?.toString();
        if (v != null && v.isNotEmpty) tags.add(v);
      }
      if (vehicle!['year'] != null) tags.add(vehicle!['year'].toString());
      if (vehicle!['mileage_km'] != null) tags.add('${vehicle!['mileage_km']} km');
    }
    return tags.take(6).toList();
  }

  factory ContactUnlockModel.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] is Map
        ? Map<String, dynamic>.from(json['seller'] as Map)
        : null;
    final item = json['inventory_item'] is Map
        ? Map<String, dynamic>.from(json['inventory_item'] as Map)
        : null;
    return ContactUnlockModel(
      id: json['id']?.toString() ?? '',
      matchId: json['match_id']?.toString(),
      score: int.tryParse(json['score']?.toString() ?? ''),
      wantisCharged: int.tryParse(json['wantis_charged']?.toString() ?? '1') ?? 1,
      outcome: json['outcome']?.toString() ?? 'PENDING',
      sellerName: seller?['full_name']?.toString(),
      sellerPhone: seller?['phone']?.toString(),
      sellerRating: double.tryParse(seller?['rating_average']?.toString() ?? ''),
      sellerIsNew: seller?['is_new_user'] == true,
      itemTitle: item?['title']?.toString(),
      itemPrice: double.tryParse(item?['price_cop']?.toString() ?? ''),
      itemCity: item?['city']?.toString(),
      itemDescription: item?['description']?.toString(),
      assetType: item?['asset_type']?.toString() ?? 'VEHICLE',
      vehicle: item?['vehicle'] is Map
          ? Map<String, dynamic>.from(item!['vehicle'] as Map)
          : null,
      property: item?['property'] is Map
          ? Map<String, dynamic>.from(item!['property'] as Map)
          : null,
      canOpenDispute: json['can_open_dispute'] != false,
    );
  }
}
