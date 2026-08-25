import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/app_mode_controller.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/models/vehicle_catalog_models.dart';
import '../../catalog/widgets/catalog_wizard_shell.dart';
import '../../geo/data/geo_repository.dart';
import '../../geo/models/geo_models.dart';
import '../../geo/widgets/city_multi_select_field.dart';
import '../../geo/widgets/location_cascade_picker.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../data/needs_repository.dart';
import '../models/need_draft.dart';
import '../models/preference_catalog.dart';

enum _NeedStep {
  assetType,
  vehicleCategory,
  brand,
  model,
  year,
  version,
  details,
  description,
  summary,
}

class NewNeedFlowScreen extends StatefulWidget {
  const NewNeedFlowScreen({super.key, this.initialAssetType});

  final String? initialAssetType;

  @override
  State<NewNeedFlowScreen> createState() => _NewNeedFlowScreenState();
}

class _NewNeedFlowScreenState extends State<NewNeedFlowScreen> {
  late final NeedDraft _draft = NeedDraft();
  final _selection = VehicleCatalogSelection();
  final _budget = TextEditingController();
  final _mileageMax = TextEditingController();
  final _description = TextEditingController();
  final _tradeIn = TextEditingController();
  final _propertyTitle = TextEditingController();
  final _search = TextEditingController();

  _NeedStep _step = _NeedStep.assetType;
  bool _loading = false;
  bool _listLoading = false;
  String? _listError;
  List<GeoCity> _travelOptions = [];
  bool _loadingTravel = false;

