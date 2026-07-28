import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/models/inventory_item_model.dart';

class SellerInventoryScreen extends StatefulWidget {
  const SellerInventoryScreen({super.key});

  @override
  State<SellerInventoryScreen> createState() => _SellerInventoryScreenState();
}

class _SellerInventoryScreenState extends State<SellerInventoryScreen> {
  bool _loading = true;
  String? _error;
  List<InventoryItemModel> _items = [];

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
      final items = await context.read<InventoryRepository>().listMine();
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
                    'Mi inventario',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: WantiColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Catálogo interno · las fotos reales se comparten por WhatsApp',
                    style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
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
          else if (_items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Todavía no tenés inventario. Agregá tu primer vehículo o inmueble.',
                  style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _InventoryCard(item: item),
                  );
                },
                childCount: _items.length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () async {
                    await context.push('/inventory/new');
                    _load();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WantiColors.teal,
                    side: const BorderSide(color: WantiColors.teal, width: 1.5),
                    shape: const StadiumBorder(),
                    textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  child: const Text('+ Agregar al inventario'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item});

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
      '≈ ${formatCop(item.priceCop, compact: true)}',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WantiColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WantiColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: WantiColors.navy.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.isVehicle ? WantiColors.surfaceTeal : WantiColors.surfaceNavy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.isVehicle ? Icons.directions_car_filled : Icons.apartment_rounded,
              color: item.isVehicle ? WantiColors.teal : WantiColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: WantiColors.ink,
                  ),
                ),
                Text(
                  subtitleParts.join(' · '),
                  style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
