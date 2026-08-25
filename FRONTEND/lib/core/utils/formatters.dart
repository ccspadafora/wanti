import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

String formatCop(num value, {bool compact = false}) {
  if (compact && value >= 1000000) {
    final m = value / 1000000;
    final formatted = m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
    return '\$${formatted}M';
  }
  final number = NumberFormat.decimalPattern('es_CO').format(value.round());
  return '\$$number';
}

String formatKm(num? km) {
  if (km == null) return '';
  return '${NumberFormat.decimalPattern('es_CO').format(km)} km';
}

String relativeDaysAgo(DateTime? date) {
  if (date == null) return '';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'hoy';
  if (days == 1) return 'hace 1 día';
  return 'hace $days días';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Parsea un monto COP escrito con puntos/comas/símbolo.
double? parseCopInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return null;
  return double.tryParse(digits);
}

/// Formatea el campo de precio mientras se escribe: `$75.000.000`
/// El `$` siempre va al inicio. Permite borrar todo el contenido.
class CopInputFormatter extends TextInputFormatter {
  CopInputFormatter();

  final NumberFormat _number = NumberFormat.decimalPattern('es_CO');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final clipped = digits.length > 15 ? digits.substring(0, 15) : digits;
    final value = int.tryParse(clipped) ?? 0;
    final formatted = '\$${_number.format(value)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
