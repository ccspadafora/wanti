import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../leads/data/leads_repository.dart';
import '../../leads/models/lead_model.dart';

class SellerLeadsScreen extends StatefulWidget {
  const SellerLeadsScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<SellerLeadsScreen> createState() => _SellerLeadsScreenState();
}

class _SellerLeadsScreenState extends State<SellerLeadsScreen> {
  static const _filters = <(String, String)>[
    ('ALL', 'Todos'),
    ('IN_NEGOTIATION', 'En negociación'),
    ('TO_VISIT', 'Por visitar'),
    ('PURCHASED', 'Comprado'),
    ('DISCARDED', 'Descartado'),
  ];

  String _stage = 'ALL';
  bool _loading = true;
  String? _error;
  List<LeadModel> _leads = [];

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
      final leads = await context.read<LeadsRepository>().list(
            stage: _stage == 'ALL' ? null : _stage,
          );
      if (!mounted) return;
      setState(() {
        _leads = leads;
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

  Future<void> _changeStage(LeadModel lead) async {
    final stages = {
      'NEW': 'Nuevo',
      'IN_NEGOTIATION': 'En negociación',
      'TO_VISIT': 'Por visitar',
      'PURCHASED': 'Comprado',
      'DISCARDED': 'Descartado',
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
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
                'Cambiar estado',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            ...stages.entries.map(
              (e) => ListTile(
                title: Text(e.value, style: GoogleFonts.nunito()),
                trailing: lead.stage == e.key
                    ? const Icon(Icons.check, color: WantiColors.teal)
                    : null,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || selected == lead.stage || !mounted) return;

    double? soldPrice;
    if (selected == 'PURCHASED') {
      final controller = TextEditingController(
        text: lead.priceCop?.toStringAsFixed(0) ?? '',
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

    try {
      await context.read<LeadsRepository>().changeStage(
            lead.id,
            selected,
            soldPrice: soldPrice,
          );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addComment(LeadModel lead) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Comentar', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Nota sobre este lead...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty || !mounted) return;
    try {
      await context.read<LeadsRepository>().addNote(lead.id, controller.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota guardada')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _viewContact(LeadModel lead) async {
    final phone = lead.buyerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin teléfono disponible')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lead.buyerName, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: Text(phone, style: GoogleFonts.nunito(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          TextButton(
            onPressed: () async {
              final digits = phone.replaceAll(RegExp(r'\D'), '');
              final uri = Uri.parse('https://wa.me/$digits');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: WantiColors.teal,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 8,
                24,
                8,
              ),
              child: Row(
                children: [
                  if (widget.showBack)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                  Text(
                    'Mis leads',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: WantiColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _filters.map((f) {
                  final selected = _stage == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _stage = f.$1);
                        _load();
                      },
                      selectedColor: WantiColors.navy,
                      labelStyle: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : WantiColors.ink,
                        fontSize: 13,
                      ),
                      backgroundColor: WantiColors.surfaceSoft,
                      shape: const StadiumBorder(),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: WantiColors.teal)),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: WantiColors.error)),
              ),
            )
          else if (_leads.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aún no tenés leads. Cuando un comprador desbloquee tu contacto, aparecerá acá.',
                  style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final lead = _leads[index];
                  final color = _stageColor(lead.stage);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: WantiColors.canvas,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: WantiColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lead.buyerName,
                                  style: GoogleFonts.nunito(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: WantiColors.ink,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  lead.stageLabel,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${lead.itemTitle}'
                            '${lead.priceCop != null ? ' · ${formatCop(lead.priceCop!, compact: true)}' : ''}',
                            style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                          ),
                          if (lead.lastActivityAt != null)
                            Text(
                              'Desbloqueado ${relativeDaysAgo(lead.lastActivityAt)}',
                              style: GoogleFonts.nunito(fontSize: 12, color: WantiColors.inkFaint),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _changeStage(lead),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: WantiColors.teal,
                                    side: const BorderSide(color: WantiColors.teal),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: Text(
                                    'Cambiar estado',
                                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _addComment(lead),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: WantiColors.inkMuted,
                                    side: const BorderSide(color: WantiColors.border),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: Text(
                                    'Comentar',
                                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _viewContact(lead),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: WantiColors.inkMuted,
                                    side: const BorderSide(color: WantiColors.border),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: Text(
                                    'Ver contacto',
                                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _leads.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
