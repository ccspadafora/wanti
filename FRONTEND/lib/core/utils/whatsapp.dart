import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp chat with [phone], optionally with a prefilled [message].
Future<bool> openWhatsAppChat({
  required String phone,
  String? message,
}) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return false;

  final encoded = message == null || message.trim().isEmpty
      ? null
      : Uri.encodeComponent(message.trim());

  final candidates = <Uri>[
    if (encoded != null)
      Uri.parse('whatsapp://send?phone=$digits&text=$encoded')
    else
      Uri.parse('whatsapp://send?phone=$digits'),
    if (encoded != null)
      Uri.parse('https://wa.me/$digits?text=$encoded')
    else
      Uri.parse('https://wa.me/$digits'),
    Uri.parse('https://api.whatsapp.com/send?phone=$digits${encoded != null ? '&text=$encoded' : ''}'),
  ];

  for (final uri in candidates) {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (_) {
      // try next scheme
    }
  }
  return false;
}