  List<CatalogBrand> _brands = [];
  List<CatalogModel> _models = [];
  List<CatalogYear> _years = [];
  List<CatalogVersion> _versions = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAssetType;
    if (initial == 'VEHICLE' || initial == 'PROPERTY') {
      _draft.assetType = initial!;
      _step = initial == 'VEHICLE' ? _NeedStep.vehicleCategory : _NeedStep.details;
      if (_draft.isVehicle) {
        _draft.syncVehicleCriteriaSlots();
      } else {
        _draft.syncPropertyCriteriaSlots();
      }
    }
  }

  @override
  void dispose() {
    _budget.dispose();
    _mileageMax.dispose();
    _description.dispose();
    _tradeIn.dispose();
    _propertyTitle.dispose();
    _search.dispose();
    super.dispose();
  }

  CatalogRepository get _catalog => context.read<CatalogRepository>();

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _resetSearch() {
    if (_search.text.isNotEmpty) {
      _search.clear();
    }
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
      _listError = e is ApiException ? e.message : 'No se pudieron cargar las marcas';
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
      _listError = e is ApiException ? e.message : 'No se pudieron cargar los modelos';
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
      _listError = e is ApiException ? e.message : 'No se pudieron cargar los años';
      _years = [];
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<void> _loadVersions() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });
    try {
      _versions = await _catalog.versions(
        modelId: _selection.model!.id,
        year: _selection.year!.year,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    } catch (e) {
      _listError = e is ApiException ? e.message : 'No se pudieron cargar las versiones';
      _versions = [];
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  void _goBack() {
    _resetSearch();
    switch (_step) {
      case _NeedStep.assetType:
        context.pop();
      case _NeedStep.vehicleCategory:
        setState(() => _step = _NeedStep.assetType);
      case _NeedStep.brand:
        setState(() => _step = _NeedStep.vehicleCategory);
      case _NeedStep.model:
        setState(() => _step = _NeedStep.brand);
        _loadBrands();
      case _NeedStep.year:
        setState(() => _step = _NeedStep.model);
        _loadModels();
      case _NeedStep.version:
        setState(() => _step = _NeedStep.year);
        _loadYears();
      case _NeedStep.details:
        if (_draft.isVehicle) {
          setState(() => _step = _NeedStep.version);
          _loadVersions();
        } else {
          setState(() => _step = _NeedStep.assetType);
        }
      case _NeedStep.description:
        setState(() => _step = _NeedStep.details);
      case _NeedStep.summary:
        setState(() => _step = _NeedStep.description);
    }
  }

  void _pickAsset(String asset) {
    _draft.assetType = asset;
    _draft.paymentTypes = PreferenceCatalog.sanitizePaymentTypes(asset, _draft.paymentTypes);
    if (asset == 'VEHICLE') {
      _draft.syncVehicleCriteriaSlots();
      setState(() => _step = _NeedStep.vehicleCategory);
    } else {
      _draft.syncPropertyCriteriaSlots();
      setState(() => _step = _NeedStep.details);
    }
  }

  void _pickCategory(String category) {
    _resetSearch();
    _selection
      ..category = category
      ..clearFrom('category');
    _draft.vehicleCategory = category;
    _draft.syncVehicleCriteriaSlots();
    setState(() => _step = _NeedStep.brand);
    _loadBrands();
  }

  void _pickBrand(CatalogBrand brand) {
    _resetSearch();
    _selection
      ..brand = brand
      ..clearFrom('brand');
    setState(() => _step = _NeedStep.model);
    _loadModels();
  }

  void _pickModel(CatalogModel model) {
    _resetSearch();
    _selection
      ..model = model
      ..clearFrom('model');
    setState(() => _step = _NeedStep.year);
    _loadYears();
  }

  void _pickYear(CatalogYear year) {
    _resetSearch();
    _selection
      ..year = year
      ..clearFrom('year');
    setState(() => _step = _NeedStep.version);
    _loadVersions();
  }

  Future<void> _pickVersion(CatalogVersion version) async {
    _selection.version = version;
    _draft
      ..brand = _selection.brand!.name
      ..model = _selection.model!.name
      ..line = version.name
      ..year = _selection.year!.year
      ..catalogVersionId = version.id
      ..vehicleCategory = _selection.category!
      ..versionSpecs = null;
    setState(() => _step = _NeedStep.details);
  }

  CatalogStepProgress _progress(_NeedStep step) {
    if (!_draft.isVehicle) {
      const map = {
        _NeedStep.assetType: ('Tipo', 1),
        _NeedStep.details: ('Detalles', 2),
        _NeedStep.description: ('Descripción', 3),
        _NeedStep.summary: ('Resumen', 4),
      };
      final info = map[step];
      if (info != null) {
        return CatalogStepProgress(current: info.$2, total: 4, stepLabel: info.$1);
      }
    }
    const vehicleSteps = [
      _NeedStep.assetType,
      _NeedStep.vehicleCategory,
      _NeedStep.brand,
      _NeedStep.model,
      _NeedStep.year,
      _NeedStep.version,
      _NeedStep.details,
      _NeedStep.description,
      _NeedStep.summary,
    ];
    const labels = {
      _NeedStep.assetType: 'Tipo',
      _NeedStep.vehicleCategory: 'Categoría',
      _NeedStep.brand: 'Marca',
      _NeedStep.model: 'Modelo',
      _NeedStep.year: 'Año',
      _NeedStep.version: 'Versión',
      _NeedStep.details: 'Detalles',
      _NeedStep.description: 'Descripción',
      _NeedStep.summary: 'Resumen',
    };
    final idx = vehicleSteps.indexOf(step);
    return CatalogStepProgress(
      current: idx >= 0 ? idx + 1 : 1,
      total: 9,
      stepLabel: labels[step] ?? '',
    );
  }

  bool _validateDetails() {
    final value = parseCopInput(_budget.text);
    if (value == null || value <= 0) {
      _toast('Ingresa un presupuesto máximo válido');
      return false;
    }
    if (_draft.city.isEmpty || _draft.department.isEmpty || _draft.geoCityId.isEmpty) {
      _toast('Selecciona departamento y ciudad');
      return false;
    }
    if (_draft.paymentTypes.isEmpty) {
      _toast('Selecciona al menos un tipo de pago');
      return false;
    }
    if (_draft.acceptsTradeIn &&
        (_draft.tradeInInventoryId == null || _draft.tradeInInventoryId!.isEmpty)) {
      _toast('Selecciona o crea un inventario para la permuta');
      return false;
    }
    if (_draft.acceptsTradeIn && _tradeIn.text.trim().isNotEmpty) {
      _draft.tradeInDescription = _tradeIn.text.trim();
    }
    if (!_draft.isVehicle && _draft.propertyType.isEmpty) {
      _toast('Selecciona el tipo de inmueble');
      return false;
    }
    if (_draft.willingToTravel && _draft.travelCities.isEmpty) {
      _toast('Selecciona al menos una ciudad adicional o desactiva el desplazamiento');
      return false;
    }
    if (_draft.isVehicle) {
      _draft.syncVehicleCriteriaSlots();
      final mileageRaw = _mileageMax.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      if (mileageRaw.isNotEmpty) {
        final km = int.tryParse(mileageRaw);
        if (km == null || km < 0) {
          _toast('Ingresa un kilometraje máximo válido');
          return false;
        }
        _draft.setCriterionValue('mileage_max_km', km);
      } else {
        _draft.criteria['mileage_max_km']
          ?..value = null
          ..displayValue = 'Sin definir';
      }
    }
    _draft
      ..budgetMaxCop = value
      ..tradeInDescription = _tradeIn.text.trim()
      ..propertyTitle = _propertyTitle.text.trim();
    return true;
  }

  Future<void> _pickTradeInInventory() async {
    final repo = context.read<InventoryRepository>();
    List<InventoryItemModel> items = [];
    try {
      items = await repo.listMine(status: 'AVAILABLE');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
      return;
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WantiColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Inventario para permuta',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona un activo existente o crea uno nuevo.',
                  style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Aún no tienes inventario disponible.',
                      style: GoogleFonts.nunito(color: WantiColors.inkMuted),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.title,
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item.city} · ${formatCop(item.priceCop)}',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                          onTap: () => Navigator.pop(ctx, item),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                WantiButton(
                  label: 'Crear inventario nuevo',
                  onPressed: () => Navigator.pop(ctx, '__create__'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    if (result == '__create__') {
      final createdId = await context.push<String>('/inventory/new?returnResult=1');
      if (!mounted || createdId == null || createdId.isEmpty) return;
      try {
        final created = await repo.detail(createdId);
        if (!mounted) return;
        setState(() {
          _draft
            ..tradeInInventoryId = created.id
            ..tradeInInventoryTitle = created.title;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        _toast(e.message);
      }
      return;
    }

    if (result is InventoryItemModel) {
      setState(() {
        _draft
          ..tradeInInventoryId = result.id
          ..tradeInInventoryTitle = result.title;
      });
    }
  }

  Future<void> _loadTravelOptions() async {
    setState(() => _loadingTravel = true);
    try {
      final cities = await context.read<GeoRepository>().cities();
      if (!mounted) return;
      setState(() {
        _travelOptions = cities
            .where((c) => c.id != _draft.geoCityId)
            .toList();
        _loadingTravel = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingTravel = false);
      _toast(e.message);
    }
  }

  void _confirmDescription() {
    _draft.description = _description.text.trim();
    setState(() => _step = _NeedStep.summary);
  }

  Future<void> _publish() async {
    if (_step != _NeedStep.summary) return;
    setState(() => _loading = true);
    try {
      final coords = [
        _draft.latitude ?? coordsForCity(_draft.city)[0],
        _draft.longitude ?? coordsForCity(_draft.city)[1],
      ];
      final repo = context.read<NeedsRepository>();
      final created = await repo.create(
        _draft.toCreatePayload(latitude: coords[0], longitude: coords[1]),
      );
      await repo.publish(created.id);
      if (!mounted) return;
      context.read<AppModeController>().bumpCatalog();
      _toast('¡Necesidad publicada!');
      context.go('/home');
    } catch (e) {
      _toast(e is ApiException ? e.message : 'No se pudo publicar');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _NeedStep.assetType:
        return _buildAssetType();
      case _NeedStep.vehicleCategory:
        return _buildCategory();
      case _NeedStep.brand:
        return _buildBrand();
      case _NeedStep.model:
        return _buildModel();
      case _NeedStep.year:
        return _buildYear();
      case _NeedStep.version:
        return _buildVersion();
      case _NeedStep.details:
        return _buildDetails();
      case _NeedStep.description:
        return _buildDescription();
      case _NeedStep.summary:
        return _buildSummary();
    }
  }

  Widget _buildAssetType() {
    return CatalogWizardShell(
      title: 'Publicar',
      headline: '¡Hola! Antes que nada cuéntanos, ¿qué vas a publicar?',
      subtitle: 'Elige si buscas un vehículo o un inmueble para continuar con tu necesidad.',
      progress: _progress(_NeedStep.assetType),
      onBack: () => context.pop(),
      child: CatalogBinaryPicker(
        firstLabel: 'Vehículos',
        firstSubtitle: 'Carros, camionetas, motos…',
        firstIcon: Icons.directions_car_outlined,
        onFirst: () => _pickAsset('VEHICLE'),
        secondLabel: 'Inmuebles',
        secondSubtitle: 'Apartamentos, casas, locales…',
        secondIcon: Icons.home_work_outlined,
        onSecond: () => _pickAsset('PROPERTY'),
      ),
    );
  }

  Widget _buildCategory() {
    return CatalogWizardShell(
      title: 'Categoría',
      headline: 'Vas a publicar tu necesidad gratis.',
      subtitle: 'Primero, elige la categoría del vehículo que buscas.',
      progress: _progress(_NeedStep.vehicleCategory),
      onBack: _goBack,
      child: CatalogCategoryPicker(onSelected: _pickCategory),
    );
  }

  Widget _sectionedList({
    required List<({String label, bool popular})> items,
    required void Function(int index) onTap,
  }) {
    if (_listLoading) {
      return const Center(child: CircularProgressIndicator(color: WantiColors.teal));
    }
    if (_listError != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_listError!)));
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay opciones en el catálogo para esta selección.\n'
            'Puedes agregarlas desde el panel admin.',
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

  Widget _buildBrand() {
    return CatalogWizardShell(
      title: 'Marca',
      headline: 'Completa estos datos con las especificaciones del fabricante',
      subtitle: 'Selecciona la marca del vehículo que buscas.',
      question: '¿Marca?',
      progress: _progress(_NeedStep.brand),
      breadcrumb: CatalogBreadcrumb(
        parts: [
          PreferenceCatalog.vehicleCategoryLabel(_selection.category ?? 'CAR'),
          'Marca',
        ],
      ),
      searchController: _search,
      onSearchChanged: (_) => _loadBrands(),
      onBack: _goBack,
      child: _sectionedList(
        items: _brands.map((b) => (label: b.name, popular: b.isPopular)).toList(),
        onTap: (i) => _pickBrand(_brands[i]),
      ),
    );
  }

  Widget _buildModel() {
    return CatalogWizardShell(
      title: 'Modelo',
      headline: 'Completa estos datos con las especificaciones del fabricante',
      subtitle: 'Elige el modelo de ${_selection.brand!.name}.',
      question: '¿Modelo?',
      progress: _progress(_NeedStep.model),
      breadcrumb: CatalogBreadcrumb(
        parts: [_selection.brand!.name, 'Modelo'],
        onTapPart: (_) {
          setState(() => _step = _NeedStep.brand);
          _loadBrands();
        },
      ),
      searchController: _search,
      onSearchChanged: (_) => _loadModels(),
      onBack: _goBack,
      child: _sectionedList(
        items: _models.map((m) => (label: m.name, popular: m.isPopular)).toList(),
        onTap: (i) => _pickModel(_models[i]),
      ),
    );
  }

  Widget _buildYear() {
    return CatalogWizardShell(
      title: 'Año',
      headline: 'Completa estos datos con las especificaciones del fabricante',
      subtitle: 'Indica el año del ${_selection.model!.name} que te interesa.',
      question: '¿Año?',
      progress: _progress(_NeedStep.year),
      breadcrumb: CatalogBreadcrumb(
        parts: [_selection.brand!.name, _selection.model!.name, 'Año'],
        onTapPart: (i) {
          if (i == 0) {
            setState(() => _step = _NeedStep.brand);
            _loadBrands();
          } else {
            setState(() => _step = _NeedStep.model);
            _loadModels();
          }
        },
      ),
      onBack: _goBack,
      child: _sectionedList(
        items: _years.map((y) => (label: '${y.year}', popular: y.isPopular)).toList(),
        onTap: (i) => _pickYear(_years[i]),
      ),
    );
  }

  Widget _buildVersion() {
    return CatalogWizardShell(
      title: 'Versión',
      headline: 'Completa estos datos con las especificaciones del fabricante',
      subtitle: 'Elige la versión exacta para ${_selection.year!.year}.',
      question: '¿Versión?',
      progress: _progress(_NeedStep.version),
      breadcrumb: CatalogBreadcrumb(
        parts: [
          _selection.brand!.name,
          _selection.model!.name,
          '${_selection.year!.year}',
          'Versión',
        ],
        onTapPart: (i) {
          if (i == 0) {
            setState(() => _step = _NeedStep.brand);
            _loadBrands();
          } else if (i == 1) {
            setState(() => _step = _NeedStep.model);
            _loadModels();
          } else {
            setState(() => _step = _NeedStep.year);
            _loadYears();
          }
        },
      ),
      searchController: _search,
      onSearchChanged: (_) => _loadVersions(),
      onBack: _goBack,
      child: _sectionedList(
        items: _versions.map((v) => (label: v.name, popular: false)).toList(),
        onTap: (i) => _pickVersion(_versions[i]),
      ),
    );
  }

  Widget _buildDetails() {
    return CatalogWizardShell(
      title: _draft.isVehicle ? 'Tu necesidad' : 'Inmueble',
      headline: _draft.isVehicle
          ? 'Indica el presupuesto, ciudad y forma de pago'
          : 'Cuéntanos qué inmueble estás buscando',
      subtitle: _draft.isVehicle
          ? 'Estos datos ayudan a los vendedores a encontrarte con ofertas relevantes.'
          : 'Selecciona el tipo de inmueble y tu presupuesto máximo.',
      progress: _progress(_NeedStep.details),
      onBack: _goBack,
      bottom: WantiButton(
        label: 'Continuar',
        onPressed: () {
          if (_validateDetails()) setState(() => _step = _NeedStep.description);
        },
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_draft.isVehicle) ...[
            Text(
              _selection.summaryLabel,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: WantiColors.tealDark,
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text('Tipo de inmueble', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PreferenceCatalog.propertyTypes.map((t) {
                final selected = _draft.propertyType == t.$1;
                return ChoiceChip(
                  label: Text(t.$2),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _draft.propertyType = t.$1;
                    _draft.syncPropertyCriteriaSlots();
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          WantiCopField(
            label: 'Presupuesto máximo (COP)',
            controller: _budget,
            hint: r'Ej. $75.000.000',
          ),
          if (_draft.isVehicle) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _mileageMax,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kilometraje máximo (km)',
                hintText: 'Ej. 80000',
              ),
            ),
          ],
          const SizedBox(height: 12),
          LocationCascadePicker(
            initialDepartment: _draft.department.isEmpty ? null : _draft.department,
            initialCity: _draft.city.isEmpty ? null : _draft.city,
            initialGeoCityId: _draft.geoCityId.isEmpty ? null : _draft.geoCityId,
            onChanged: ({
              required department,
              required city,
              required geoCityId,
              latitude,
              longitude,
            }) {
              setState(() {
                _draft
                  ..department = department
                  ..city = city
                  ..geoCityId = geoCityId
                  ..latitude = latitude
                  ..longitude = longitude;
                _draft.travelCities.removeWhere((t) => t.id == geoCityId);
              });
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '¿Estás dispuesto a desplazarte a otra ciudad?',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            value: _draft.willingToTravel,
            activeThumbColor: WantiColors.teal,
            onChanged: (v) {
              setState(() {
                _draft.willingToTravel = v;
                if (!v) {
                  _draft.travelCities.clear();
                } else if (_travelOptions.isEmpty) {
                  _loadTravelOptions();
                }
              });
            },
          ),
          if (_draft.willingToTravel) ...[
            const SizedBox(height: 4),
            CityMultiSelectField(
              cities: _travelOptions,
              selectedIds: _draft.travelCities.map((c) => c.id).toSet(),
              excludeCityId: _draft.geoCityId,
              loading: _loadingTravel,
              label: 'Ciudades de desplazamiento',
              hint: 'Selecciona una o más ciudades',
              onChanged: (selected) {
                setState(() {
                  _draft.travelCities
                    ..clear()
                    ..addAll(
                      selected.map(
                        (c) => (
                          id: c.id,
                          name: c.name,
                          department: c.departmentName,
                        ),
                      ),
                    );
                });
              },
            ),
          ],
          const SizedBox(height: 12),
          Text('Formas de pago', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in PreferenceCatalog.paymentOptionsFor(_draft.assetType))
                FilterChip(
                  label: Text(p.$2),
                  selected: _draft.paymentTypes.contains(p.$1),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _draft.paymentTypes = PreferenceCatalog.sanitizePaymentTypes(
                          _draft.assetType,
                          [..._draft.paymentTypes, p.$1],
                        );
                      } else {
                        _draft.paymentTypes = PreferenceCatalog.sanitizePaymentTypes(
                          _draft.assetType,
                          _draft.paymentTypes.where((e) => e != p.$1).toList(),
                        );
                        if (p.$1 == 'TRADE_IN') {
                          _draft
                            ..tradeInInventoryId = null
                            ..tradeInInventoryTitle = null;
                        }
                      }
                    });
                  },
                ),
            ],
          ),
          if (_draft.acceptsTradeIn) ...[
            const SizedBox(height: 12),
            Text('Permuta', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickTradeInInventory,
              icon: const Icon(Icons.swap_horiz),
              label: Text(
                _draft.tradeInInventoryTitle?.isNotEmpty == true
                    ? _draft.tradeInInventoryTitle!
                    : 'Seleccionar o crear inventario',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              ),
            ),
            if (_draft.tradeInInventoryId != null)
              TextButton(
                onPressed: () => setState(() {
                  _draft
                    ..tradeInInventoryId = null
                    ..tradeInInventoryTitle = null;
                }),
                child: Text(
                  'Quitar permuta asociada',
                  style: GoogleFonts.nunito(color: WantiColors.inkMuted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _tradeIn,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas de la permuta (opcional)',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription() {
    const maxChars = 5000;
    final count = _description.text.characters.length;
    return CatalogWizardShell(
      title: 'Descripción',
      headline: _draft.isVehicle
          ? 'Detalla las principales características del vehículo que buscas'
          : 'Detalla las principales características del inmueble que buscas',
      subtitle: 'Este comentario ayuda a los vendedores a entender mejor tu deseo.',
      progress: _progress(_NeedStep.description),
      onBack: _goBack,
      bottom: WantiButton(
        label: 'Confirmar',
        onPressed: _confirmDescription,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_draft.isVehicle) ...[
            Text(
              _draft.title,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: WantiColors.tealDark,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Descripción (opcional)',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WantiColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLines: 8,
            maxLength: maxChars,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Escribe aquí más información para las personas interesadas.',
              alignLabelWithHint: true,
              counterText: '$count / $maxChars',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: WantiColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: WantiColors.teal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WantiColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: WantiColors.teal, width: 3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20, color: WantiColors.tealDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No incluyas datos de contacto, e-mail, teléfono, direcciones ni enlaces a redes sociales.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      height: 1.35,
                      color: WantiColors.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return CatalogWizardShell(
      title: 'Resumen',
      headline: 'Revisa tu necesidad antes de publicar',
      subtitle: 'Puedes editar cualquier dato o cambiar el vehículo antes de finalizar.',
      progress: _progress(_NeedStep.summary),
      onBack: _goBack,
      bottom: Column(
        children: [
          WantiButton(
            label: _loading ? 'Publicando…' : 'Finalizar y publicar',
            onPressed: _loading ? null : _publish,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _step = _NeedStep.description),
            child: Text(
              'Editar descripción',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: WantiColors.tealDark),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _step = _NeedStep.details),
            child: Text(
              'Editar datos',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: WantiColors.tealDark),
            ),
          ),
          if (_draft.isVehicle)
            TextButton(
              onPressed: () {
                setState(() => _step = _NeedStep.brand);
                _loadBrands();
              },
              child: Text(
                'Cambiar vehículo',
                style: GoogleFonts.nunito(color: WantiColors.inkMuted),
              ),
            ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _summaryRow('Título', _draft.title),
          _summaryRow('Tipo', _draft.isVehicle ? 'Vehículo' : 'Inmueble'),
          if (_draft.isVehicle) ...[
            _summaryRow(
              'Categoría',
              PreferenceCatalog.vehicleCategoryLabel(_draft.vehicleCategory),
            ),
            _summaryRow('Marca', _draft.brand),
            _summaryRow('Modelo', _draft.model),
            _summaryRow('Referencia', _draft.line),
            _summaryRow('Año', '${_draft.year ?? ''}'),
          ] else
            _summaryRow('Inmueble', PreferenceCatalog.propertyTypeLabel(_draft.propertyType)),
          _summaryRow('Presupuesto', formatCop(_draft.budgetMaxCop)),
          if (_draft.isVehicle && _draft.criteria['mileage_max_km']?.value != null)
            _summaryRow('Kilometraje máx.', _draft.criteria['mileage_max_km']!.displayValue),
          _summaryRow('Ubicación', '${_draft.department} · ${_draft.city}'),
          if (_draft.willingToTravel)
            _summaryRow(
              'Desplazamiento',
              _draft.travelCities.map((c) => c.name).join(', '),
            ),
          _summaryRow('Pago', _draft.paymentTypes.join(', ')),
          if (_draft.acceptsTradeIn)
            _summaryRow(
              'Permuta',
              _draft.tradeInInventoryTitle ?? _draft.tradeInInventoryId ?? '',
            ),
          if (_draft.description.isNotEmpty) _summaryRow('Descripción', _draft.description),
        ],
      ),
    );
  }

  Widget _summaryRow(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WantiColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: GoogleFonts.nunito(color: WantiColors.inkMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(v, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: WantiColors.ink)),
          ),
        ],
      ),
    );
  }
}
