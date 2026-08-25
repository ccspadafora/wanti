import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/colombia_cities.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/vehicle_catalog_models.dart';
import '../../catalog/widgets/catalog_wizard_shell.dart';
import '../models/need_browse_filters.dart';
import '../models/preference_catalog.dart';

enum _FilterStep { category, brand, model, year, extras }

class BrowseNeedFilterWizard extends StatefulWidget {
  const BrowseNeedFilterWizard({
    super.key,
    required this.initial,
  });

  final NeedBrowseFilters initial;

  @override
  State<BrowseNeedFilterWizard> createState() => _BrowseNeedFilterWizardState();
}

class _BrowseNeedFilterWizardState extends State<BrowseNeedFilterWizard> {
  late NeedBrowseFilters _filters;
  final _selection = VehicleCatalogSelection();
  final _search = TextEditingController();
  final _budget = TextEditingController();
  final _area = TextEditingController();

  _FilterStep _step = _FilterStep.category;
  bool _listLoading = false;
  String? _listError;

  List<CatalogBrand> _brands = [];
  List<CatalogModel> _models = [];
  List<CatalogYear> _years = [];

  @override
  void initState() {
    super.initState();
    _filters = widget.initial.copy();
    if (_filters.isVehicle) {
      _selection.category = _filters.vehicleCategory ?? 'CAR';
      if (_filters.brand != null && _filters.model != null) {
        _step = _FilterStep.extras;
      } else if (_filters.vehicleCategory != null || _filters.brand != null) {
        _filters.vehicleCategory ??= _selection.category;
        _step = _FilterStep.brand;
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadBrands());
      } else {
        _step = _FilterStep.category;
      }
    } else {
      _step = _FilterStep.extras;
    }
    if (_filters.maxBudget != null && _filters.maxBudget! > 0) {
      _budget.text = formatCop(_filters.maxBudget!, compact: false);
    }
    if (_filters.areaMinSqm != null) {
      _area.text = '${_filters.areaMinSqm}';
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _budget.dispose();
    _area.dispose();
    super.dispose();
  }

  CatalogRepository get _catalog => context.read<CatalogRepository>();

