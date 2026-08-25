import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/app_mode_controller.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/gratis_badge.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../auth/state/auth_controller.dart';
import '../../matches/screens/buyer_matches_screen.dart';
import '../../needs/data/needs_repository.dart';
import '../../needs/models/need_model.dart';
import '../../profile/screens/profile_screen.dart';
import '../../seller/screens/seller_alerts_screen.dart';
import '../../seller/screens/seller_home_screen.dart';
import '../../seller/screens/seller_inventory_screen.dart';
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab, this.initialNeedId});

  final String? initialTab;
  final String? initialNeedId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  String _asset = 'VEHICLE';
  AppMode? _lastMode;
  String? _matchesNeedId;
  int _matchesNeedToken = 0;

  @override
  void initState() {
    super.initState();
    _applyInitialTab(widget.initialTab, widget.initialNeedId);
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.initialNeedId != widget.initialNeedId) {
      _applyInitialTab(widget.initialTab, widget.initialNeedId);
    }
  }

  void _applyInitialTab(String? tab, [String? needId]) {
    if (tab == 'matches') _tab = 2;
    if (tab == 'wallet') _tab = 3;
    if (tab == 'inventory') _tab = 1;
    if (tab == 'alerts') _tab = 2;
    if (tab == 'profile') _tab = 3;
    if (needId != null && needId.isNotEmpty) {
      _matchesNeedId = needId;
      _matchesNeedToken++;
      _tab = 2;
    }
  }

  void _openMatchesForNeed(String needId) {
    setState(() {
      _matchesNeedId = needId;
      _matchesNeedToken++;
      _tab = 2;
    });
  }

  Future<void> _openNewNeed() async {
    await context.push('/needs/new?asset=$_asset');
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppModeController>();
    if (_lastMode != null && _lastMode != mode.mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = 0);
      });
    }
    _lastMode = mode.mode;

    final isSeller = mode.isSeller;

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _tab,
        children: isSeller
            ? const [
                SellerHomeScreen(),
                SellerInventoryScreen(),
                SellerAlertsScreen(),
                ProfileScreen(),
              ]
            : [
                BuyerHomeScreen(
                  asset: _asset,
                  onAssetChanged: (v) => setState(() => _asset = v),
                  onNeedSelected: _openMatchesForNeed,
                ),
                const SizedBox.shrink(),
                BuyerMatchesScreen(
                  needId: _matchesNeedId,
                  needFilterToken: _matchesNeedToken,
                ),
                const ProfileScreen(),
              ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: WantiColors.borderLight)),
          color: WantiColors.canvas,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: isSeller
                  ? [
                      _navItem(0, Icons.home_outlined, Icons.home, 'Inicio'),
                      _navItem(
                        1,
                        Icons.inventory_2_outlined,
                        Icons.inventory_2,
                        'Inventario',
                        showGratis: true,
                      ),
                      _navItem(2, Icons.notifications_none, Icons.notifications, 'Alertas'),
                      _navItem(3, Icons.person_outline, Icons.person, 'Perfil'),
                    ]
                  : [
                      _navItem(0, Icons.home_outlined, Icons.home, 'Inicio'),
                      _navItem(
                        1,
                        Icons.add_circle_outline,
                        Icons.add_circle,
                        'Publicar',
                        showGratis: true,
                      ),
                      _navItem(2, Icons.favorite_border, Icons.favorite, 'Matches'),
                      _navItem(3, Icons.person_outline, Icons.person, 'Perfil'),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool showGratis = false,
  }) {
    final active = _tab == index;
    final isSeller = context.read<AppModeController>().isSeller;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isSeller && index == 1) {
            _openNewNeed();
            return;
          }
          setState(() => _tab = index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 3,
              width: 28,
              decoration: BoxDecoration(
                color: active ? WantiColors.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(
              height: 14,
              child: showGratis
                  ? const Center(child: GratisBadge(compact: true))
                  : null,
            ),
            Icon(
              active ? activeIcon : icon,
              color: active ? WantiColors.teal : WantiColors.inkFaint,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? WantiColors.teal : WantiColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({
    super.key,
    required this.asset,
    required this.onAssetChanged,
    required this.onNeedSelected,
  });

  final String asset;
  final ValueChanged<String> onAssetChanged;
  final ValueChanged<String> onNeedSelected;

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  bool _loading = true;
  List<NeedModel> _needs = [];
  String? _error;
  int? _catalogEpoch;

  String get _asset => widget.asset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BuyerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<NeedsRepository>();
      final needs = await repo.listMine(assetType: _asset);
      if (!mounted) return;
      setState(() {
        _needs = needs.where((n) => n.status == 'ACTIVE' || n.status == 'PAUSED').toList();
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _budgetLabel(double value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      final formatted = m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
      return '\$${formatted}M COP';
    }
    return NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(value);
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

    return RefreshIndicator(
      onRefresh: _load,
      color: WantiColors.teal,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: HomeAppHeader(
              greeting: '${_greeting()}, ${user?.firstName ?? ''} 👋',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _AssetToggle(
                      selected: _asset == 'VEHICLE',
                      icon: Icons.directions_car_filled_outlined,
                      label: 'Vehículo',
                      onTap: () => widget.onAssetChanged('VEHICLE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AssetToggle(
                      selected: _asset == 'PROPERTY',
                      icon: Icons.home_work_outlined,
                      label: 'Inmueble',
                      onTap: () => widget.onAssetChanged('PROPERTY'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Text(
                _asset == 'VEHICLE'
                    ? 'Mis sueños de vehículo'
                    : 'Mis sueños de inmueble',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: WantiColors.ink,
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
          else if (_needs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Todavía no tienes sueños activos.\nPublica el primero.',
                  style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final need = _needs[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _NeedCard(
                      need: need,
                      budget: _budgetLabel(need.budgetMaxCop),
                      onRenewed: _load,
                      onOpen: () => widget.onNeedSelected(need.id),
                    ),
                  );
                },
                childCount: _needs.length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: GratisBadge(),
                  ),
                  const SizedBox(height: 8),
                  WantiButton(
                    label: '+ Publicar sueño',
                    onPressed: () async {
                      await context.push('/needs/new?asset=$_asset');
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetToggle extends StatelessWidget {
  const _AssetToggle({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? WantiColors.navy : WantiColors.canvas,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? WantiColors.navy : WantiColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : WantiColors.ink, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : WantiColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedCard extends StatefulWidget {
  const _NeedCard({
    required this.need,
    required this.budget,
    required this.onRenewed,
    required this.onOpen,
  });

  final NeedModel need;
  final String budget;
  final Future<void> Function() onRenewed;
  final VoidCallback onOpen;

  @override
  State<_NeedCard> createState() => _NeedCardState();
}

class _NeedCardState extends State<_NeedCard> {
  bool _renewing = false;
  bool _toggling = false;

  Future<void> _togglePause() async {
    setState(() => _toggling = true);
    try {
      final repo = context.read<NeedsRepository>();
      if (widget.need.status == 'PAUSED') {
        await repo.resume(widget.need.id);
      } else {
        await repo.pause(widget.need.id);
      }
      await widget.onRenewed();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _confirmRenew() async {
    const renewalDays = 30;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WantiColors.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Renovar publicación?',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: WantiColors.ink,
          ),
        ),
        content: Text(
          '“${widget.need.title}” se extenderá por $renewalDays días más desde hoy.',
          style: GoogleFonts.nunito(
            fontSize: 15,
            color: WantiColors.inkMuted,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                color: WantiColors.inkMuted,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: WantiColors.teal,
                foregroundColor: WantiColors.onTeal,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Sí, renovar',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _renewing = true);
    try {
      await context.read<NeedsRepository>().renew(widget.need.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Publicación renovada por $renewalDays días',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: WantiColors.navy,
        ),
      );
      await widget.onRenewed();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final need = widget.need;
    final days = need.daysRemaining;
    final isVehicle = need.assetType == 'VEHICLE';
    final renewable = need.isRenewable;
    final urgent = days != null && days <= 5;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WantiColors.canvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: urgent ? WantiColors.warning : WantiColors.border,
              width: urgent ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: WantiColors.navy.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: WantiColors.surfaceTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isVehicle ? Icons.directions_car_filled : Icons.home_work_outlined,
                      color: WantiColors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          need.title,
                          style: GoogleFonts.nunito(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: WantiColors.ink,
                          ),
                        ),
                        Text(
                          widget.budget,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: WantiColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: WantiColors.inkFaint,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: need.status == 'PAUSED'
                          ? WantiColors.warningLight
                          : WantiColors.surfaceTeal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      need.status == 'PAUSED' ? 'Pausada' : '${need.matchesCount} matches',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: need.status == 'PAUSED'
                            ? WantiColors.warning
                            : WantiColors.tealDark,
                      ),
                    ),
                  ),
                  if (days != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgent ? WantiColors.warningLight : WantiColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        days == 0 ? 'Vence hoy' : '$days días restantes',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: urgent ? WantiColors.warning : WantiColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _toggling ? null : _togglePause,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WantiColors.inkMuted,
                        side: const BorderSide(color: WantiColors.border),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        _toggling
                            ? '...'
                            : (need.status == 'PAUSED' ? 'Reanudar' : 'Pausar'),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await context.push<bool>(
                          '/needs/${need.id}/edit',
                        );
                        if (ok == true) await widget.onRenewed();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WantiColors.navy,
                        side: const BorderSide(color: WantiColors.navy),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Editar',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  if (renewable) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _renewing ? null : _confirmRenew,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: WantiColors.tealDark,
                          side: const BorderSide(color: WantiColors.teal, width: 1.5),
                          shape: const StadiumBorder(),
                        ),
                        child: _renewing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: WantiColors.teal,
                                ),
                              )
                            : Text(
                                'Renovar',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
