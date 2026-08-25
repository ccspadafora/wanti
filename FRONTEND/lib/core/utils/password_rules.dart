/// Reglas de contraseña alineadas al backend (Django AUTH_PASSWORD_VALIDATORS).
class PasswordRules {
  PasswordRules._();

  static const minLength = 10;

  static const requirements = [
    'Mínimo $minLength caracteres',
    'No puede ser solo números',
    'No uses contraseñas comunes (ej. 1234567890)',
    'No debe parecerse a tu nombre o correo',
  ];

  static String? validate(
    String? value, {
    String? email,
    String? fullName,
  }) {
    final password = value ?? '';
    if (password.isEmpty) return 'Obligatorio';
    if (password.length < minLength) {
      return 'Debe tener al menos $minLength caracteres';
    }
    if (RegExp(r'^\d+$').hasMatch(password)) {
      return 'No puede ser solo números';
    }

    final lowered = password.toLowerCase();
    final emailLocal = (email ?? '').split('@').first.toLowerCase().trim();
    if (emailLocal.length >= 3 && lowered.contains(emailLocal)) {
      return 'No debe parecerse a tu correo';
    }

    final nameParts = (fullName ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((p) => p.length >= 3);
    for (final part in nameParts) {
      if (lowered.contains(part)) {
        return 'No debe parecerse a tu nombre';
      }
    }

    const common = {
      'password',
      'password1',
      '1234567890',
      '123456789',
      'qwertyuiop',
      'abcdefghij',
      'colombia12',
      'wanti12345',
    };
    if (common.contains(lowered)) {
      return 'Esa contraseña es demasiado común';
    }
    return null;
  }
}
