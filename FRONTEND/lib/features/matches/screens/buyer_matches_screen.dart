import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
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
  String? _unlockingId;

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
      final matches = await context.read<MatchesRepository>().listBuyer(
            needId: _needFilter,
          );
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
    if (need == null) return 'Matches de esta necesidad';
    return '${need.title} · ${need.city}';
  }

  Future<void> _unlock(MatchModel match) async {
    setState(() => _unlockingId = match.id);
    try {
      final result = await context.read<MatchesRepository>().unlock(match.id);
      if (!mounted) return;
      await context.push(
        '/matches/${match.id}/unlocked'
        '?unlockId=${Uri.encodeComponent(result.unlockId)}'
        '&phone=${Uri.encodeComponent(result.sellerPhone ?? '')}'
        '&score=${match.score}',
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _unlockingId = null);
    }
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
                ],
              ),
            ),
          ),
          if (_needs.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Todos'),
                        selected: _needFilter == null,
                        onSelected: (_) {
                          setState(() => _needFilter = null);
                          _load();
                        },
                        selectedColor: WantiColors.navy,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: _needFilter == null ? Colors.white : WantiColors.ink,
                        ),
                        backgroundColor: WantiColors.surfaceSoft,
                        side: BorderSide.none,
                      ),
                    ),
                    ..._needs.map(
                      (n) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(n.title, overflow: TextOverflow.ellipsis),
                          selected: _needFilter == n.id,
                          onSelected: (_) {
                            setState(() => _needFilter = n.id);
                            _load();
                          },
                          selectedColor: WantiColors.navy,
                          labelStyle: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: _needFilter == n.id ? Colors.white : WantiColors.ink,
                            fontSize: 12,
                          ),
                          backgroundColor: WantiColors.surfaceSoft,
                          side: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
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
          else if (_matches.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _needFilter == null
                      ? 'Todavía no hay matches. Publicá una necesidad y te avisamos cuando haya coincidencias.'
                      : 'Todavía no hay matches para esta necesidad.',
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
                      unlocking: _unlockingId == match.id,
                      onUnlock: () => _unlock(match),
                      onOpenUnlocked: () => _openUnlocked(match),
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
