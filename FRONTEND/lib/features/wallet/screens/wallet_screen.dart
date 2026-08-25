import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../data/wallet_repository.dart';
import '../models/wallet_models.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  String? _error;
  WalletBalance? _balance;
  List<TopupPackage> _packages = [];
  List<WalletTransaction> _txns = [];
  String? _selectedPackageId;
  bool _topping = false;

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
      final repo = context.read<WalletRepository>();
      final results = await Future.wait([
        repo.balance(),
        repo.packages(),
        repo.transactions(),
      ]);
      if (!mounted) return;
      final packages = results[1] as List<TopupPackage>;
      setState(() {
        _balance = results[0] as WalletBalance;
        _packages = packages;
        _txns = results[2] as List<WalletTransaction>;
        _selectedPackageId ??= packages.where((p) => p.isPopular).firstOrNull?.id ??
            packages.firstOrNull?.id;
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

  Future<void> _topup() async {
    final id = _selectedPackageId;
    if (id == null) return;
    setState(() => _topping = true);
    try {
      final result = await context.read<WalletRepository>().topup(id);
      if (!mounted) return;
      final status = (result['status'] ?? '').toString().toUpperCase();
      final checkout = result['checkout_url']?.toString();
      if (status == 'COMPLETED') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wanti acreditados')),
        );
      } else if (checkout != null && checkout.isNotEmpty) {
        final uri = Uri.tryParse(checkout);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa el pago. El saldo se actualizará al confirmarse.'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Orden creada ($status). Esperando confirmación de pago.')),
        );
      }
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _balance;

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
                    'Mi Wallet',
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
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: WantiColors.navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo disponible',
                        style: GoogleFonts.nunito(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${balance?.balanceWantis ?? 0} Wanti',
                        style: GoogleFonts.nunito(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '≈ ${formatCop(balance?.balanceEquivalentCop ?? 0)} · 1 Wanti = ${formatCop(balance?.wantiPriceCop ?? 5000)}',
                        style: GoogleFonts.nunito(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Recargar Wanti',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: WantiColors.ink,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final pkg = _packages[index];
                  final selected = pkg.id == _selectedPackageId;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                    child: InkWell(
                      onTap: () => setState(() => _selectedPackageId = pkg.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? WantiColors.teal : WantiColors.border,
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${pkg.wantisTotal} Wanti',
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: WantiColors.ink,
                                        ),
                                      ),
                                      if (pkg.wantisBonus > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WantiColors.surfaceTeal,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '+${pkg.wantisBonus} gratis',
                                            style: GoogleFonts.nunito(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: WantiColors.tealDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (pkg.isPopular) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WantiColors.warningLight,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Popular',
                                            style: GoogleFonts.nunito(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: WantiColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    formatCop(pkg.priceCop),
                                    style: GoogleFonts.nunito(
                                      color: WantiColors.inkMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? WantiColors.navy : WantiColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Elegir',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : WantiColors.inkMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _packages.length,
              ),
            ),
            if (_packages.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: WantiButton(
                    label: 'Recargar',
                    loading: _topping,
                    onPressed: _topup,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(
                  'Historial reciente',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: WantiColors.ink,
                  ),
                ),
              ),
            ),
            if (_txns.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Sin movimientos todavía.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final txn = _txns[index];
                    final positive = txn.amountWantis > 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        txn.label,
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w700,
                                          color: WantiColors.ink,
                                        ),
                                      ),
                                      if (txn.detailLine.isNotEmpty)
                                        Text(
                                          txn.detailLine,
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            color: WantiColors.inkMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${positive ? '+' : ''}${txn.amountWantis}',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w800,
                                    color: positive ? WantiColors.teal : WantiColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: WantiColors.borderLight),
                        ],
                      ),
                    );
                  },
                  childCount: _txns.take(10).length,
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
