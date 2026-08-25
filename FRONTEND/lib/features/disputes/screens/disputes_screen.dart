import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/app_mode_controller.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../auth/state/auth_controller.dart';
import '../data/disputes_repository.dart';
import '../dispute_reasons.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  bool _loading = true;
  String? _error;
  List<DisputeModel> _items = [];

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
      final items = await context.read<DisputesRepository>().list();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _openDetail(DisputeModel d) async {
    await context.push('/disputes/${d.id}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = context.watch<AppModeController>().isSeller;

    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        color: WantiColors.teal,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.paddingOf(context).top + 8,
                  24,
                  8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        'Disputas',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: WantiColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WantiColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: WantiColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSeller
                            ? 'Disputas como vendedor'
                            : 'Disputas hacia ti',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: WantiColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isSeller
                            ? 'Para abrir una disputa de Wanti: Mis contactos → entra al lead → “Abrir disputa / reembolso Wanti”.'
                            : 'Aquí solo ves disputas relacionadas contigo. '
                                'No abres disputas de Wanti desde esta pantalla.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: WantiColors.inkMuted,
                          height: 1.4,
                        ),
                      ),
                      if (isSeller) ...[
                        const SizedBox(height: 10),
                        Text(
                          DisputeReasons.sellerExplainer,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: WantiColors.tealDark,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
            else if (_items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No tienes disputas abiertas ni resueltas.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final d = _items[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: InkWell(
                        onTap: () => _openDetail(d),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: WantiColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.displayReason,
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      d.statusLabel,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        color: WantiColors.inkMuted,
                                      ),
                                    ),
                                    if ((d.openedByName ?? '').isNotEmpty)
                                      Text(
                                        'Abierta por ${d.openedByName}',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: WantiColors.inkFaint,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: WantiColors.inkFaint),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class DisputeDetailScreen extends StatefulWidget {
  const DisputeDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  DisputeModel? _dispute;

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
      final d = await context.read<DisputesRepository>().detail(widget.id);
      if (!mounted) return;
      setState(() {
        _dispute = d;
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

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await context.read<DisputesRepository>().cancel(widget.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _appeal() async {
    setState(() => _busy = true);
    try {
      await context.read<DisputesRepository>().appeal(widget.id);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(bool confirmed) async {
    setState(() => _busy = true);
    try {
      await context.read<DisputesRepository>().respondAuto(
            widget.id,
            confirmedPurchase: confirmed,
          );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _dispute;
    final userId = context.watch<AuthController>().user?.id;
    final isOpener = d?.openedBy(userId) == true;
    final isBuyer = d?.isBuyerParty(userId) == true;
    final showAutoRespond = d?.status == 'AUTO_REVIEW' && isBuyer;
    final showCancel = isOpener &&
        (d?.status == 'OPEN' ||
            d?.status == 'AUTO_REVIEW' ||
            d?.status == 'HUMAN_REVIEW');
    final showAppeal = d?.canAppeal == true;

    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: WantiColors.teal))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: WantiColors.error)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 8, 24, 32),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          ),
                          Text(
                            'Detalle de disputa',
                            style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d?.statusLabel ?? '',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: WantiColors.navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Motivo: ${d?.displayReason ?? ''}',
                              style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                            ),
                            if ((d?.openedByName ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Abierta por ${d!.openedByName}',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: WantiColors.inkFaint,
                                ),
                              ),
                            ],
                            if ((d?.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(d!.description!, style: GoogleFonts.nunito()),
                            ],
                            if ((d?.resolutionNote ?? '').isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Resolución: ${d!.resolutionNote}',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: WantiColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isBuyer
                                    ? DisputeReasons.buyerExplainer
                                    : DisputeReasons.sellerExplainer,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: WantiColors.inkMuted,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (showCancel) ...[
                              OutlinedButton(
                                onPressed: _busy ? null : _cancel,
                                child: const Text('Cancelar disputa'),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (showAutoRespond) ...[
                              Text(
                                'Verificación automática: ¿completaste la compra con este contacto?',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _busy ? null : () => _respond(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: WantiColors.teal,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Sí, compré'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _busy ? null : () => _respond(false),
                                      child: const Text('No compré'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Si confirmas la compra, la disputa se cierra sin reembolso. '
                                'Si no compraste, pasa a revisión humana.',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: WantiColors.inkFaint,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (showAppeal) ...[
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _busy ? null : _appeal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WantiColors.navy,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Apelar'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
