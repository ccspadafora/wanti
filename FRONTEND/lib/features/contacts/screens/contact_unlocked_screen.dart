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
import '../../contacts/data/contacts_repository.dart';
import '../../contacts/models/contact_unlock_model.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/models/match_model.dart';

class ContactUnlockedScreen extends StatefulWidget {
  const ContactUnlockedScreen({
    super.key,
    required this.matchId,
    this.unlockId,
    this.phone,
    this.score,
  });

  final String matchId;
  final String? unlockId;
  final String? phone;
  final int? score;

  @override
  State<ContactUnlockedScreen> createState() => _ContactUnlockedScreenState();
}

class _ContactUnlockedScreenState extends State<ContactUnlockedScreen> {
  bool _loading = true;
  String? _error;
  MatchModel? _match;
  ContactUnlockModel? _unlock;
  String? _outcome;
  bool _busy = false;
  bool _openingWa = false;

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
      final matchesRepo = context.read<MatchesRepository>();
      final contactsRepo = context.read<ContactsRepository>();
      final match = await matchesRepo.detail(widget.matchId);

      ContactUnlockModel? unlock;
      if (widget.unlockId != null && widget.unlockId!.isNotEmpty) {
        unlock = await contactsRepo.findUnlock(widget.unlockId!);
      }
      if (unlock == null) {
        final unlocks = await contactsRepo.listUnlocks();
        unlock = unlocks.where((u) => u.matchId == match.id).firstOrNull ??
            unlocks.where((u) => u.itemTitle == match.itemTitle).firstOrNull;
      }

      if (!mounted) return;
      setState(() {
        _match = match;
        _unlock = unlock;
        _outcome = (unlock?.outcome == null || unlock?.outcome == 'PENDING')
            ? null
            : unlock?.outcome;
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

  String? get _phone {
    final candidates = [
      widget.phone,
      _unlock?.sellerPhone,
      _match?.sellerPhone,
      _match?.seller?.phone,
    ];
    for (final p in candidates) {
      if (p != null && p.trim().isNotEmpty) return p.trim();
    }
    return null;
  }

  String get _sellerName =>
      _unlock?.sellerName ?? _match?.seller?.fullName ?? 'Vendedor';

  String get _whatsappMessage {
    final item = _match?.itemTitle ?? _unlock?.itemTitle ?? 'tu publicación';
    return 'Hola $_sellerName, te contacto desde Wanti por “$item”. ¿Seguís disponible?';
  }

  Future<void> _openWhatsApp() async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teléfono del vendedor no disponible')),
      );
      return;
    }

    setState(() => _openingWa = true);
    final unlockId = _unlock?.id ?? widget.unlockId;
    if (unlockId != null && unlockId.isNotEmpty) {
      try {
        await context.read<ContactsRepository>().markWhatsappOpened(unlockId);
      } catch (_) {}
    }