  void _resetSearch() {
    if (_search.text.isNotEmpty) _search.clear();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      _brands = await _catalog.brands(
        category: _selection.category!,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    } catch (e) {
      _listError = e is ApiException ? e.message : 'Error al cargar marcas';
      _brands = [];
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<void> _loadModels() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      _models = await _catalog.models(
        brandId: _selection.brand!.id,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    } catch (e) {
      _listError = e is ApiException ? e.message : 'Error al cargar modelos';
      _models = [];
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<void> _loadYears() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      _years = await _catalog.years(modelId: _selection.model!.id);
    } catch (e) {
      _listError = e is ApiException ? e.message : 'Error al cargar años';
      _years = [];
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  void _goBack() {
    _resetSearch();
    if (!_filters.isVehicle) {
      Navigator.pop(context);
      return;
    }
    switch (_step) {
      case _FilterStep.category:
        Navigator.pop(context);
      case _FilterStep.brand:
        setState(() => _step = _FilterStep.category);
      case _FilterStep.model:
        setState(() => _step = _FilterStep.brand);
        _loadBrands();
      case _FilterStep.year:
        setState(() => _step = _FilterStep.model);
        _loadModels();
      case _FilterStep.extras:
        if (_selection.model != null) {
          setState(() => _step = _FilterStep.year);
          _loadYears();
        } else if (_selection.brand != null) {
          setState(() => _step = _FilterStep.model);
          _loadModels();
        } else {
          setState(() => _step = _FilterStep.category);
        }
    }
  }

  void _pickCategory(String category) {
    _resetSearch();
    _selection
      ..category = category
      ..clearFrom('category');
    _filters.vehicleCategory = category;
    _filters.clearVehicleIdentity();
    setState(() => _step = _FilterStep.brand);
    _loadBrands();
  }

  void _pickBrand(CatalogBrand brand) {
    _resetSearch();
    _selection
      ..brand = brand
      ..clearFrom('brand');
    _filters.brand = brand.name;
    _filters.model = null;
    _filters.year = null;
    setState(() => _step = _FilterStep.model);
    _loadModels();
  }

  void _pickModel(CatalogModel model) {
    _resetSearch();
    _selection
      ..model = model
      ..clearFrom('model');
    _filters.model = model.name;
    _filters.year = null;
    setState(() => _step = _FilterStep.year);
    _loadYears();
  }

  void _pickYear(CatalogYear year) {
    _resetSearch();
    _selection.year = year;
    _filters.year = year.year;
    setState(() => _step = _FilterStep.extras);
  }

  void _skipYear() {
    _resetSearch();
    _filters.year = null;
    setState(() => _step = _FilterStep.extras);
  }

  void _apply() {
    final budget = parseCopInput(_budget.text);
    _filters.maxBudget = budget != null && budget > 0 ? budget : null;
    final areaRaw = _area.text.trim();
    if (areaRaw.isEmpty) {
      _filters.areaMinSqm = null;
    } else {
      _filters.areaMinSqm = int.tryParse(areaRaw.replaceAll(RegExp(r'[^\d]'), ''));
    }
    Navigator.pop(context, _filters);
  }

  Widget _sectionedList({
    required List<({String label, bool popular})> items,
    required void Function(int index) onTap,
  }) {
    if (_listLoading) {
      return const Center(child: CircularProgressIndicator(color: WantiColors.teal));
    }
    if (_listError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_listError!, textAlign: TextAlign.center),
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay opciones en el catálogo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(color: WantiColors.inkMuted),
          ),
        ),
      );
    }
    final popular = <int>[];
    final all = <int>[];
    for (var i = 0; i < items.length; i++) {
      if (items[i].popular) {
        popular.add(i);
      } else {
        all.add(i);
      }
    }
    return ListView(
      children: [
        if (popular.isNotEmpty) ...[
          const CatalogSectionHeader('Más usados'),
          for (final i in popular)
            CatalogChoiceTile(label: items[i].label, onTap: () => onTap(i)),
        ],
        if (all.isNotEmpty) ...[
          const CatalogSectionHeader('Todos'),
          for (final i in all)
            CatalogChoiceTile(label: items[i].label, onTap: () => onTap(i)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_filters.isVehicle) {
      return _buildPropertyExtras();
    }
    switch (_step) {
      case _FilterStep.category:
        return _buildCategory();
      case _FilterStep.brand:
        return _buildBrand();
      case _FilterStep.model:
        return _buildModel();
      case _FilterStep.year:
        return _buildYear();
      case _FilterStep.extras:
        return _buildVehicleExtras();
    }
  }

  Widget _buildCategory() {
    return CatalogWizardShell(
      title: 'Filtrar sueños',
      headline: '¿Qué tipo de vehículo buscas?',
      subtitle: 'Elige la categoría para refinar la búsqueda.',
      onBack: _goBack,
      child: CatalogCategoryPicker(onSelected: _pickCategory),
    );
  }

  Widget _buildBrand() {
    return CatalogWizardShell(
      title: 'Marca',
      question: '¿Marca?',
      searchController: _search,
      onSearchChanged: (_) => _loadBrands(),
      onBack: _goBack,
      child: _sectionedList(
        items: [for (final b in _brands) (label: b.name, popular: b.isPopular)],
        onTap: (i) => _pickBrand(_brands[i]),
      ),
    );
  }

  Widget _buildModel() {
    final crumbs = [
      if (_selection.brand != null) _selection.brand!.name,
      'Modelo',
    ];
    return CatalogWizardShell(
      title: 'Modelo',
      question: '¿Modelo?',
      breadcrumb: CatalogBreadcrumb(parts: crumbs),
      searchController: _search,
      onSearchChanged: (_) => _loadModels(),
      onBack: _goBack,
      child: _sectionedList(
        items: [for (final m in _models) (label: m.name, popular: m.isPopular)],
        onTap: (i) => _pickModel(_models[i]),
      ),
    );
  }

  Widget _buildYear() {
    final crumbs = [
      if (_selection.brand != null) _selection.brand!.name,
      if (_selection.model != null) _selection.model!.name,
      'Año',
    ];
    return CatalogWizardShell(
      title: 'Año',
      question: '¿Año?',
      breadcrumb: CatalogBreadcrumb(parts: crumbs),
      onBack: _goBack,
      bottom: TextButton(
        onPressed: _skipYear,
        child: Text(
          'Cualquier año',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: WantiColors.tealDark),
        ),
      ),
      child: _sectionedList(
        items: [for (final y in _years) (label: '${y.year}', popular: y.isPopular)],
        onTap: (i) => _pickYear(_years[i]),
      ),
    );
  }

  Widget _buildVehicleExtras() {
    final crumbs = <String>[
      if (_selection.brand != null) _selection.brand!.name,
      if (_selection.model != null) _selection.model!.name,
      if (_filters.year != null) '${_filters.year}',
      'Más filtros',
    ];
    return CatalogWizardShell(
      title: 'Filtros',
      headline: 'Refina tu búsqueda',
      subtitle: 'Ubicación, características y presupuesto máximo del comprador.',
      breadcrumb: crumbs.isNotEmpty ? CatalogBreadcrumb(parts: crumbs) : null,
      onBack: _goBack,
      bottom: WantiButton(label: 'Aplicar filtros', onPressed: _apply),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          WantiDropdown<String>(
            label: 'Ciudad',
            value: _filters.city,
            hint: 'Todas',
            items: ColombiaCities.all
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _filters.city = v),
          ),
          const SizedBox(height: 12),
          WantiCopField(
            label: 'Presupuesto máximo del comprador',
            controller: _budget,
            hint: r'Ej. $75.000.000',
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyExtras() {
    final pType = _filters.propertyType;
    final showBedrooms = pType == null || {'APTO', 'CASA'}.contains(pType);
    final showBathrooms =
        pType == null || {'APTO', 'CASA', 'LOCAL', 'BODEGA', 'CONSULTORIO'}.contains(pType);
    final showStratumParking =
        pType == null || {'APTO', 'CASA', 'LOCAL', 'CONSULTORIO'}.contains(pType);

    return CatalogWizardShell(
      title: 'Filtrar sueños',
      headline: 'Filtros de inmuebles',
      subtitle: 'Solo criterios inmobiliarios: tipo, arriendo/venta, tamaño y presupuesto.',
      onBack: () => Navigator.pop(context),
      bottom: WantiButton(label: 'Aplicar filtros', onPressed: _apply),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          WantiDropdown<String>(
            label: 'Tipo de inmueble',
            value: _filters.propertyType,
            hint: 'Todos',
            items: PreferenceCatalog.propertyTypes
                .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                .toList(),
            onChanged: (v) => setState(() {
              _filters.propertyType = v;
              // Limpia campos que no aplican al tipo elegido
              if (v != null && !{'APTO', 'CASA'}.contains(v)) {
                _filters.bedroomsMin = null;
              }
              if (v != null &&
                  !{'APTO', 'CASA', 'LOCAL', 'BODEGA', 'CONSULTORIO'}.contains(v)) {
                _filters.bathroomsMin = null;
              }
              if (v != null &&
                  !{'APTO', 'CASA', 'LOCAL', 'CONSULTORIO'}.contains(v)) {
                _filters.socioeconomicStratum = null;
                _filters.parkingSpotsMin = null;
              }
            }),
          ),
          const SizedBox(height: 12),
          WantiDropdown<String>(
            label: 'Arriendo / venta',
            value: _filters.listingIntent,
            hint: 'Todos',
            items: const [
              DropdownMenuItem(value: 'SALE', child: Text('Venta')),
              DropdownMenuItem(value: 'RENT', child: Text('Arriendo')),
            ],
            onChanged: (v) => setState(() => _filters.listingIntent = v),
          ),
          const SizedBox(height: 12),
          WantiDropdown<String>(
            label: 'Ciudad',
            value: _filters.city,
            hint: 'Todas',
            items: ColombiaCities.all
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _filters.city = v),
          ),
          const SizedBox(height: 12),
          WantiField(
            label: 'Área mínima (m²)',
            controller: _area,
            keyboardType: TextInputType.number,
            hint: 'Ej. 80',
          ),
          if (showBedrooms) ...[
            const SizedBox(height: 12),
            WantiDropdown<int>(
              label: 'Habitaciones (mín.)',
              value: _filters.bedroomsMin,
              hint: 'Cualquiera',
              items: [1, 2, 3, 4, 5, 6]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n+')))
                  .toList(),
              onChanged: (v) => setState(() => _filters.bedroomsMin = v),
            ),
          ],
          if (showBathrooms) ...[
            const SizedBox(height: 12),
            WantiDropdown<int>(
              label: 'Baños (mín.)',
              value: _filters.bathroomsMin,
              hint: 'Cualquiera',
              items: [1, 2, 3, 4, 5]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n+')))
                  .toList(),
              onChanged: (v) => setState(() => _filters.bathroomsMin = v),
            ),
          ],
          if (showStratumParking) ...[
            const SizedBox(height: 12),
            WantiDropdown<int>(
              label: 'Estrato',
              value: _filters.socioeconomicStratum,
              hint: 'Cualquiera',
              items: [1, 2, 3, 4, 5, 6]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
              onChanged: (v) => setState(() => _filters.socioeconomicStratum = v),
            ),
            const SizedBox(height: 12),
            WantiDropdown<int>(
              label: 'Parqueaderos (mín.)',
              value: _filters.parkingSpotsMin,
              hint: 'Cualquiera',
              items: [1, 2, 3, 4]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n+')))
                  .toList(),
              onChanged: (v) => setState(() => _filters.parkingSpotsMin = v),
            ),
          ],
          const SizedBox(height: 12),
          WantiCopField(
            label: 'Presupuesto máximo del comprador',
            controller: _budget,
            hint: r'Ej. $500.000.000',
          ),
        ],
      ),
    );
  }
}
