import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/match_cards.dart';
import '../../matches/data/matches_repository.dart';
import '../../matches/models/match_model.dart';

class SellerAlertsScreen extends StatefulWidget {
  const SellerAlertsScreen({super.key});

  @override
  State<SellerAlertsScreen> createState() => _SellerAlertsScreenState();
}

class _SellerAlertsScreenState extends State<SellerAlertsScreen> {
  bool _loading = true;
  String? _error;
  List<MatchModel> _alerts = [];

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
      final alerts = await context.read<MatchesRepository>().listSeller();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
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
                    'Alertas',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: WantiColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Un comprador busca lo que tú tenés',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      color: WantiColors.inkMuted,
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
          else if (_alerts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Sin alertas por ahora. Cuando un comprador busque algo de tu inventario, aparecerá acá.',
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
                      compact: true,
                    ),
                  );
                },
                childCount: _alerts.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
