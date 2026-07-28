import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/wanti_colors.dart';
import '../../../shared/widgets/wanti_widgets.dart';
import '../data/needs_repository.dart';
import '../models/need_draft.dart';
import '../models/preference_catalog.dart';

class NewNeedFlowScreen extends StatefulWidget {
  const NewNeedFlowScreen({super.key, this.initialAssetType = 'VEHICLE'});

  final String initialAssetType;

  @override
  State<NewNeedFlowScreen> createState() => _NewNeedFlowScreenState();
}

class _NewNeedFlowScreenState extends State<NewNeedFlowScreen> {
  late final NeedDraft _draft = NeedDraft()..assetType = widget.initialAssetType;
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _line = TextEditingController();
  final _budget = TextEditingController();
  final _city = TextEditingController(text: 'Bogotá');
  final _description = TextEditingController();
  final _tradeIn = TextEditingController();
  final _propertyTitle = TextEditingController();
  int _step = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (_draft.isVehicle) {
      _draft.syncVehicleCriteriaSlots();
    } else {
      _draft.syncPropertyCriteriaSlots();
    }
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _line.dispose();
    _budget.dispose();
    _city.dispose();
    _description.dispose();
    _tradeIn.dispose();
    _propertyTitle.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    final digits = _budget.text.replaceAll(RegExp(r'[^\d]'), '');
    final value = double.tryParse(digits);
    if (value == null || value <= 0) {
      _toast('Ingresá un presupuesto máximo válido');
      return false;
    }
    if (_city.text.trim().isEmpty) {
      _toast('Indicá la ubicación');
      return false;
    }
    if (_draft.paymentTypes.isEmpty) {
      _toast('Seleccioná al menos un tipo de pago');
      return false;
    }
    if (_draft.acceptsTradeIn && _tradeIn.text.trim().isEmpty) {
      _toast('Describí tu permuta');
      return false;
    }

    if (_draft.isVehicle) {
      if (_brand.text.trim().isEmpty || _model.text.trim().isEmpty) {
        _toast('Completá marca y modelo');
        return false;
      }
      _draft
        ..brand = _brand.text.trim()
        ..model = _model.text.trim()
        ..line = _line.text.trim();
      _draft.syncVehicleCriteriaSlots();
    } else {
      _draft.propertyTitle = _propertyTitle.text.trim();
      _draft.syncPropertyCriteriaSlots();
    }

