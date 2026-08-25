import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../shared/widgets/match_cards.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';
import '../../disputes/dispute_reasons.dart';
import '../../disputes/widgets/open_dispute_sheet.dart';
import '../../leads/data/leads_repository.dart';
import '../../leads/models/lead_model.dart';

class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({super.key, required this.leadId});

  final String leadId;

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  LeadModel? _lead;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lead = await context.read<LeadsRepository>().detail(widget.leadId);
      if (!mounted) return;
      setState(() {
        _lead = lead;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'IN_NEGOTIATION':
        return WantiColors.warning;
      case 'TO_VISIT':
        return const Color(0xFF3B82F6);
      case 'PURCHASED':
        return WantiColors.teal;
      case 'DISCARDED':
        return WantiColors.inkFaint;
      default:
        return WantiColors.navy;
    }
  }

  Future<void> _changeStage() async {
    final lead = _lead;
    if (lead == null) return;
    final stages = {
      'NEW': 'Nuevo',
      'IN_NEGOTIATION': 'En negociación',
      'TO_VISIT': 'Por visitar',
      'PURCHASED': 'Comprado',
      'DISCARDED': 'Descartado',
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: WantiColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Estado del lead',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            ...stages.entries.map(
              (e) => ListTile(
                title: Text(e.value, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                trailing: lead.stage == e.key
                    ? const Icon(Icons.check_circle, color: WantiColors.teal)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == lead.stage || !mounted) return;

    double? soldPrice;
    if (selected == 'PURCHASED') {
      final controller = TextEditingController(
        text: lead.soldPriceCop?.toStringAsFixed(0) ?? lead.priceCop?.toStringAsFixed(0) ?? '',
      );
      soldPrice = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Precio de venta', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'COP'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                final v = double.tryParse(controller.text.replaceAll(RegExp(r'[^\d.]'), ''));
                Navigator.pop(ctx, v);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (soldPrice == null) return;
    }

    setState(() => _busy = true);
    try {
      final updated = await context.read<LeadsRepository>().changeStage(
            lead.id,
            selected,
            soldPrice: soldPrice,
          );
      if (!mounted) return;
      setState(() => _lead = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final lead = _lead;
    if (lead == null) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nueva nota', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe un comentario del lead…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<LeadsRepository>().addNote(lead.id, controller.text.trim());
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDispute() async {
    final lead = _lead;
    final unlockId = lead?.unlockId;
    if (lead == null || unlockId == null || unlockId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar el desbloqueo')),
      );
      return;
    }
    if (!lead.canOpenDispute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya hay una disputa abierta para este contacto')),
      );
      return;
    }
    final ok = await showOpenDisputeSheet(
      context,
      unlockId: unlockId,
      role: 'seller',
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disputa enviada a revisión')),
      );
      await _load();
    }
  }

  Future<void> _openWhatsApp() async {
    final lead = _lead;
    final phone = lead?.buyerPhone;
    if (lead == null || phone == null || phone.isEmpty) return;
    final me = context.read<AuthController>().user?.fullName ?? 'un vendedor Wanti';
    final first = lead.buyerName.split(' ').first;
    final need = lead.needTitle ?? lead.itemTitle;
    final msg =
        'Hola $first, te desbloqueé tu contacto por Wanti. Mucho gusto, mi nombre es $me. '
        'Vi tu búsqueda “$need”.';
    final ok = await openWhatsAppChat(phone: phone, message: msg);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  Future<void> _copyPhone() async {
    final phone = _lead?.buyerPhone;
    if (phone == null || phone.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teléfono copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = _lead;
    final score = lead?.score ?? 0;
    final color = lead == null ? WantiColors.navy : _stageColor(lead.stage);

    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: WantiColors.teal))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: WantiColors.error)))
                : lead == null
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          ScreenHeader(
                            title: 'Lead',
                            onBack: () => context.pop(),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: WantiColors.surfaceTeal,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_open_rounded,
                                        color: WantiColors.tealDark,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Contacto desbloqueado con Wanti. Gestiona este lead como CRM.',
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: WantiColors.tealDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Comprador',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: WantiColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: WantiColors.surfaceTeal,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: WantiColors.navy,
                                        child: Text(
                                          initialsOf(lead.buyerName),
                                          style: GoogleFonts.nunito(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lead.buyerName,
                                              style: GoogleFonts.nunito(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: WantiColors.ink,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: lead.buyerPhone == null
                                                  ? null
                                                  : _openWhatsApp,
                                              onLongPress: _copyPhone,
                                              child: Text(
                                                lead.buyerPhone ?? 'Teléfono no disponible',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 15,
                                                  color: WantiColors.inkMuted,
                                                  decoration: lead.buyerPhone == null
                                                      ? null
                                                      : TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                            if ((lead.buyerEmail ?? '').isNotEmpty)
                                              Text(
                                                lead.buyerEmail!,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 13,
                                                  color: WantiColors.inkFaint,
                                                ),
                                              ),
                                            if (lead.buyerRating != null)
                                              Text(
                                                '★ ${lead.buyerRating!.toStringAsFixed(1)}',
                                                style: GoogleFonts.nunito(
                                                  fontWeight: FontWeight.w700,
                                                  color: WantiColors.warning,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _busy ? null : _openWhatsApp,
                                    icon: const Icon(Icons.chat_rounded),
                                    label: Text(
                                      'Abrir WhatsApp',
                                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Disputa / Wanti',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DisputeReasons.sellerExplainer,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: WantiColors.inkMuted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _busy || !lead.canOpenDispute
                                        ? null
                                        : _openDispute,
                                    icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
                                    label: Text(
                                      lead.canOpenDispute
                                          ? 'Abrir disputa / reembolso Wanti'
                                          : 'Disputa ya abierta',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: WantiColors.error,
                                      disabledForegroundColor: WantiColors.inkFaint,
                                      side: BorderSide(
                                        color: lead.canOpenDispute
                                            ? WantiColors.error
                                            : WantiColors.borderLight,
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!lead.canOpenDispute) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => context.push('/disputes'),
                                    child: Text(
                                      'Ver mis disputas',
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w700,
                                        color: WantiColors.tealDark,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                Text(
                                  'Sueño del comprador',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: WantiColors.teal, width: 1.4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (score > 0) ...[
                                            MatchPercentLabel(score: score),
                                            const SizedBox(width: 12),
                                          ],
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  lead.needTitle ?? 'Sueño',
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  [
                                                    if ((lead.needCity ?? '').isNotEmpty)
                                                      lead.needCity,
                                                    if (lead.budgetMaxCop != null)
                                                      'Hasta ${formatCop(lead.budgetMaxCop!, compact: true)}',
                                                  ].whereType<String>().join(' · '),
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 13,
                                                    color: WantiColors.inkMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if ((lead.needDescription ?? '').trim().isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          lead.needDescription!.trim(),
                                          style: GoogleFonts.nunito(
                                            fontSize: 13,
                                            color: WantiColors.inkMuted,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Text(
                                        'Match con tu ítem: ${lead.itemTitle}'
                                        '${lead.priceCop != null ? ' · ${formatCop(lead.priceCop!, compact: true)}' : ''}',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: WantiColors.tealDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Estado',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: _busy ? null : _changeStage,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: WantiColors.borderLight),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            lead.stageLabel,
                                            style: GoogleFonts.nunito(
                                              fontWeight: FontWeight.w800,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Cambiar',
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w700,
                                            color: WantiColors.tealDark,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: WantiColors.tealDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Notas',
                                        style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _busy ? null : _addNote,
                                      icon: const Icon(Icons.add_comment_outlined, size: 18),
                                      label: Text(
                                        'Agregar',
                                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                if (lead.notes.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Todavía no hay comentarios en este lead.',
                                      style: GoogleFonts.nunito(
                                        color: WantiColors.inkMuted,
                                        height: 1.4,
                                      ),
                                    ),
                                  )
                                else
                                  ...lead.notes.map(
                                    (n) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: WantiColors.surfaceSoft,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.text,
                                            style: GoogleFonts.nunito(
                                              fontSize: 14,
                                              height: 1.4,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            [
                                              if ((n.authorName ?? '').isNotEmpty) n.authorName,
                                              if (n.createdAt != null)
                                                relativeDaysAgo(n.createdAt),
                                            ].whereType<String>().join(' · '),
                                            style: GoogleFonts.nunito(
                                              fontSize: 11,
                                              color: WantiColors.inkFaint,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
