import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/wanti_colors.dart';
import '../models/geo_models.dart';

/// Desplegable de multiselección de ciudades (no chips).
class CityMultiSelectField extends StatelessWidget {
  const CityMultiSelectField({
    super.key,
    required this.cities,
    required this.selectedIds,
    required this.onChanged,
    this.excludeCityId,
    this.label = 'Ciudades adicionales',
    this.hint = 'Selecciona una o más ciudades',
    this.loading = false,
  });

  final List<GeoCity> cities;
  final Set<String> selectedIds;
  final ValueChanged<List<GeoCity>> onChanged;
  final String? excludeCityId;
  final String label;
  final String hint;
  final bool loading;

  List<GeoCity> get _options {
    if (excludeCityId == null || excludeCityId!.isEmpty) return cities;
    return cities.where((c) => c.id != excludeCityId).toList();
  }

  List<GeoCity> get _selected {
    final ids = selectedIds;
    return _options.where((c) => ids.contains(c.id)).toList();
  }

  String get _summary {
    final sel = _selected;
    if (sel.isEmpty) return hint;
    if (sel.length <= 2) return sel.map((c) => c.name).join(', ');
    return '${sel.length} ciudades seleccionadas';
  }

  Future<void> _openPicker(BuildContext context) async {
    final options = _options;
    final working = {...selectedIds};
    final search = TextEditingController();

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: WantiColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = search.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? options
                : options
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(q) ||
                          c.departmentName.toLowerCase().contains(q),
                    )
                    .toList();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, working),
                            child: Text(
                              'Listo',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                color: WantiColors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setLocal(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar ciudad o departamento',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        working.isEmpty
                            ? 'Ninguna seleccionada'
                            : '${working.length} seleccionada${working.length == 1 ? '' : 's'}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: WantiColors.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final city = filtered[i];
                          final checked = working.contains(city.id);
                          return CheckboxListTile(
                            value: checked,
                            activeColor: WantiColors.teal,
                            title: Text(
                              city.name,
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              city.departmentName,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: WantiColors.inkMuted,
                              ),
                            ),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  working.add(city.id);
                                } else {
                                  working.remove(city.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    search.dispose();
    if (result == null) return;
    final selected = options.where((c) => result.contains(c.id)).toList();
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(color: WantiColors.teal)),
          )
        else
          InkWell(
            onTap: () => _openPicker(context),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: WantiColors.border),
                ),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              child: Text(
                _summary,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w500,
                  color: hasSelection ? WantiColors.ink : WantiColors.inkMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
