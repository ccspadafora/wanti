import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../../inventory/data/inventory_repository.dart';

class AddInventoryScreen extends StatefulWidget {
  const AddInventoryScreen({super.key});

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  String _asset = 'VEHICLE';
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController(text: 'Bogotá');
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _mileage = TextEditingController();
  final _fuel = TextEditingController();
  final _transmission = TextEditingController();
  final _traction = TextEditingController();
  final _bedrooms = TextEditingController();
  final _bathrooms = TextEditingController();
  final _area = TextEditingController();
  final _propertyType = TextEditingController(text: 'APTO');
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _city.dispose();
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _mileage.dispose();
    _fuel.dispose();
    _transmission.dispose();
    _traction.dispose();
    _bedrooms.dispose();
    _bathrooms.dispose();
    _area.dispose();
    _propertyType.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = double.tryParse(_price.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (price == null || price <= 0) {
      _toast('Ingresá un precio válido');
      return;
    }
    if (_city.text.trim().isEmpty) {
      _toast('Indicá la ciudad');
      return;
    }

    Map<String, dynamic> detail;
    String title;
    if (_asset == 'VEHICLE') {
      if (_brand.text.trim().isEmpty || _model.text.trim().isEmpty) {
        _toast('Completá marca y modelo');
        return;
      }
      final year = int.tryParse(_year.text.trim());
      final mileage = int.tryParse(_mileage.text.trim());
      if (year == null || mileage == null) {
        _toast('Año y kilometraje son obligatorios');
        return;
      }
      title = _title.text.trim().isEmpty
          ? '${_brand.text.trim()} ${_model.text.trim()} $year'
          : _title.text.trim();
      detail = {
        'vehicle_category': 'CAR',
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'year': year,
        'mileage_km': mileage,
        'fuel_type': _fuel.text.trim(),
        'transmission': _transmission.text.trim(),
        'traction': _traction.text.trim(),
      };
    } else {
      title = _title.text.trim();
      if (title.isEmpty) {
        _toast('Ingresá un título para el inmueble');
        return;
      }
      detail = {
        'property_type': _propertyType.text.trim().isEmpty ? 'APTO' : _propertyType.text.trim(),
        'bedrooms': int.tryParse(_bedrooms.text.trim()),
        'bathrooms': int.tryParse(_bathrooms.text.trim()),
        'area_sqm': double.tryParse(_area.text.trim()),
      }..removeWhere((_, v) => v == null);
    }

    setState(() => _loading = true);
    try {
      await context.read<InventoryRepository>().create({
        'asset_type': _asset,
        'title': title,
        'price_cop': price,
        'city': _city.text.trim(),
        'location': {'latitude': 4.711, 'longitude': -74.0721},
        'detail': detail,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventario publicado')),
      );
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Agregar al inventario'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Toggle(
                          label: 'Vehículo',
                          selected: _asset == 'VEHICLE',
                          onTap: () => setState(() => _asset = 'VEHICLE'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Toggle(
                          label: 'Inmueble',
                          selected: _asset == 'PROPERTY',
                          onTap: () => setState(() => _asset = 'PROPERTY'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  WantiField(label: 'Título', controller: _title, hint: 'Opcional en vehículos'),
                  const SizedBox(height: 14),
                  WantiField(
                    label: 'Precio COP',
                    controller: _price,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  WantiField(label: 'Ciudad', controller: _city),
                  const SizedBox(height: 14),
                  if (_asset == 'VEHICLE') ...[
                    WantiField(label: 'Marca', controller: _brand),
                    const SizedBox(height: 14),
                    WantiField(label: 'Modelo', controller: _model),
                    const SizedBox(height: 14),
                    WantiField(label: 'Año', controller: _year, keyboardType: TextInputType.number),
                    const SizedBox(height: 14),
                    WantiField(
                      label: 'Kilometraje',
                      controller: _mileage,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    WantiField(label: 'Combustible', controller: _fuel, hint: 'Diésel, Gasolina...'),
                    const SizedBox(height: 14),
                    WantiField(label: 'Transmisión', controller: _transmission),
                    const SizedBox(height: 14),
                    WantiField(label: 'Tracción', controller: _traction, hint: '4x4, 4x2...'),
                  ] else ...[
                    WantiField(label: 'Tipo', controller: _propertyType, hint: 'APTO, CASA...'),
                    const SizedBox(height: 14),
                    WantiField(
                      label: 'Habitaciones',
                      controller: _bedrooms,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    WantiField(
                      label: 'Baños',
                      controller: _bathrooms,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    WantiField(
                      label: 'Área m²',
                      controller: _area,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 28),
                  WantiButton(
                    label: 'Publicar',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? WantiColors.navy : WantiColors.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? WantiColors.navy : WantiColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : WantiColors.ink,
          ),
        ),
      ),
    );
  }
}
