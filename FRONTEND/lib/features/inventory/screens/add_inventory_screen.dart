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
import '../../geo/widgets/location_cascade_picker.dart';
import '../../needs/models/need_draft.dart';
import '../../needs/models/preference_catalog.dart';
import '../data/inventory_repository.dart';

enum _InvStep {
  assetType,
  vehicleCategory,
  brand,
  model,
  year,
  version,
  mileage,
  details,
  summary,
}

class AddInventoryScreen extends StatefulWidget {
  const AddInventoryScreen({super.key, this.returnResult = false});

  /// When true, pops with the created inventory id instead of just closing.
  final bool returnResult;

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _selection = VehicleCatalogSelection();
  final _price = TextEditingController();
  final _mileage = TextEditingController();
  final _description = TextEditingController();
  final _title = TextEditingController();
  final _bedrooms = TextEditingController();
  final _bathrooms = TextEditingController();
  final _area = TextEditingController();
  final _search = TextEditingController();

  _InvStep _step = _InvStep.assetType;
  String _asset = 'VEHICLE';
  String _propertyType = 'APTO';
  String _department = '';
  String _city = '';
  String _geoCityId = '';
  double? _latitude;
  double? _longitude;
  bool _loading = false;
  bool _listLoading = false;
  String? _listError;

  List<CatalogBrand> _brands = [];
  List<CatalogModel> _models = [];
  List<CatalogYear> _years = [];
  List<CatalogVersion> _versions = [];

