class WalletBalance {
  WalletBalance({
    required this.balanceWantis,
    required this.wantiPriceCop,
    required this.balanceEquivalentCop,
  });

  final int balanceWantis;
  final double wantiPriceCop;
  final double balanceEquivalentCop;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balanceWantis: int.tryParse(json['balance_wantis']?.toString() ?? '0') ?? 0,
      wantiPriceCop: double.tryParse(json['wanti_price_cop']?.toString() ?? '5000') ?? 5000,
      balanceEquivalentCop:
          double.tryParse(json['balance_equivalent_cop']?.toString() ?? '0') ?? 0,
    );
  }
}

class TopupPackage {
  TopupPackage({
    required this.id,
    required this.name,
    required this.wantisBase,
    required this.wantisBonus,
    required this.wantisTotal,
    required this.priceCop,
    required this.isPopular,
  });

  final String id;
  final String name;
  final int wantisBase;
  final int wantisBonus;
  final int wantisTotal;
  final double priceCop;
  final bool isPopular;

  factory TopupPackage.fromJson(Map<String, dynamic> json) {
    return TopupPackage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      wantisBase: int.tryParse(json['wantis_base']?.toString() ?? '0') ?? 0,
      wantisBonus: int.tryParse(json['wantis_bonus']?.toString() ?? '0') ?? 0,
      wantisTotal: int.tryParse(json['wantis_total']?.toString() ?? '0') ?? 0,
      priceCop: double.tryParse(json['price_cop']?.toString() ?? '0') ?? 0,
      isPopular: json['is_popular'] == true,
    );
  }
}

class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.type,
    required this.amountWantis,
    required this.balanceAfter,
    this.note,
    this.contactName,
    this.inventoryTitle,
    this.createdAt,
  });

  final String id;
  final String type;
  final int amountWantis;
  final int balanceAfter;
  final String? note;
  final String? contactName;
  final String? inventoryTitle;
  final DateTime? createdAt;

  String get label {
    switch (type) {
      case 'TOPUP':
        return 'Recarga';
      case 'UNLOCK':
        return 'Desbloqueo de contacto';
      case 'REFUND':
        return 'Reembolso · Disputa';
      case 'BONUS':
        return 'Bonificación';
      default:
        return type;
    }
  }

  String get detailLine {
    if (type == 'UNLOCK') {
      final parts = <String>[
        if (contactName != null && contactName!.isNotEmpty) contactName!,
        if (inventoryTitle != null && inventoryTitle!.isNotEmpty) inventoryTitle!,
      ];
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    return note ?? '';
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      type: json['transaction_type']?.toString() ?? '',
      amountWantis: int.tryParse(json['amount_wantis']?.toString() ?? '0') ?? 0,
      balanceAfter: int.tryParse(json['balance_after']?.toString() ?? '0') ?? 0,
      note: json['note']?.toString(),
      contactName: json['contact_name']?.toString(),
      inventoryTitle: json['inventory_title']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}
