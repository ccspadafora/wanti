class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  /// Mensaje listo para mostrar (incluye detalles de validación).
  String get displayMessage {
    final fromDetails = _messagesFromDetails(details);
    if (fromDetails.isEmpty) return message;
    final joined = fromDetails.join('\n');
    if (message.trim().isEmpty ||
        message == 'Error de validación' ||
        message == 'Error') {
      return joined;
    }
    if (joined == message || message.contains(fromDetails.first)) return message;
    return '$message\n$joined';
  }

  static List<String> _messagesFromDetails(dynamic data) {
    final out = <String>[];
    if (data is List) {
      for (final item in data) {
        out.addAll(_messagesFromDetails(item));
      }
    } else if (data is Map) {
      for (final value in data.values) {
        out.addAll(_messagesFromDetails(value));
      }
    } else if (data != null) {
      final text = data.toString().trim();
      if (text.isNotEmpty) out.add(text);
    }
    return out;
  }

  @override
  String toString() => displayMessage;
}
