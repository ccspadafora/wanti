import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../contacts/data/contacts_repository.dart';
import '../dispute_reasons.dart';

/// Sheet compartido para abrir disputa (vendedor = Wanti).
Future<bool> showOpenDisputeSheet(
  BuildContext context, {
  required String unlockId,
  required String role,
}) async {
  final reasons = DisputeReasons.forRole(role);
  if (reasons.isEmpty) {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: WantiColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Disputas de Wanti',
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              DisputeReasons.buyerExplainer,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: WantiColors.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
    return false;
  }

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WantiColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _OpenDisputeSheetBody(
      unlockId: unlockId,
      role: role,
      reasons: reasons,
    ),
  );
  return ok == true;
}

class _OpenDisputeSheetBody extends StatefulWidget {
  const _OpenDisputeSheetBody({
    required this.unlockId,
    required this.role,
    required this.reasons,
  });

  final String unlockId;
  final String role;
  final List<({String code, String label})> reasons;

  @override
  State<_OpenDisputeSheetBody> createState() => _OpenDisputeSheetBodyState();
}

class _OpenDisputeSheetBodyState extends State<_OpenDisputeSheetBody> {
  late String _selected;
  String _details = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.reasons.first.code;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final text = _details.trim();
      await context.read<ContactsRepository>().createDispute(
            widget.unlockId,
            reason: _selected,
            details: text.isEmpty ? 'Disputa abierta desde la app' : text,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.displayMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la disputa: $e')),
      );
    }
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WantiColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solicitar reembolso de Wanti',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DisputeReasons.explainerFor(widget.role),
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: WantiColors.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Motivo',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: WantiColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.reasons.map((r) {
              final sel = _selected == r.code;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: _submitting ? null : () => setState(() => _selected = r.code),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? WantiColors.teal : WantiColors.borderLight,
                        width: sel ? 1.5 : 1,
                      ),
                      color: sel ? WantiColors.surfaceTeal : WantiColors.canvas,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sel ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18,
                          color: sel ? WantiColors.tealDark : WantiColors.inkFaint,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r.label,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              enabled: !_submitting,
              onChanged: (v) => _details = v,
              decoration: InputDecoration(
                hintText: 'Detalle opcional',
                hintStyle: GoogleFonts.nunito(color: WantiColors.inkFaint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: WantiColors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: WantiColors.error.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _submitting ? 'Enviando…' : 'Enviar disputa',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: _submitting ? null : _cancel,
              child: Text(
                'Cancelar',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
