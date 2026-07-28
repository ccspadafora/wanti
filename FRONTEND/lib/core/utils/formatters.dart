import 'package:intl/intl.dart';

String formatCop(num value, {bool compact = false}) {
  if (compact && value >= 1000000) {
    final m = value / 1000000;
    final formatted = m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
    return '\$${formatted}M';
  }
  return NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(value);
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
