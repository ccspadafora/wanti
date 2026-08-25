import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/app_mode_controller.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/gratis_badge.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../../needs/models/preference_catalog.dart';

class SellerInventoryScreen extends StatefulWidget {
  const SellerInventoryScreen({super.key});

  @override
  State<SellerInventoryScreen> createState() => _SellerInventoryScreenState();
}

class _SellerInventoryScreenState extends State<SellerInventoryScreen> {
  bool _loading = true;
  String? _error;
  List<InventoryItemModel> _items = [];
  String? _markingId;
  int? _catalogEpoch;
  String _assetFilter = 'ALL'; // ALL | VEHICLE | PROPERTY
  String? _vehicleCategory;
  String? _brandFilter;
  String? _modelFilter;
  String? _propertyType;

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
      final repo = context.read<InventoryRepository>();
      final results = await Future.wait([
        repo.listMine(status: 'AVAILABLE'),
        repo.listMine(status: 'RESERVED'),
      ]);
      if (!mounted) return;
      final items = <InventoryItemModel>[
        ...results[0],
        ...results[1],
      ].where((e) => e.status != 'SOLD').toList();
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

  Future<void> _addInventory() async {
    await context.push('/inventory/new');
    _load();
  }

  Future<void> _markSold(InventoryItemModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Marcar como vendido?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          '“${item.title}” desaparecerá del inventario activo.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vendido')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _markingId = item.id);
    try {
      await context.read<InventoryRepository>().markSold(item.id);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _markingId = null);
    }
  }

  Future<void> _reserve(InventoryItemModel item) async {
    setState(() => _markingId = item.id);
    try {
      await context.read<InventoryRepository>().reserve(item.id);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _markingId = null);
    }
  }

  Future<void> _reactivate(InventoryItemModel item) async {
    setState(() => _markingId = item.id);
    try {
      await context.read<InventoryRepository>().reactivate(item.id);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _markingId = null);
    }
  }

  List<InventoryItemModel> get _filtered {
    var list = _items;
    if (_assetFilter == 'VEHICLE') {
      list = list.where((e) => e.isVehicle).toList();
      if (_vehicleCategory != null) {
        list = list.where((e) => e.vehicleCategory == _vehicleCategory).toList();
      }
      if (_brandFilter != null && _brandFilter!.isNotEmpty) {
        final q = _brandFilter!.toLowerCase();
        list = list.where((e) => (e.brand ?? '').toLowerCase().contains(q)).toList();
      }
      if (_modelFilter != null && _modelFilter!.isNotEmpty) {
        final q = _modelFilter!.toLowerCase();
        list = list.where((e) => (e.model ?? '').toLowerCase().contains(q)).toList();
      }
    } else if (_assetFilter == 'PROPERTY') {
      list = list.where((e) => !e.isVehicle).toList();
      if (_propertyType != null) {
        list = list.where((e) => e.propertyType == _propertyType).toList();
      }
    }
    return list;
  }

  List<String> get _availableBrands {
    final brands = _items
        .where((e) => e.isVehicle && (e.brand ?? '').isNotEmpty)
        .map((e) => e.brand!)
        .toSet()
        .toList()
      ..sort();
    return brands;
  }

  void _setAssetFilter(String value) {
    setState(() {
      _assetFilter = value;
      if (value != 'VEHICLE') {
        _vehicleCategory = null;
        _brandFilter = null;
        _modelFilter = null;
      }
      if (value != 'PROPERTY') {
        _propertyType = null;
      }
    });
  }

  Future<void> _editPrice(InventoryItemModel item) async {
    final controller = TextEditingController(
      text: formatCop(item.priceCop),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar precio', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [CopInputFormatter()],
          decoration: const InputDecoration(labelText: 'Precio COP', hintText: r'$75.000.000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final price = parseCopInput(controller.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio inválido')),
      );
      return;
    }
    setState(() => _markingId = item.id);
    try {
      await context.read<InventoryRepository>().update(item.id, {'price_cop': price});
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _markingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mi inventario',
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: WantiColors.ink,
                          ),
                        ),
                      ),
                      const GratisBadge(),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addInventory,
                        style: IconButton.styleFrom(
                          backgroundColor: WantiColors.teal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Sube tu inventario',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Catálogo interno · las fotos reales se comparten por WhatsApp',
                    style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _addInventory,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: Text(
                        'Sube tu inventario',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WantiColors.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _assetFilter == 'ALL',
                        onSelected: (_) => _setAssetFilter('ALL'),
                        selectedColor: WantiColors.navy,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: _assetFilter == 'ALL' ? Colors.white : WantiColors.ink,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Vehículos'),
                        selected: _assetFilter == 'VEHICLE',
                        onSelected: (_) => _setAssetFilter('VEHICLE'),
                        selectedColor: WantiColors.navy,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: _assetFilter == 'VEHICLE' ? Colors.white : WantiColors.ink,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Inmuebles'),
                        selected: _assetFilter == 'PROPERTY',
                        onSelected: (_) => _setAssetFilter('PROPERTY'),
                        selectedColor: WantiColors.navy,
                        labelStyle: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: _assetFilter == 'PROPERTY' ? Colors.white : WantiColors.ink,
                        ),
                      ),
                    ],
                  ),
                  if (_assetFilter == 'VEHICLE') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _vehicleCategory,
                      decoration: const InputDecoration(labelText: 'Categoría', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ...PreferenceCatalog.vehicleCategories.map(
                          (c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _vehicleCategory = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _brandFilter,
                      decoration: const InputDecoration(labelText: 'Marca', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ..._availableBrands.map(
                          (b) => DropdownMenuItem(value: b, child: Text(b)),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _brandFilter = v;
                        _modelFilter = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Modelo',
                        hintText: 'Ej. Spark',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {
                        _modelFilter = v.trim().isEmpty ? null : v.trim();
                      }),
                    ),
                  ],
                  if (_assetFilter == 'PROPERTY') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _propertyType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de inmueble',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        ...PreferenceCatalog.propertyTypes.map(
                          (p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _propertyType = v),
                    ),
                  ],
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
          else if (_filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _items.isEmpty
                      ? 'Todavía no tienes inventario activo. Sube tu primer vehículo o inmueble — es GRATIS.'
                      : 'No hay ítems con estos filtros.',
                  style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _filtered[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _InventoryCard(
                      item: item,
                      marking: _markingId == item.id,
                      onOpenMatches: () => context.push(
                        '/alerts?inventoryItemId=${Uri.encodeComponent(item.id)}',
                      ),
                      onMarkSold: () => _markSold(item),
                      onReserve: () => _reserve(item),
                      onReactivate: () => _reactivate(item),
                      onEditPrice: () => _editPrice(item),
                    ),
                  );
                },
                childCount: _filtered.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.onOpenMatches,
    required this.onMarkSold,
    required this.onReserve,
    required this.onReactivate,
    required this.onEditPrice,
    this.marking = false,
  });

  final InventoryItemModel item;
  final VoidCallback onOpenMatches;
  final VoidCallback onMarkSold;
  final VoidCallback onReserve;
  final VoidCallback onReactivate;
  final VoidCallback onEditPrice;
  final bool marking;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
      '≈ ${formatCop(item.priceCop, compact: true)}',
      if (item.unlockCount > 0) '${item.unlockCount} contactos',
      if (item.status == 'RESERVED') 'Reservado',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenMatches,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
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
                      if (item.matchesCount > 0)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: WantiColors.navy,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              item.matchesCount > 99 ? '99+' : '${item.matchesCount}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                        if (item.matchesCount > 0)
                          Text(
                            '${item.matchesCount} match${item.matchesCount == 1 ? '' : 'es'}',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: WantiColors.tealDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar precio',
                    onPressed: marking ? null : onEditPrice,
                    icon: const Icon(Icons.edit_outlined, size: 20, color: WantiColors.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpenMatches,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WantiColors.tealDark,
                        side: const BorderSide(color: WantiColors.teal),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Ver matches',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: marking
                          ? null
                          : (item.status == 'RESERVED' ? onReactivate : onReserve),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WantiColors.inkMuted,
                        side: const BorderSide(color: WantiColors.border),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        marking
                            ? '...'
                            : (item.status == 'RESERVED' ? 'Reactivar' : 'Reservar'),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: marking ? null : onMarkSold,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WantiColors.inkMuted,
                    side: const BorderSide(color: WantiColors.border),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    marking ? '...' : 'Marcar vendido',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
