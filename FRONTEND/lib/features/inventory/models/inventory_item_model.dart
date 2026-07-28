class InventoryItemModel {
  InventoryItemModel({
    required this.id,
    required this.title,
    required this.assetType,
    required this.priceCop,
    required this.city,
    required this.status,
    this.unlockCount = 0,
    this.subtitle,
  });

  final String id;
  final String title;
  final String assetType;
  final double priceCop;
  final String city;
  final String status;
  final int unlockCount;
  final String? subtitle;

  bool get isVehicle => assetType == 'VEHICLE';

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] is Map
        ? Map<String, dynamic>.from(json['vehicle'] as Map)
        : json['detail'] is Map && json['asset_type'] == 'VEHICLE'
            ? Map<String, dynamic>.from(json['detail'] as Map)
            : null;
    final property = json['property'] is Map
        ? Map<String, dynamic>.from(json['property'] as Map)
        : json['detail'] is Map && json['asset_type'] == 'PROPERTY'
            ? Map<String, dynamic>.from(json['detail'] as Map)
            : null;

    String? subtitle;
    if (vehicle != null) {
      final parts = <String>[];
      if ((vehicle['fuel_type'] ?? '').toString().isNotEmpty) {
        parts.add(vehicle['fuel_type'].toString());
      }
      if (vehicle['mileage_km'] != null) {
        parts.add('${vehicle['mileage_km']} km');
      }
      subtitle = parts.join(' · ');
    } else if (property != null) {
      final parts = <String>[];
      if (property['bedrooms'] != null) parts.add('${property['bedrooms']} hab');
      if (property['bathrooms'] != null) parts.add('${property['bathrooms']} baños');
      subtitle = parts.join(' · ');
    }

    return InventoryItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      assetType: json['asset_type']?.toString() ?? 'VEHICLE',
      priceCop: double.tryParse(json['price_cop']?.toString() ?? '') ?? 0,
      city: json['city']?.toString() ?? '',
      status: json['status']?.toString() ?? 'AVAILABLE',
      unlockCount: int.tryParse(json['unlock_count']?.toString() ?? '0') ?? 0,
      subtitle: subtitle,
    );
  }
}
