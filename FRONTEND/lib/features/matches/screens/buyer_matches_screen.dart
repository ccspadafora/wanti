import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/app_mode_controller.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/match_cards.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/models/match_model.dart';
import '../../needs/data/needs_repository.dart';
import '../../needs/models/need_model.dart';

class BuyerMatchesScreen extends StatefulWidget {
  const BuyerMatchesScreen({
    super.key,
    this.needId,
    this.needFilterToken = 0,
  });

  final String? needId;
  final int needFilterToken;

  @override
  State<BuyerMatchesScreen> createState() => _BuyerMatchesScreenState();
}

class _BuyerMatchesScreenState extends State<BuyerMatchesScreen> {
  bool _loading = true;
  String? _error;
  List<MatchModel> _matches = [];
  List<NeedModel> _needs = [];
  String? _needFilter;
  String _scoreFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _needFilter = widget.needId;
    _load();
  }

  @override
  void didUpdateWidget(covariant BuyerMatchesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.needFilterToken != oldWidget.needFilterToken) {
      setState(() => _needFilter = widget.needId);
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final needs = await context.read<NeedsRepository>().listMine();
      var matches = await context.read<MatchesRepository>().listBuyer(
            needId: _needFilter,
          );
      if (_scoreFilter == 'HIGH') {
        matches = matches.where((m) => m.score >= 85).toList()
          ..sort((a, b) => b.score.compareTo(a.score));
      } else if (_scoreFilter == 'LOW') {
        matches = matches.where((m) => m.score < 85).toList()
          ..sort((a, b) => a.score.compareTo(b.score));
      } else {
        matches = [...matches]..sort((a, b) => b.score.compareTo(a.score));
      }
      if (!mounted) return;
      setState(() {
        _needs = needs.where((n) => n.status == 'ACTIVE' || n.status == 'PAUSED').toList();
        _matches = matches;
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

  String get _subtitle {
    if (_needFilter == null) return 'Todos tus matches activos';
    final need = _needs.where((n) => n.id == _needFilter).firstOrNull;
    if (need == null) return 'Matches de este sueño';
    return '${need.title} · ${need.city}';
  }

  Future<void> _openUnlocked(MatchModel match) async {
    await context.push(
      '/matches/${match.id}/unlocked'
      '?unlockId=${Uri.encodeComponent(match.unlockId ?? '')}'
      '&phone=${Uri.encodeComponent(match.sellerPhone ?? match.seller?.phone ?? '')}'
      '&score=${match.score}',
    );
    _load();
  }

  Future<void> _discard(MatchModel match) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Descartar match?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'Dejará de aparecer en tu lista. Puedes seguir buscando otros.',
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
      if (!mounted) return;
      setState(() {
        _matches.removeWhere((m) => m.id == match.id);
        final needId = match.needId;
        if (needId != null) {
          _needs = _needs.map((n) {
            if (n.id != needId) return n;
            final next = (n.matchesCount - 1).clamp(0, 999999);
            return n.copyWith(matchesCount: next);
          }).toList();
        }
      });
      context.read<AppModeController>().bumpCatalog();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
                24,
                MediaQuery.paddingOf(context).top + 20,
                24,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tus matches',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: WantiColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle,
                    style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: WantiColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _ScoreSeg(
                          label: 'Todos',
                          selected: _scoreFilter == 'ALL',
                          onTap: () {
                            setState(() => _scoreFilter = 'ALL');
                            _load();
                          },
                        ),
                        _ScoreSeg(
                          label: '≥ 85%',
                          selected: _scoreFilter == 'HIGH',
                          onTap: () {
                            setState(() => _scoreFilter = 'HIGH');
                            _load();
                          },
                        ),
                        _ScoreSeg(
                          label: '< 85%',
                          selected: _scoreFilter == 'LOW',
                          onTap: () {
                            setState(() => _scoreFilter = 'LOW');
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_needs.isNotEmpty)
            ContenedorNeedsList(
              needs: _needs,
              needFilter: _needFilter,
              matchCount: _matches.length,
              onSelect: (id) {
                setState(() => _needFilter = id);
                _load();
              },
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
          else if (_matches.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _needFilter == null
                      ? 'Todavía no hay matches. Publica un sueño y te avisamos cuando haya coincidencias.'
                      : 'Todavía no hay matches para este sueño.',
                  style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final match = _matches[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: BuyerMatchCard(
                      match: match,
                      unlocking: false,
                      onOpenUnlocked: () => _openUnlocked(match),
                      onDiscard: () => _discard(match),
                    ),
                  );
                },
                childCount: _matches.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _ScoreSeg extends StatelessWidget {
  const _ScoreSeg({
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? WantiColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : WantiColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class ContenedorNeedsList extends StatelessWidget {
  const ContenedorNeedsList({
    super.key,
    required this.needs,
    required this.needFilter,
    required this.matchCount,
    required this.onSelect,
  });

  final List<NeedModel> needs;
  final String? needFilter;
  final int matchCount;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          children: [
            _NeedPill(
              label: 'Todos',
              count: needFilter == null ? matchCount : null,
              selected: needFilter == null,
              onTap: () => onSelect(null),
            ),
            ...needs.map((n) {
              final selected = needFilter == n.id;
              return _NeedPill(
                label: n.title,
                count: selected ? matchCount : n.matchesCount,
                selected: selected,
                onTap: () => onSelect(n.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NeedPill extends StatelessWidget {
  const _NeedPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? WantiColors.surfaceTeal : WantiColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? WantiColors.teal : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? WantiColors.tealDark : WantiColors.inkMuted,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected ? WantiColors.teal : WantiColors.borderLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : WantiColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
