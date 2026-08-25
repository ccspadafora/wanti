import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/app_mode_controller.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/match_cards.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../leads/data/leads_repository.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/models/match_model.dart';
import '../seller_match_actions.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  bool _loading = true;
  String? _error;
  List<MatchModel> _alerts = [];
  int _inventoryCount = 0;
  int _leadsCount = 0;
  final _search = TextEditingController();
  String? _unlockingId;
  int? _catalogEpoch;
  String _scoreFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matches = context.read<MatchesRepository>();
      final inventory = context.read<InventoryRepository>();
      final leads = context.read<LeadsRepository>();
      final results = await Future.wait([
        matches.listSeller(),
        inventory.listMine(),
        leads.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _alerts = results[0] as List<MatchModel>;
        _inventoryCount = (results[1] as List).length;
        _leadsCount = (results[2] as List).length;
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

  List<MatchModel> get _filtered {
    var list = _alerts;
    if (_scoreFilter == 'HIGH') {
      list = list.where((m) => m.score >= 85).toList();
    } else if (_scoreFilter == 'LOW') {
      list = list.where((m) => m.score < 85).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((m) {
      final hay =
          '${m.needTitle} ${m.itemTitle} ${m.buyer?.fullName} ${m.needCity}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final epoch = context.watch<AppModeController>().catalogEpoch;
    if (_catalogEpoch != null && _catalogEpoch != epoch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    _catalogEpoch = epoch;
    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      color: WantiColors.teal,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                HomeAppHeader(
                  greeting: 'Hola, ${user?.firstName ?? ''} 👋',
                  subtitle: 'Modo vender',
                ),
                Container(
                  width: double.infinity,
                  color: WantiColors.surfaceTeal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar comprador, sueño o ítem…',
                          prefixIcon: const Icon(Icons.search, color: WantiColors.inkFaint),
                          filled: true,
                          fillColor: WantiColors.canvas,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: WantiColors.canvas.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _HomeSeg(
                              label: 'Todos',
                              selected: _scoreFilter == 'ALL',
                              onTap: () => setState(() => _scoreFilter = 'ALL'),
                            ),
                            _HomeSeg(
                              label: '≥ 85%',
                              selected: _scoreFilter == 'HIGH',
                              onTap: () => setState(() => _scoreFilter = 'HIGH'),
                            ),
                            _HomeSeg(
                              label: '< 85%',
                              selected: _scoreFilter == 'LOW',
                              onTap: () => setState(() => _scoreFilter = 'LOW'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Alertas',
                      value: '${_alerts.length}',
                      color: WantiColors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Inventario',
                      value: '$_inventoryCount',
                      color: WantiColors.navy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.push('/leads'),
                      borderRadius: BorderRadius.circular(14),
                      child: _StatCard(
                        label: 'Contactos',
                        value: '$_leadsCount',
                        color: WantiColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => context.push('/needs/browse'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: WantiColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: WantiColors.surfaceTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.travel_explore_rounded,
                            color: WantiColors.tealDark,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explorar sueños',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: WantiColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Busca necesidades activas por marca, modelo y más — sin depender de tu inventario.',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: WantiColors.inkMuted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: WantiColors.inkFaint),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Últimas alertas de match',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: WantiColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/contacts/purchasers'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Contactos desbloqueados',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: WantiColors.navy,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/leads'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Mis contactos →',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: WantiColors.teal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
          else if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay alertas. Publica inventario para recibir matches.',
                  style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final match = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: SellerMatchCard(
                      match: match,
                      unlocking: _unlockingId == match.id,
                      onUnlock: () async {
                        setState(() => _unlockingId = match.id);
                        await unlockSellerMatch(
                          context,
                          match,
                          onDone: _load,
                        );
                        if (mounted) setState(() => _unlockingId = null);
                      },
                      onOpenLead: () => openSellerLeadFromMatch(context, match),
                      onDiscard: () => _discard(match),
                    ),
                  );
                },
                childCount: filtered.take(5).length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: WantiButton(
                label: '+ Publicar inventario',
                onPressed: () async {
                  await context.push('/inventory/new');
                  _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _discard(MatchModel match) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Descartar alerta?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'Esta coincidencia dejará de aparecer en tus alertas.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Descartar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<MatchesRepository>().discard(match.id);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _HomeSeg extends StatelessWidget {
  const _HomeSeg({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? WantiColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : WantiColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: WantiColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 12, color: WantiColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
