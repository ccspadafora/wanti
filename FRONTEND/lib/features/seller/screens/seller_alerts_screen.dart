import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/match_cards.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/models/match_model.dart';
import '../seller_match_actions.dart';

class SellerAlertsScreen extends StatefulWidget {
  const SellerAlertsScreen({
    super.key,
    this.inventoryItemId,
    this.showBack = false,
  });

  final String? inventoryItemId;
  final bool showBack;

  @override
  State<SellerAlertsScreen> createState() => _SellerAlertsScreenState();
}

class _SellerAlertsScreenState extends State<SellerAlertsScreen> {
  bool _loading = true;
  String? _error;
  List<MatchModel> _alerts = [];
  List<InventoryItemModel> _inventory = [];
  String? _unlockingId;
  String? _inventoryFilter;
  String _scoreFilter = 'ALL'; // ALL | HIGH | LOW

  @override
  void initState() {
    super.initState();
    _inventoryFilter = widget.inventoryItemId;
    _load();
  }

  @override
  void didUpdateWidget(covariant SellerAlertsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inventoryItemId != widget.inventoryItemId) {
      _inventoryFilter = widget.inventoryItemId;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matchesRepo = context.read<MatchesRepository>();
      final inventoryRepo = context.read<InventoryRepository>();
      final results = await Future.wait([
        matchesRepo.listSeller(inventoryItemId: _inventoryFilter),
        inventoryRepo.listMine(status: 'AVAILABLE'),
      ]);
      if (!mounted) return;
      var alerts = results[0] as List<MatchModel>;
      if (_scoreFilter == 'HIGH') {
        alerts = alerts.where((m) => m.score >= 85).toList()
          ..sort((a, b) => b.score.compareTo(a.score));
      } else if (_scoreFilter == 'LOW') {
        alerts = alerts.where((m) => m.score < 85).toList()
          ..sort((a, b) => a.score.compareTo(b.score));
      } else {
        alerts = [...alerts]..sort((a, b) => b.score.compareTo(a.score));
      }
      setState(() {
        _alerts = alerts;
        _inventory = results[1] as List<InventoryItemModel>;
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

  @override
  Widget build(BuildContext context) {
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
                  widget.showBack ? 8 : 24,
                  MediaQuery.paddingOf(context).top + (widget.showBack ? 8 : 20),
                  24,
                  8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.showBack)
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          ),
                        Expanded(
                          child: Text(
                            'Alertas',
                            style: GoogleFonts.nunito(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: WantiColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Un comprador busca lo que tienes',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: WantiColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_inventory.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _chip(
                        label: 'Todos los ítems',
                        selected: _inventoryFilter == null,
                        onTap: () {
                          setState(() => _inventoryFilter = null);
                          _load();
                        },
                      ),
                      ..._inventory.map(
                        (i) => _chip(
                          label: i.title,
                          selected: _inventoryFilter == i.id,
                          onTap: () {
                            setState(() => _inventoryFilter = i.id);
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _chip(
                      label: 'Mayor coincidencia',
                      selected: _scoreFilter == 'HIGH',
                      onTap: () {
                        setState(() => _scoreFilter = 'HIGH');
                        _load();
                      },
                    ),
                    _chip(
                      label: 'Menor coincidencia',
                      selected: _scoreFilter == 'LOW',
                      onTap: () {
                        setState(() => _scoreFilter = 'LOW');
                        _load();
                      },
                    ),
                    _chip(
                      label: 'Todos',
                      selected: _scoreFilter == 'ALL',
                      onTap: () {
                        setState(() => _scoreFilter = 'ALL');
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
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
            else if (_alerts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _inventoryFilter == null
                        ? 'Sin alertas por ahora. Cuando un comprador busque algo de tu inventario, aparecerá aquí.'
                        : 'No hay matches para este ítem del inventario.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final match = _alerts[index];
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
                  childCount: _alerts.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
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

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: WantiColors.navy,
        labelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : WantiColors.ink,
          fontSize: 12,
        ),
        backgroundColor: WantiColors.surfaceSoft,
        side: BorderSide.none,
      ),
    );
  }
}
