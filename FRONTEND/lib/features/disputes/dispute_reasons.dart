/// Motivos de disputa de contacto/Wanti: solo el vendedor (quien gasta Wanti).
/// El comprador no disputa Wanti; impugna reseñas desde Mis reseñas.
class DisputeReasons {
  DisputeReasons._();

  static const seller = <({String code, String label})>[
    (code: 'BUYER_CONTACT_INVALID', label: 'El contacto del comprador es inválido'),
    (code: 'BUYER_NO_RESPONSE', label: 'El comprador no responde'),
    (code: 'SPAM_OR_ABUSE', label: 'Lead spam, abuso o mala fe'),
    (code: 'FALSE_NEED', label: 'La búsqueda no es real o tiene datos falsos'),
    (code: 'OTHER', label: 'Otro motivo'),
  ];

  /// Comprador no abre disputas de contacto/Wanti.
  static const buyer = <({String code, String label})>[];

  static List<({String code, String label})> forRole(String role) =>
      role == 'seller' ? seller : buyer;

  static String labelFor(String code) {
    for (final r in seller) {
      if (r.code == code) return r.label;
    }
    const legacy = {
      'CONTACT_INVALID': 'El contacto no existe o es inválido',
      'NO_RESPONSE': 'El vendedor no responde',
      'ASSET_UNAVAILABLE': 'El bien ya no está disponible',
      'FALSE_INFO': 'Información falsa o engañosa',
      'OTHER': 'Otro motivo',
    };
    return legacy[code] ?? code.replaceAll('_', ' ');
  }

  static const sellerExplainer =
      'Como vendedor gastas Wanti para desbloquear el contacto del comprador. '
      'Si el lead es inválido (contacto falso, no responde, spam o sueño irreal), '
      'puedes abrir una disputa y solicitar reembolso de Wanti. '
      'El caso pasa a revisión humana.';

  static const buyerExplainer =
      'Aquí solo ves disputas relacionadas contigo (por ejemplo, si un vendedor '
      'abrió una disputa sobre un contacto). Para impugnar una calificación o '
      'comentario, usa Mis reseñas → Recibidas.';

  static String explainerFor(String role) =>
      role == 'seller' ? sellerExplainer : buyerExplainer;
}