    final ok = await openWhatsAppChat(phone: phone, message: _whatsappMessage);
    if (!mounted) return;
    setState(() => _openingWa = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp. Verificá que esté instalado.'),
        ),
      );
    }
  }

  Future<void> _copyPhone() async {
    final phone = _phone;
    if (phone == null) return;
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teléfono copiado')),
    );
  }

  Future<void> _reportOutcome(String outcome) async {
    final unlockId = _unlock?.id ?? widget.unlockId;
    if (unlockId == null || unlockId.isEmpty) return;
    setState(() {
      _busy = true;
      _outcome = outcome;
    });
    try {
      await context.read<ContactsRepository>().reportOutcome(unlockId, outcome);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por tu feedback')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _outcome = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dispute() async {
    final unlockId = _unlock?.id ?? widget.unlockId;
    if (unlockId == null || unlockId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reportar disputa', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: Text(
          'Vas a solicitar reembolso por lead inválido. ¿Continuar?',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reportar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<ContactsRepository>().createDispute(
            unlockId,
            reason: 'CONTACT_INVALID',
            details: 'Lead inválido reportado desde la app',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disputa enviada')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    final score = widget.score ?? _unlock?.score ?? match?.score ?? 0;
    final itemTitle = match?.itemTitle ?? _unlock?.itemTitle ?? 'Publicación';
    final itemPrice = match?.itemPrice ?? _unlock?.itemPrice;
    final itemCity = match?.itemCity ?? _unlock?.itemCity;
    final tags = match?.buyerMatchTags.isNotEmpty == true
        ? match!.buyerMatchTags
        : (_unlock?.itemTags ?? const <String>[]);

    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: WantiColors.teal))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: WantiColors.error)))
                : Column(
                    children: [
                      ScreenHeader(
                        title: 'Contacto desbloqueado',
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
                                      'Lead desbloqueado. Ya podés ver el ítem y hablar con el vendedor.',
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
                              'Publicación',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: WantiColors.ink,
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
                                      MatchPercentLabel(score: score),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itemTitle,
                                              style: GoogleFonts.nunito(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: WantiColors.ink,
                                              ),
                                            ),
                                            Text(
                                              [
                                                if (itemCity != null && itemCity.isNotEmpty)
                                                  itemCity,
                                                if (itemPrice != null)
                                                  '${formatCop(itemPrice)} COP',
                                                if (match?.itemYear != null)
                                                  '${match!.itemYear}',
                                                if (match?.itemMileage != null)
                                                  formatKm(match!.itemMileage),
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
                                  if (tags.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: tags
                                          .map((t) => PreferenceChip(label: t))
                                          .toList(),
                                    ),
                                  ],
                                  if ((match?.itemDescription ?? _unlock?.itemDescription)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      (match?.itemDescription ?? _unlock?.itemDescription)!
                                          .trim(),
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        color: WantiColors.inkMuted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Vendedor',
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
                                      initialsOf(_sellerName),
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
                                          _sellerName,
                                          style: GoogleFonts.nunito(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: WantiColors.ink,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _phone == null ? null : _openWhatsApp,
                                          onLongPress: _copyPhone,
                                          child: Text(
                                            _phone ?? 'Teléfono no disponible',
                                            style: GoogleFonts.nunito(
                                              fontSize: 15,
                                              color: WantiColors.inkMuted,
                                              decoration: _phone == null
                                                  ? null
                                                  : TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Vendedor verificado ✓',
                                            style: GoogleFonts.nunito(
                                              fontWeight: FontWeight.w700,
                                              color: WantiColors.tealDark,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: (_busy || _openingWa) ? null : _openWhatsApp,
                                icon: _openingWa
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.chat_rounded, size: 20),
                                label: Text(
                                  'Contactar por WhatsApp',
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Abre WhatsApp con un mensaje listo para enviarle a $_sellerName.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: WantiColors.inkFaint,
                              ),
                            ),
                            if (_phone != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _copyPhone,
                                child: Text(
                                  'Copiar teléfono',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700,
                                    color: WantiColors.tealDark,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              '¿Cómo resultó este contacto?',
                              style: GoogleFonts.nunito(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: WantiColors.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _OutcomeBtn(
                                    label: 'Compré',
                                    icon: Icons.check_circle_outline,
                                    bg: WantiColors.surfaceTeal,
                                    fg: WantiColors.tealDark,
                                    selected: _outcome == 'PURCHASED',
                                    onTap: _busy ? null : () => _reportOutcome('PURCHASED'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _OutcomeBtn(
                                    label: 'En proceso',
                                    icon: Icons.hourglass_empty,
                                    bg: WantiColors.warningLight,
                                    fg: WantiColors.warning,
                                    selected: _outcome == 'IN_PROGRESS',
                                    onTap: _busy ? null : () => _reportOutcome('IN_PROGRESS'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _OutcomeBtn(
                                    label: 'No compré',
                                    icon: Icons.cancel_outlined,
                                    bg: WantiColors.errorLight,
                                    fg: WantiColors.error,
                                    selected: _outcome == 'NOT_PURCHASED',
                                    onTap: _busy ? null : () => _reportOutcome('NOT_PURCHASED'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed:
                                  _busy || (_unlock?.canOpenDispute == false) ? null : _dispute,
                              child: Text(
                                'Lead inválido → Reportar disputa y solicitar reembolso',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  color: WantiColors.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
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

class _OutcomeBtn extends StatelessWidget {
  const _OutcomeBtn({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.selected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? fg : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