  @override
  void dispose() {
    _price.dispose();
    _mileage.dispose();
    _description.dispose();
    _title.dispose();
    _bedrooms.dispose();
    _bathrooms.dispose();
    _area.dispose();
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
      _listError = e is ApiException ? e.message : 'Error al cargar versiones';
      _versions = [];
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  void _goBack() {
    _resetSearch();
    switch (_step) {
      case _InvStep.assetType:
        context.pop();
      case _InvStep.vehicleCategory:
        setState(() => _step = _InvStep.assetType);
      case _InvStep.brand:
        setState(() => _step = _InvStep.vehicleCategory);
      case _InvStep.model:
        setState(() => _step = _InvStep.brand);
        _loadBrands();
      case _InvStep.year:
        setState(() => _step = _InvStep.model);
        _loadModels();
      case _InvStep.version:
        setState(() => _step = _InvStep.year);
        _loadYears();
      case _InvStep.mileage:
        setState(() => _step = _InvStep.version);
        _loadVersions();
      case _InvStep.details:
        if (_asset == 'VEHICLE') {
          setState(() => _step = _InvStep.mileage);
        } else {
          setState(() => _step = _InvStep.assetType);
        }
      case _InvStep.summary:
        setState(() => _step = _InvStep.details);
    }
  }

  void _pickAsset(String asset) {
    _asset = asset;
    setState(() {
      _step = asset == 'VEHICLE' ? _InvStep.vehicleCategory : _InvStep.details;
    });
  }

  void _pickCategory(String category) {
    _resetSearch();
    _selection
      ..category = category
      ..clearFrom('category');
    setState(() => _step = _InvStep.brand);
    _loadBrands();
  }

  void _pickBrand(CatalogBrand brand) {
    _resetSearch();
    _selection
      ..brand = brand
      ..clearFrom('brand');
    setState(() => _step = _InvStep.model);
    _loadModels();
  }

  void _pickModel(CatalogModel model) {
    _resetSearch();
    _selection
      ..model = model
      ..clearFrom('model');
    setState(() => _step = _InvStep.year);
    _loadYears();
  }

  void _pickYear(CatalogYear year) {
    _resetSearch();
    _selection
      ..year = year
      ..clearFrom('year');
    setState(() => _step = _InvStep.version);
    _loadVersions();
  }

  void _pickVersion(CatalogVersion version) {
    _selection.version = version;
    setState(() => _step = _InvStep.mileage);
  }

  bool _validateMileage() {
    final km = int.tryParse(_mileage.text.trim().replaceAll(RegExp(r'[^\d]'), ''));
    if (km == null || km < 0) {
      _toast('Indica el kilometraje');
      return false;
    }
    return true;
  }

  bool _validateDetails() {
    final price = parseCopInput(_price.text);
    if (price == null || price <= 0) {
      _toast('Ingresa un precio válido');
      return false;
    }
    if (_city.isEmpty || _department.isEmpty || _geoCityId.isEmpty) {
      _toast('Selecciona departamento y ciudad');
      return false;
    }
    return true;
  }

  CatalogStepProgress _progress(_InvStep step) {
    if (_asset != 'VEHICLE') {
      const map = {
        _InvStep.assetType: ('Tipo', 1),
        _InvStep.details: ('Detalles', 2),
        _InvStep.summary: ('Resumen', 3),
      };
      final info = map[step];
      if (info != null) {
        return CatalogStepProgress(current: info.$2, total: 3, stepLabel: info.$1);
      }
    }
    const steps = [
      _InvStep.assetType,
      _InvStep.vehicleCategory,
      _InvStep.brand,
      _InvStep.model,
      _InvStep.year,
      _InvStep.version,
      _InvStep.mileage,
      _InvStep.details,
      _InvStep.summary,
    ];
    const labels = {
      _InvStep.assetType: 'Tipo',
      _InvStep.vehicleCategory: 'Categoría',
      _InvStep.brand: 'Marca',
      _InvStep.model: 'Modelo',
      _InvStep.year: 'Año',
      _InvStep.version: 'Versión',
      _InvStep.mileage: 'Kilometraje',
      _InvStep.details: 'Detalles',
      _InvStep.summary: 'Resumen',
    };
    final idx = steps.indexOf(step);
    return CatalogStepProgress(
      current: idx >= 0 ? idx + 1 : 1,
      total: 9,
      stepLabel: labels[step] ?? '',
    );
  }

  Future<void> _submit() async {
    if (!_validateDetails()) return;
    setState(() => _loading = true);
    try {
      final price = parseCopInput(_price.text)!;
      final coords = [
        _latitude ?? coordsForCity(_city)[0],
        _longitude ?? coordsForCity(_city)[1],
      ];
      late Map<String, dynamic> detail;
      late String title;
      if (_asset == 'VEHICLE') {
        final km = int.parse(_mileage.text.trim().replaceAll(RegExp(r'[^\d]'), ''));
        title = _selection.summaryLabel;
        detail = {
          'vehicle_category': _selection.category,
          'brand': _selection.brand!.name,
          'model': _selection.model!.name,
          'line': _selection.version!.name,
          'year': _selection.year!.year,
          'mileage_km': km,
        };
      } else {
        title = _title.text.trim().isEmpty
            ? PreferenceCatalog.propertyTypeLabel(_propertyType)
            : _title.text.trim();
        detail = {
          'property_type': _propertyType,
          if (_bedrooms.text.isNotEmpty) 'bedrooms': int.tryParse(_bedrooms.text),
          if (_bathrooms.text.isNotEmpty) 'bathrooms': int.tryParse(_bathrooms.text),
          if (_area.text.isNotEmpty) 'area_sqm': int.tryParse(_area.text),
        };
      }
      final created = await context.read<InventoryRepository>().create({
        'asset_type': _asset,
        'title': title,
        'description': _description.text.trim(),
        'price_cop': price.toStringAsFixed(2),
        'city': _city,
        'department': _department,
        'geo_city_id': _geoCityId,
        'location': {'latitude': coords[0], 'longitude': coords[1]},
        'detail': {
          ...detail,
          if (_asset == 'VEHICLE' && _selection.version != null)
            'catalog_version_id': _selection.version!.id,
        },
      });
      if (!mounted) return;
      context.read<AppModeController>().bumpCatalog();
      _toast('Publicación creada');
      if (widget.returnResult) {
        context.pop(created.id);
      } else {
        context.pop();
      }
    } catch (e) {
      _toast(e is ApiException ? e.message : 'No se pudo crear');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _InvStep.assetType:
        return _buildAssetType();
      case _InvStep.vehicleCategory:
        return _buildCategory();
      case _InvStep.brand:
        return _buildListStep(
          step: _InvStep.brand,
          title: 'Marca',
          question: '¿Marca?',
          subtitle: 'Selecciona la marca de tu vehículo.',
          crumbs: [
            PreferenceCatalog.vehicleCategoryLabel(_selection.category ?? 'CAR'),
            'Marca',
          ],
          items: _brands.map((b) => (label: b.name, popular: b.isPopular)).toList(),
          onTap: (i) => _pickBrand(_brands[i]),
          onSearch: _loadBrands,
        );
      case _InvStep.model:
        return _buildListStep(
          step: _InvStep.model,
          title: 'Modelo',
          question: '¿Modelo?',
          subtitle: 'Elige el modelo de ${_selection.brand!.name}.',
          crumbs: [_selection.brand!.name, 'Modelo'],
          items: _models.map((m) => (label: m.name, popular: m.isPopular)).toList(),
          onTap: (i) => _pickModel(_models[i]),
          onSearch: _loadModels,
          onCrumb: (_) {
            setState(() => _step = _InvStep.brand);
            _loadBrands();
          },
        );
      case _InvStep.year:
        return _buildListStep(
          step: _InvStep.year,
          title: 'Año',
          question: '¿Año?',
          subtitle: 'Indica el año de fabricación del ${_selection.model!.name}.',
          crumbs: [_selection.brand!.name, _selection.model!.name, 'Año'],
          items: _years.map((y) => (label: '${y.year}', popular: y.isPopular)).toList(),
          onTap: (i) => _pickYear(_years[i]),
          searchable: false,
          onCrumb: (i) {
            if (i == 0) {
              setState(() => _step = _InvStep.brand);
              _loadBrands();
            } else {
              setState(() => _step = _InvStep.model);
              _loadModels();
            }
          },
        );
      case _InvStep.version:
        return _buildListStep(
          step: _InvStep.version,
          title: 'Versión',
          question: '¿Versión?',
          subtitle: 'Elige la versión exacta para ${_selection.year!.year}.',
          crumbs: [
            _selection.brand!.name,
            _selection.model!.name,
            '${_selection.year!.year}',
            'Versión',
          ],
          items: _versions.map((v) => (label: v.name, popular: false)).toList(),
          onTap: (i) => _pickVersion(_versions[i]),
          onSearch: _loadVersions,
          onCrumb: (i) {
            if (i == 0) {
              setState(() => _step = _InvStep.brand);
              _loadBrands();
            } else if (i == 1) {
              setState(() => _step = _InvStep.model);
              _loadModels();
            } else {
              setState(() => _step = _InvStep.year);
              _loadYears();
            }
          },
        );
      case _InvStep.mileage:
        return _buildMileage();
      case _InvStep.details:
        return _buildDetails();
      case _InvStep.summary:
        return _buildSummary();
    }
  }

  Widget _buildAssetType() {
    return CatalogWizardShell(
      title: 'Publicar',
      headline: '¡Hola! Antes que nada cuéntanos, ¿qué vas a publicar?',
      subtitle: 'Elige si vas a publicar un vehículo o un inmueble en tu inventario.',
      progress: _progress(_InvStep.assetType),
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
      headline: 'Vas a publicar gratis y sin comisiones.',
      subtitle: 'Primero, elige la categoría de tu vehículo.',
      progress: _progress(_InvStep.vehicleCategory),
      onBack: _goBack,
      child: CatalogCategoryPicker(onSelected: _pickCategory),
    );
  }

  Widget _buildListStep({
    required _InvStep step,
    required String title,
    required List<String> crumbs,
    required List<({String label, bool popular})> items,
    required void Function(int) onTap,
    String? question,
    String? subtitle,
    VoidCallback? onSearch,
    void Function(int)? onCrumb,
    bool searchable = true,
  }) {
    return CatalogWizardShell(
      title: title,
      headline: 'Completa estos datos con las especificaciones del fabricante',
      subtitle: subtitle,
      question: question,
      progress: _progress(step),
      breadcrumb: CatalogBreadcrumb(parts: crumbs, onTapPart: onCrumb),
      searchController: searchable ? _search : null,
      onSearchChanged: searchable && onSearch != null ? (_) => onSearch() : null,
      onBack: _goBack,
      child: _sectionedList(items: items, onTap: onTap),
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
            'Agregalas desde el panel de administración.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(color: WantiColors.inkMuted),
          ),
        ),
      );
    }
    final popular = <int>[];
    final all = <int>[];
    for (var i = 0; i < items.length; i++) {
      (items[i].popular ? popular : all).add(i);
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

  Widget _buildMileage() {
    final canConfirm = _mileage.text.trim().isNotEmpty;
    return CatalogWizardShell(
      title: 'Kilometraje',
      headline: 'Indica los kilómetros que tiene el vehículo',
      subtitle: 'Ingresa el kilometraje actual para completar la ficha del vehículo.',
      progress: _progress(_InvStep.mileage),
      onBack: _goBack,
      bottom: WantiButton(
        label: 'Confirmar',
        onPressed: canConfirm
            ? () {
                if (_validateMileage()) setState(() => _step = _InvStep.details);
              }
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: _mileage,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Ej: 50.000',
            suffixText: 'km',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return CatalogWizardShell(
      title: 'Datos',
      headline: _asset == 'VEHICLE' ? 'Precio y ubicación' : 'Datos del inmueble',
      subtitle: _asset == 'VEHICLE'
          ? 'Indica el precio de venta y la ciudad donde está el vehículo.'
          : 'Completa los datos principales de tu inmueble.',
      progress: _progress(_InvStep.details),
      onBack: _goBack,
      bottom: WantiButton(
        label: 'Continuar',
        onPressed: () {
          if (_validateDetails()) setState(() => _step = _InvStep.summary);
        },
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_asset == 'VEHICLE')
            Text(
              _selection.summaryLabel,
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: WantiColors.tealDark),
            )
          else ...[
            Wrap(
              spacing: 8,
              children: PreferenceCatalog.propertyTypes.map((t) {
                return ChoiceChip(
                  label: Text(t.$2),
                  selected: _propertyType == t.$1,
                  onSelected: (_) => setState(() => _propertyType = t.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(controller: _bedrooms, decoration: const InputDecoration(labelText: 'Habitaciones'), keyboardType: TextInputType.number),
            TextField(controller: _bathrooms, decoration: const InputDecoration(labelText: 'Baños'), keyboardType: TextInputType.number),
            TextField(controller: _area, decoration: const InputDecoration(labelText: 'Área m²'), keyboardType: TextInputType.number),
          ],
          const SizedBox(height: 12),
          WantiCopField(
            label: 'Precio (COP)',
            controller: _price,
            hint: r'Ej. $75.000.000',
          ),
          const SizedBox(height: 12),
          LocationCascadePicker(
            initialDepartment: _department.isEmpty ? null : _department,
            initialCity: _city.isEmpty ? null : _city,
            initialGeoCityId: _geoCityId.isEmpty ? null : _geoCityId,
            onChanged: ({
              required department,
              required city,
              required geoCityId,
              latitude,
              longitude,
            }) {
              setState(() {
                _department = department;
                _city = city;
                _geoCityId = geoCityId;
                _latitude = latitude;
                _longitude = longitude;
              });
            },
          ),
          const SizedBox(height: 12),
          if (_asset != 'VEHICLE')
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título (opcional)'),
            ),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return CatalogWizardShell(
      title: 'Resumen',
      headline: 'Revisa tu publicación antes de finalizar',
      subtitle: 'Confirma que los datos sean correctos. Puedes volver a editar cualquier paso.',
      progress: _progress(_InvStep.summary),
      onBack: _goBack,
      bottom: Column(
        children: [
          WantiButton(
            label: _loading ? 'Publicando…' : 'Finalizar registro',
            onPressed: _loading ? null : _submit,
          ),
          TextButton(
            onPressed: () => setState(() => _step = _InvStep.details),
            child: Text('Editar', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _row('Tipo', _asset == 'VEHICLE' ? 'Vehículo' : 'Inmueble'),
          if (_asset == 'VEHICLE') ...[
            _row('Vehículo', _selection.summaryLabel),
            _row('Kilometraje', '${_mileage.text} km'),
          ] else
            _row('Inmueble', PreferenceCatalog.propertyTypeLabel(_propertyType)),
          _row('Precio', formatCop(parseCopInput(_price.text) ?? 0)),
          _row('Ubicación', '$_department · $_city'),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WantiColors.borderLight)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: GoogleFonts.nunito(color: WantiColors.inkMuted)),
          ),
          Expanded(
            child: Text(v, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
