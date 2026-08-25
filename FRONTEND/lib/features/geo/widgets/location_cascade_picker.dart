import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../data/geo_repository.dart';
import '../models/geo_models.dart';

/// Selector Departamento → Ciudad/Municipio.
class LocationCascadePicker extends StatefulWidget {
  const LocationCascadePicker({
    super.key,
    this.initialDepartment,
    this.initialCity,
    this.initialGeoCityId,
    required this.onChanged,
  });

  final String? initialDepartment;
  final String? initialCity;
  final String? initialGeoCityId;
  final void Function({
    required String department,
    required String city,
    required String geoCityId,
    double? latitude,
    double? longitude,
  }) onChanged;

  @override
  State<LocationCascadePicker> createState() => _LocationCascadePickerState();
}

class _LocationCascadePickerState extends State<LocationCascadePicker> {
  List<GeoDepartment> _departments = [];
  List<GeoCity> _cities = [];
  GeoDepartment? _department;
  GeoCity? _city;
  bool _loadingDeps = true;
  bool _loadingCities = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDeps = true;
      _error = null;
    });
    try {
      final deps = await context.read<GeoRepository>().departments();
      if (!mounted) return;
      GeoDepartment? selected;
      if (widget.initialDepartment != null) {
        for (final d in deps) {
          if (d.name.toLowerCase() == widget.initialDepartment!.toLowerCase()) {
            selected = d;
            break;
          }
        }
      }
      setState(() {
        _departments = deps;
        _department = selected;
        _loadingDeps = false;
      });
      if (selected != null) {
        await _loadCities(selected);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingDeps = false;
      });
    }
  }

  Future<void> _loadCities(GeoDepartment dep) async {
    setState(() {
      _loadingCities = true;
      _cities = [];
      _city = null;
    });
    try {
      final cities = await context.read<GeoRepository>().cities(departmentId: dep.id);
      if (!mounted) return;
      GeoCity? selected;
      if (widget.initialGeoCityId != null) {
        for (final c in cities) {
          if (c.id == widget.initialGeoCityId) {
            selected = c;
            break;
          }
        }
      } else if (widget.initialCity != null) {
        for (final c in cities) {
          if (c.name.toLowerCase() == widget.initialCity!.toLowerCase()) {
            selected = c;
            break;
          }
        }
      }
      setState(() {
        _cities = cities;
        _city = selected;
        _loadingCities = false;
      });
      if (selected != null) _emit(selected);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loadingCities = false;
      });
    }
  }

  void _emit(GeoCity city) {
    widget.onChanged(
      department: city.departmentName,
      city: city.name,
      geoCityId: city.id,
      latitude: city.latitude,
      longitude: city.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDeps) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: WantiColors.teal)),
      );
    }
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: WantiColors.error));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Departamento', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<GeoDepartment>(
          // ignore: deprecated_member_use
          value: _department,
          isExpanded: true,
          decoration: const InputDecoration(hintText: 'Selecciona departamento'),
          items: _departments
              .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
              .toList(),
          onChanged: (dep) {
            if (dep == null) return;
            setState(() => _department = dep);
            _loadCities(dep);
          },
        ),
        const SizedBox(height: 12),
        Text('Ciudad / municipio', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_loadingCities)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: WantiColors.teal)),
          )
        else
          DropdownButtonFormField<GeoCity>(
            // ignore: deprecated_member_use
            value: _city,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: _department == null
                  ? 'Primero elige departamento'
                  : 'Selecciona ciudad',
            ),
            items: _cities
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: _department == null
                ? null
                : (city) {
                    if (city == null) return;
                    setState(() => _city = city);
                    _emit(city);
                  },
          ),
      ],
    );
  }
}
