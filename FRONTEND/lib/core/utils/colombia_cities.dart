/// Ciudades canónicas de Colombia (selector único para evitar variantes de escritura).
class ColombiaCities {
  ColombiaCities._();

  static const List<String> all = [
    'Bogotá',
    'Medellín',
    'Cali',
    'Barranquilla',
    'Cartagena',
    'Bucaramanga',
    'Pereira',
    'Manizales',
    'Santa Marta',
    'Cúcuta',
    'Ibagué',
    'Villavicencio',
    'Pasto',
    'Neiva',
    'Armenia',
    'Valledupar',
    'Montería',
    'Sincelejo',
    'Popayán',
    'Tunja',
  ];

  static String? normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final q = raw.trim().toLowerCase();
    for (final c in all) {
      if (c.toLowerCase() == q) return c;
    }
    // aliases comunes
    if (q == 'bogota') return 'Bogotá';
    if (q == 'medellin') return 'Medellín';
    if (q == 'cucuta') return 'Cúcuta';
    if (q == 'ibague') return 'Ibagué';
    if (q == 'popayan') return 'Popayán';
    return null;
  }
}
