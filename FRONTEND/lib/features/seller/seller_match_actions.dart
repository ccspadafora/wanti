import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/wanti_colors.dart';
import '../../core/utils/whatsapp.dart';
import '../auth/state/auth_controller.dart';
import '../matches/data/matches_repository.dart';
import '../matches/models/match_model.dart';

Future<void> unlockSellerMatch(
  BuildContext context,
  MatchModel match, {
  required VoidCallback onDone,
}) async {
  try {
    final result = await context.read<MatchesRepository>().unlock(match.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.wantisCharged > 0
              ? 'Contacto desbloqueado (−${result.wantisCharged} Wanti)'
              : 'Contacto ya disponible',
        ),
      ),
    );
    onDone();
    if (!context.mounted) return;
    final leadId = result.leadId ?? match.leadId;
    if (leadId != null && leadId.isNotEmpty) {
      await context.push('/leads/$leadId');
    } else {
      final me = context.read<AuthController>().user?.fullName ?? 'un vendedor Wanti';
      await showSellerBuyerContact(
        context,
        buyerName: match.buyer?.fullName ?? 'Comprador',
        phone: result.buyerPhone ?? match.buyerPhone,
        email: result.buyerEmail ?? match.buyerEmail,
        needTitle: match.needTitle,
        actorName: me,
      );
    }
  } on ApiException catch (e) {
    if (!context.mounted) return;
    if (_isInsufficientFunds(e)) {
      await _promptBuyWantis(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  }
}

bool _isInsufficientFunds(ApiException e) {
  final code = (e.code ?? '').toUpperCase();
  final msg = e.message.toLowerCase();
  return code.contains('INSUFFICIENT') ||
      msg.contains('saldo insuficiente') ||
      msg.contains('wantis disponibles') ||
      msg.contains('sin wanti');
}

Future<void> _promptBuyWantis(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: WantiColors.canvas,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'No tienes Wanti',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      content: Text(
        'Necesitas Wanti para desbloquear este contacto. Compra ahora en tu wallet.',
        style: GoogleFonts.nunito(height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Después', style: GoogleFonts.nunito()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: WantiColors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: Text('Compra ahora', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) {
    context.push('/wallet');
  }
}

Future<void> openSellerLeadFromMatch(
  BuildContext context,
  MatchModel match,
) async {
  final leadId = match.leadId;
  if (leadId != null && leadId.isNotEmpty) {
    await context.push('/leads/$leadId');
    return;
  }
  final phone = match.buyerPhone ?? match.buyer?.phone;
  final me = context.read<AuthController>().user?.fullName ?? 'un vendedor Wanti';
  if (phone != null && phone.isNotEmpty) {
    await showSellerBuyerContact(
      context,
      buyerName: match.buyer?.fullName ?? 'Comprador',
      phone: phone,
      needTitle: match.needTitle,
      actorName: me,
    );
  }
  if (!context.mounted) return;
  context.push('/leads');
}

Future<void> showSellerBuyerContact(
  BuildContext context, {
  required String buyerName,
  String? phone,
  String? email,
  String? needTitle,
  String? actorName,
}) async {
  if (phone == null || phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sin teléfono disponible')),
    );
    return;
  }

  final first = buyerName.split(' ').first;
  final me = actorName ?? 'un vendedor Wanti';
  final msg = needTitle == null || needTitle.isEmpty
      ? 'Hola $first, te compré tu contacto por Wanti. Mucho gusto, mi nombre es $me.'
      : 'Hola $first, te compré tu contacto por Wanti. Mucho gusto, mi nombre es $me. Vi tu búsqueda “$needTitle”.';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: WantiColors.canvas,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        buyerName,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (needTitle != null && needTitle.isNotEmpty)
            Text(needTitle, style: GoogleFonts.nunito(color: WantiColors.inkMuted)),
          const SizedBox(height: 8),
          Text(
            phone,
            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(email, style: GoogleFonts.nunito(color: WantiColors.inkMuted)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cerrar', style: GoogleFonts.nunito()),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final ok = await openWhatsAppChat(phone: phone, message: msg);
            if (!ok && context.mounted) {
              final digits = phone.replaceAll(RegExp(r'\D'), '');
              final uri = Uri.parse('https://wa.me/$digits');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: Text(
            'WhatsApp',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF25D366),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shared handler for buyer unlock insufficient funds.
Future<bool> handleUnlockApiError(BuildContext context, ApiException e) async {
  if (_isInsufficientFunds(e)) {
    await _promptBuyWantis(context);
    return true;
  }
  return false;
}
