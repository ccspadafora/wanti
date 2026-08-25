import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../needs/data/needs_repository.dart';
import '../../needs/models/need_browse_filters.dart';
import '../../needs/models/need_model.dart';
import '../../needs/models/preference_catalog.dart';
import '../../needs/utils/need_thumbnails.dart';
import 'browse_need_filter_wizard.dart';

class BrowseNeedsScreen extends StatefulWidget {
  const BrowseNeedsScreen({super.key});

  @override
  State<BrowseNeedsScreen> createState() => _BrowseNeedsScreenState();
}

class _BrowseNeedsScreenState extends State<BrowseNeedsScreen> {
  bool _loading = true;
  String? _error;
  List<NeedModel> _needs = [];
  final _filters = NeedBrowseFilters();

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
      final needs = await context.read<NeedsRepository>().search(
            assetType: _filters.assetType,
            city: _filters.city,
            brand: _filters.isVehicle ? _filters.brand : null,
            model: _filters.isVehicle ? _filters.model : null,
            year: _filters.isVehicle ? _filters.year : null,
            vehicleCategory: _filters.isVehicle ? _filters.vehicleCategory : null,
            propertyType: _filters.isVehicle ? null : _filters.propertyType,
            listingIntent: _filters.isVehicle ? null : _filters.listingIntent,
            bedroomsMin: _filters.isVehicle ? null : _filters.bedroomsMin,
            bathroomsMin: _filters.isVehicle ? null : _filters.bathroomsMin,
            areaMinSqm: _filters.isVehicle ? null : _filters.areaMinSqm,
            socioeconomicStratum:
                _filters.isVehicle ? null : _filters.socioeconomicStratum,
            parkingSpotsMin: _filters.isVehicle ? null : _filters.parkingSpotsMin,
            maxBudget: _filters.maxBudget,
          );
      if (!mounted) return;
      setState(() {
        _needs = needs;
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

  void _clearFilters() {
    setState(() {
      _filters.clearAll();
    });
    _load();
  }

  Future<void> _openFilters() async {
    final result = await Navigator.of(context).push<NeedBrowseFilters>(
      MaterialPageRoute(
        builder: (_) => BrowseNeedFilterWizard(initial: _filters),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _filters
          ..assetType = result.assetType
          ..vehicleCategory = result.vehicleCategory
          ..brand = result.brand
          ..model = result.model
          ..year = result.year
          ..city = result.city
          ..propertyType = result.propertyType
          ..listingIntent = result.listingIntent
          ..bedroomsMin = result.bedroomsMin
          ..bathroomsMin = result.bathroomsMin
          ..areaMinSqm = result.areaMinSqm
          ..socioeconomicStratum = result.socioeconomicStratum
          ..parkingSpotsMin = result.parkingSpotsMin
          ..maxBudget = result.maxBudget;
      });
      _load();
    }
  }

  void _setAssetType(String asset) {
    setState(() {
      _filters.assetType = asset;
      if (asset == 'VEHICLE') {
        _filters.clearPropertyFilters();
      } else {
        _filters.vehicleCategory = null;
        _filters.brand = null;
        _filters.model = null;
        _filters.year = null;
      }
    });
    _load();
  }

  String _subtitle(NeedModel n) {
    final detail = n.detail;
    if (n.assetType == 'VEHICLE' && detail != null) {
      final brand = detail['brand']?.toString() ?? '';
      final model = detail['model']?.toString() ?? '';
      final bits = [if (brand.isNotEmpty) brand, if (model.isNotEmpty) model];
      if (bits.isNotEmpty) {
        return '${bits.join(' ')} · ${n.city} · hasta ${formatCop(n.budgetMaxCop, compact: true)}';
      }
    }
    if (n.assetType == 'PROPERTY' && detail != null) {
      final type = detail['property_type']?.toString() ?? '';
      final label = PreferenceCatalog.propertyTypes
          .where((p) => p.$1 == type)
          .map((p) => p.$2)
          .firstOrNull;
      if (label != null) {
        return '$label · ${n.city} · hasta ${formatCop(n.budgetMaxCop, compact: true)}';
      }
    }
    return '${n.city} · hasta ${formatCop(n.budgetMaxCop, compact: true)}';
  }

  List<Widget> _activeFilterChips() {
    final chips = <Widget>[];
    void addChip(String label, VoidCallback onRemove) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: InputChip(
            label: Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600)),
            onDeleted: onRemove,
            deleteIconColor: WantiColors.inkMuted,
            backgroundColor: WantiColors.surfaceSoft,
            side: const BorderSide(color: WantiColors.borderLight),
          ),
        ),
      );
    }

    if (_filters.city != null) {
      addChip(_filters.city!, () {
        setState(() => _filters.city = null);
        _load();
      });
    }
    if (_filters.isVehicle) {
      if (_filters.vehicleCategory != null) {
        final label = PreferenceCatalog.vehicleCategories
            .where((c) => c.$1 == _filters.vehicleCategory)
            .map((c) => c.$2)
            .firstOrNull ?? _filters.vehicleCategory!;
        addChip(label, () {
          setState(() {
            _filters.vehicleCategory = null;
            _filters.clearVehicleIdentity();
          });
          _load();
        });
      }
      if (_filters.brand != null) {
        addChip(_filters.brand!, () {
          setState(() {
            _filters.brand = null;
            _filters.model = null;
            _filters.year = null;
          });
          _load();
        });
      }
      if (_filters.model != null) {
        addChip(_filters.model!, () {
          setState(() {
            _filters.model = null;
            _filters.year = null;
          });
          _load();
        });
      }
      if (_filters.year != null) {
        addChip('${_filters.year}', () {
          setState(() => _filters.year = null);
          _load();
        });
      }
    } else {
      if (_filters.propertyType != null) {
        final label = PreferenceCatalog.propertyTypes
                .where((p) => p.$1 == _filters.propertyType)
                .map((p) => p.$2)
                .firstOrNull ??
            _filters.propertyType!;
        addChip(label, () {
          setState(() => _filters.propertyType = null);
          _load();
        });
      }
      if (_filters.listingIntent != null) {
        addChip(
          _filters.listingIntent == 'RENT' ? 'Arriendo' : 'Venta',
          () {
            setState(() => _filters.listingIntent = null);
            _load();
          },
        );
      }
      if (_filters.areaMinSqm != null) {
        addChip('≥ ${_filters.areaMinSqm} m²', () {
          setState(() => _filters.areaMinSqm = null);
          _load();
        });
      }
      if (_filters.bedroomsMin != null) {
        addChip('${_filters.bedroomsMin}+ hab.', () {
          setState(() => _filters.bedroomsMin = null);
          _load();
        });
      }
      if (_filters.bathroomsMin != null) {
        addChip('${_filters.bathroomsMin}+ baños', () {
          setState(() => _filters.bathroomsMin = null);
          _load();
        });
      }
      if (_filters.socioeconomicStratum != null) {
        addChip('Estrato ${_filters.socioeconomicStratum}', () {
          setState(() => _filters.socioeconomicStratum = null);
          _load();
        });
      }
      if (_filters.parkingSpotsMin != null) {
        addChip('${_filters.parkingSpotsMin}+ park.', () {
          setState(() => _filters.parkingSpotsMin = null);
          _load();
        });
      }
    }
    if (_filters.maxBudget != null && _filters.maxBudget! > 0) {
      addChip(
        'Hasta ${formatCop(_filters.maxBudget!, compact: true)}',
        () {
          setState(() => _filters.maxBudget = null);
          _load();
        },
      );
    }
    return chips;
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
                  8,
                  MediaQuery.paddingOf(context).top + 8,
                  16,
                  8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        'Explorar sueños',
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: WantiColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Filtros',
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: _filters.activeCount > 0,
                        label: Text('${_filters.activeCount}'),
                        child: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Busca necesidades activas de otros usuarios. No depende de tu inventario.',
                  style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted, height: 1.35),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Vehículos'),
                      selected: _filters.assetType == 'VEHICLE',
                      onSelected: (_) => _setAssetType('VEHICLE'),
                      selectedColor: WantiColors.navy,
                      labelStyle: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: _filters.assetType == 'VEHICLE' ? Colors.white : WantiColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Inmuebles'),
                      selected: _filters.assetType == 'PROPERTY',
                      onSelected: (_) => _setAssetType('PROPERTY'),
                      selectedColor: WantiColors.navy,
                      labelStyle: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        color: _filters.assetType == 'PROPERTY' ? Colors.white : WantiColors.ink,
                      ),
                    ),
                    if (_filters.activeCount > 0) ...[
                      const Spacer(),
                      TextButton(
                        onPressed: _clearFilters,
                        child: Text(
                          'Limpiar',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: WantiColors.tealDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_filters.activeCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Wrap(children: _activeFilterChips()),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: OutlinedButton.icon(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.filter_list_rounded, size: 18),
                  label: Text(
                    _filters.isVehicle
                        ? 'Marca, modelo, año…'
                        : 'Tipo, habitaciones, estrato…',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WantiColors.tealDark,
                    side: const BorderSide(color: WantiColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                    'No hay sueños públicos con estos filtros.\n'
                    'Prueba ampliar la búsqueda o cambiar marca/modelo.',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final n = _needs[index];
                    final assetPath = NeedThumbnails.assetFor(
                      assetType: n.assetType,
                      detail: n.detail,
                    );
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: WantiColors.borderLight),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: WantiColors.surfaceSoft,
                                  child: Icon(
                                    n.assetType == 'PROPERTY'
                                        ? Icons.home_work_outlined
                                        : Icons.directions_car_outlined,
                                    color: WantiColors.inkFaint,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _subtitle(n),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        color: WantiColors.inkMuted,
                                      ),
                                    ),
                                    if ((n.description ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        n.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: WantiColors.inkFaint,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: _needs.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
