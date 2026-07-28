import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/match_cards.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../leads/data/leads_repository.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/models/match_model.dart';

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
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _alerts;
    return _alerts.where((m) {
      final hay = '${m.needTitle} ${m.itemTitle} ${m.buyer?.fullName}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
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
                  subtitle: 'Modo vendedor',
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
                          hintText: 'Buscar necesidades de compradores...',
                          prefixIcon: const Icon(Icons.search, color: WantiColors.inkFaint),
                          filled: true,
                          fillColor: WantiColors.canvas,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explora lo que los compradores están buscando',
                        style: GoogleFonts.nunito(fontSize: 12, color: WantiColors.inkMuted),
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
                    child: _StatCard(
                      label: 'Leads',
                      value: '$_leadsCount',
                      color: WantiColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Últimas alertas de match',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: WantiColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/leads'),
                    child: Text(
                      'Mis leads →',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: WantiColors.teal,
                      ),
                    ),
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
                  'Todavía no hay alertas. Publicá inventario para recibir matches.',
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
                    child: SellerMatchCard(match: match),
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