    _draft
      ..budgetMaxCop = value
      ..city = _city.text.trim()
      ..tradeInDescription = _tradeIn.text.trim();
    return true;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _publish() async {
    if (!_draft.legalAccepted) {
      _toast('Debés aceptar la cláusula de responsabilidad');
      return;
    }
    setState(() => _loading = true);
    try {
      _draft.description = _description.text.trim();
      final coords = coordsForCity(_draft.city);
      final repo = context.read<NeedsRepository>();
      final need = await repo.create(
        _draft.toCreatePayload(latitude: coords[0], longitude: coords[1]),
      );
      await repo.publish(need.id, legalAccepted: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Necesidad publicada!')),
      );
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _headerTitle {
    if (_step == 1) {
      return _draft.isVehicle ? 'Nueva necesidad · Vehículo' : 'Nueva necesidad · Inmueble';
    }
    if (_step == 2) {
      return _draft.isVehicle ? 'Preferencias del vehículo' : 'Preferencias del inmueble';
    }
    return 'Vista previa';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: _headerTitle,
              onBack: () {
                if (_step > 1) {
                  setState(() => _step -= 1);
                } else {
                  context.pop();
                }
              },
            ),
            StepProgress(
              label: _step == 1
                  ? 'Datos principales'
                  : _step == 2
                      ? 'Obligatorio vs. preferencia'
                      : 'Revisá y publicá',
              step: _step,
              total: 3,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _step == 1
                    ? _Step1(
                        key: const ValueKey(1),
                        draft: _draft,
                        brand: _brand,
                        model: _model,
                        line: _line,
                        budget: _budget,
                        city: _city,
                        tradeIn: _tradeIn,
                        propertyTitle: _propertyTitle,
                        onChanged: () => setState(() {}),
                      )
                    : _step == 2
                        ? _Step2(
                            key: const ValueKey(2),
                            draft: _draft,
                            onChanged: () => setState(() {}),
                          )
                        : _Step3(
                            key: const ValueKey(3),
                            draft: _draft,
                            description: _description,
                            onLegal: (v) => setState(() => _draft.legalAccepted = v),
                          ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: WantiButton(
                label: _step < 3 ? 'Siguiente →' : 'Publicar necesidad 🚀',
                loading: _loading,
                onPressed: () {
                  if (_step == 1) {
                    if (_validateStep1()) setState(() => _step = 2);
                  } else if (_step == 2) {
                    setState(() => _step = 3);
                  } else {
                    _publish();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  const _Step1({
    super.key,
    required this.draft,
    required this.brand,
    required this.model,
    required this.line,
    required this.budget,
    required this.city,
    required this.tradeIn,
    required this.propertyTitle,
    required this.onChanged,
  });

  final NeedDraft draft;
  final TextEditingController brand;
  final TextEditingController model;
  final TextEditingController line;
  final TextEditingController budget;
  final TextEditingController city;
  final TextEditingController tradeIn;
  final TextEditingController propertyTitle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        if (draft.isVehicle) ...[
          _section('CATEGORÍA'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PreferenceCatalog.vehicleCategories.map((c) {
              final active = draft.vehicleCategory == c.$1;
              return _ChoiceChip(
                label: c.$2,
                active: active,
                onTap: () {
                  draft.vehicleCategory = c.$1;
                  draft.syncVehicleCriteriaSlots();
                  onChanged();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _DropdownField(
            label: 'Marca',
            value: brand.text.isEmpty ? null : brand.text,
            options: [
              ...PreferenceCatalog.brandsFor(draft.vehicleCategory),
              'Otra',
            ],
            onChanged: (v) {
              if (v == 'Otra') {
                brand.clear();
              } else {
                brand.text = v ?? '';
              }
              onChanged();
            },
          ),
          if (brand.text.isEmpty ||
              !PreferenceCatalog.brandsFor(draft.vehicleCategory).contains(brand.text)) ...[
            const SizedBox(height: 12),
            WantiField(label: 'Escribí la marca', controller: brand, hint: 'Marca'),
          ],
          const SizedBox(height: 16),
          WantiField(label: 'Modelo', controller: model, hint: 'Captiva, Tracker, Onix...'),
          const SizedBox(height: 16),
          WantiField(label: 'Versión / línea', controller: line, hint: 'Sport, LTZ 3.0...'),
        ] else ...[
          _section('TIPO DE INMUEBLE'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PreferenceCatalog.propertyTypes.map((t) {
              final active = draft.propertyType == t.$1;
              return _ChoiceChip(
                label: t.$2,
                active: active,
                onTap: () {
                  draft.propertyType = t.$1;
                  draft.syncPropertyCriteriaSlots();
                  onChanged();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          WantiField(
            label: 'Título (opcional)',
            controller: propertyTitle,
            hint: 'Ej. Apto 3 hab. Chapinero',
          ),
        ],
        const SizedBox(height: 16),
        WantiField(
          label: 'Presupuesto máximo',
          controller: budget,
          hint: '120.000.000 COP',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _section('TIPO DE PAGO (podés marcar varios)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (draft.isVehicle
                  ? PreferenceCatalog.paymentOptions
                  : PreferenceCatalog.propertyPaymentOptions)
              .map((p) {
            final active = draft.paymentTypes.contains(p.$1);
            return _ChoiceChip(
              label: p.$2,
              active: active,
              onTap: () {
                if (active) {
                  draft.paymentTypes = List.from(draft.paymentTypes)..remove(p.$1);
                } else {
                  draft.paymentTypes = List.from(draft.paymentTypes)..add(p.$1);
                }
                onChanged();
              },
            );
          }).toList(),
        ),
        if (draft.acceptsTradeIn) ...[
          const SizedBox(height: 16),
          WantiField(
            label: 'Describí tu permuta',
            controller: tradeIn,
            hint: 'Qué ofrecés a cambio...',
            maxLines: 3,
          ),
        ],
        const SizedBox(height: 16),
        WantiField(label: 'Ubicación (ciudad)', controller: city, hint: 'Bogotá'),
      ],
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: WantiColors.inkMuted,
          letterSpacing: 0.24,
        ),
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  const _Step2({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final NeedDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = draft.criteria.entries.toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WantiColors.border),
          ),
          child: Text(
            draft.isVehicle
                ? 'Completá solo lo que te importa según la categoría del vehículo. Obligatorio excluye; Preferencia no.'
                : 'Los campos cambian según el tipo de inmueble (${PreferenceCatalog.propertyTypeLabel(draft.propertyType)}). Obligatorio excluye; Preferencia no.',
            style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted, height: 1.35),
          ),
        ),
        const SizedBox(height: 16),
        ...entries.map((e) {
          final c = e.value;
          final field = c.field!;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: c.required ? WantiColors.teal : WantiColors.border,
                width: c.required ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.label,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: WantiColors.ink,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: c.required,
                      activeThumbColor: Colors.white,
                      activeTrackColor: WantiColors.teal,
                      onChanged: (v) {
                        c.required = v;
                        onChanged();
                      },
                    ),
                  ],
                ),
                Text(
                  c.required ? 'Obligatorio' : 'Preferencia',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: c.required ? WantiColors.tealDark : WantiColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _PreferenceEditor(
                  field: field,
                  value: c.value,
                  onChanged: (raw) {
                    draft.setCriterionValue(e.key, raw);
                    onChanged();
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PreferenceEditor extends StatelessWidget {
  const _PreferenceEditor({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final PreferenceFieldDef field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (field.inputType) {
      case PreferenceInputType.dropdown:
      case PreferenceInputType.year:
        final options = field.inputType == PreferenceInputType.year
            ? PreferenceCatalog.years
            : field.options;
        final current = value?.toString();
        return _DropdownField(
          label: null,
          value: current != null && options.contains(current) ? current : null,
          options: options,
          hint: 'Seleccioná...',
          onChanged: onChanged,
        );
      case PreferenceInputType.multi:
        final selected = <String>{
          if (value is List) ...value.map((e) => e.toString()),
        };
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((opt) {
            final active = selected.contains(opt);
            return _ChoiceChip(
              label: opt,
              active: active,
              onTap: () {
                final next = Set<String>.from(selected);
                if (active) {
                  next.remove(opt);
                } else {
                  next.add(opt);
                }
                onChanged(next.toList());
              },
            );
          }).toList(),
        );
      case PreferenceInputType.number:
      case PreferenceInputType.text:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          keyboardType: field.inputType == PreferenceInputType.number
              ? TextInputType.number
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: field.hint.isEmpty ? field.label : field.hint,
            filled: true,
            fillColor: WantiColors.surfaceSoft,
          ),
          onChanged: onChanged,
        );
    }
  }
}

class _Step3 extends StatelessWidget {
  const _Step3({
    super.key,
    required this.draft,
    required this.description,
    required this.onLegal,
  });

  final NeedDraft draft;
  final TextEditingController description;
  final ValueChanged<bool> onLegal;

  @override
  Widget build(BuildContext context) {
    final required = draft.criteria.entries
        .where((e) => e.value.required && e.value.value != null)
        .map((e) => '${e.value.label}: ${e.value.displayValue}')
        .join('\n');
    final preferred = draft.criteria.entries
        .where((e) => !e.value.required && e.value.value != null)
        .map((e) => '${e.value.label}: ${e.value.displayValue}')
        .join('\n');
    final paymentLabel = draft.paymentTypes
        .map((p) {
          final opts = draft.isVehicle
              ? PreferenceCatalog.paymentOptions
              : PreferenceCatalog.propertyPaymentOptions;
          return opts.firstWhere((e) => e.$1 == p, orElse: () => (p, p)).$2;
        })
        .join(', ');
    final budgetM = draft.budgetMaxCop / 1000000;
    final budgetLabel =
        '\$${budgetM == budgetM.roundToDouble() ? budgetM.toStringAsFixed(0) : budgetM.toStringAsFixed(1)}M COP';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: WantiColors.surfaceTeal,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WantiColors.teal, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(
                draft.isVehicle ? Icons.directions_car_filled : Icons.home_work_outlined,
                size: 48,
                color: WantiColors.teal,
              ),
              const SizedBox(height: 12),
              Text(
                draft.title.isEmpty ? 'Tu necesidad' : draft.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WantiColors.tealDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$budgetLabel · $paymentLabel · ${draft.city}',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 12, color: WantiColors.tealDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WantiColors.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WantiColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              if (required.isNotEmpty) ...[
                Text('Obligatorios', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                Text(required, style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4)),
                const SizedBox(height: 8),
              ],
              if (preferred.isNotEmpty) ...[
                Text('Preferencias', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                Text(preferred, style: GoogleFonts.nunito(color: WantiColors.inkMuted, height: 1.4)),
              ],
              if (draft.acceptsTradeIn && draft.tradeInDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Permuta: ${draft.tradeInDescription}',
                    style: GoogleFonts.nunito(color: WantiColors.inkMuted)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Breve descripción de tu sueño...',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: draft.legalAccepted,
              activeColor: WantiColors.teal,
              onChanged: (v) => onLegal(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  draft.isVehicle
                      ? 'Acepto la cláusula de responsabilidad sobre estado mecánico'
                      : 'Acepto la cláusula de responsabilidad sobre el estado del inmueble',
                  style: GoogleFonts.nunito(fontSize: 14, color: WantiColors.ink),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? WantiColors.navy : WantiColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? WantiColors.navy : WantiColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: active ? Colors.white : WantiColors.ink,
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.options,
    required this.onChanged,
    this.label,
    this.value,
    this.hint = 'Seleccioná...',
  });

  final String? label;
  final String? value;
  final List<String> options;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WantiColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<String>(
          value: value != null && options.contains(value) ? value : null,
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: WantiColors.surfaceSoft,
          ),
        ),
      ],
    );
  }
}
