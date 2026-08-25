import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/wanti_colors.dart';

/// Progreso visible del flujo tipo Mercado Libre.
class CatalogStepProgress {
  const CatalogStepProgress({
    required this.current,
    required this.total,
    required this.stepLabel,
  });

  final int current;
  final int total;
  final String stepLabel;
}

/// Shell visual tipo Mercado Libre, con colores Wanti (navy/teal).
class CatalogWizardShell extends StatelessWidget {
  const CatalogWizardShell({
    super.key,
    required this.title,
    required this.child,
    this.headline,
    this.subtitle,
    this.question,
    this.breadcrumb,
    this.progress,
    this.onBack,
    this.bottom,
    this.searchController,
    this.onSearchChanged,
    this.searchHint = 'Buscar',
  });

  final String title;
  final String? headline;
  final String? subtitle;
  /// Pregunta del paso actual, ej. "¿Marca?"
  final String? question;
  final Widget? breadcrumb;
  final CatalogStepProgress? progress;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? bottom;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WantiColors.canvas,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: WantiColors.navy,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (progress != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Paso ${progress!.current} de ${progress!.total}',
                                style: GoogleFonts.nunito(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                progress!.stepLabel,
                                style: GoogleFonts.nunito(
                                  color: WantiColors.teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress!.current / progress!.total,
                              minHeight: 4,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              color: WantiColors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (headline != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      headline!,
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: WantiColors.ink,
                        height: 1.12,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      subtitle!,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: WantiColors.inkMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (breadcrumb != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: breadcrumb!,
                  ),
                if (question != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 20, 4),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: WantiColors.tealDark),
                        ),
                        Text(
                          question!,
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: WantiColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (searchController != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: searchHint,
                        prefixIcon: const Icon(Icons.search, color: WantiColors.inkFaint),
                        filled: true,
                        fillColor: WantiColors.surfaceSoft,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: WantiColors.border),
                        ),
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
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                if (bottom != null)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: bottom!,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogBreadcrumb extends StatelessWidget {
  const CatalogBreadcrumb({super.key, required this.parts, this.onTapPart});

  final List<String> parts;
  final void Function(int index)? onTapPart;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '>',
                style: GoogleFonts.nunito(color: WantiColors.inkFaint, fontWeight: FontWeight.w700),
              ),
            ),
          GestureDetector(
            onTap: onTapPart != null && i < parts.length - 1 ? () => onTapPart!(i) : null,
            child: Text(
              parts[i],
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: i < parts.length - 1 ? WantiColors.tealDark : WantiColors.ink,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CatalogChoiceTile extends StatelessWidget {
  const CatalogChoiceTile({
    super.key,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: WantiColors.borderLight)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: WantiColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: WantiColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class CatalogSectionHeader extends StatelessWidget {
  const CatalogSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: WantiColors.inkFaint,
        ),
      ),
    );
  }
}

/// Opción compacta estilo Mercado Libre — ancho completo, altura fija.
class CatalogOptionTile extends StatelessWidget {
  const CatalogOptionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WantiColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: WantiColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Icons.category_outlined,
                  size: 24,
                  color: WantiColors.tealDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: WantiColors.ink,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: WantiColors.inkMuted,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: WantiColors.inkFaint, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dos opciones apiladas — vehículo/inmueble o carro/moto.
class CatalogBinaryPicker extends StatelessWidget {
  const CatalogBinaryPicker({
    super.key,
    required this.firstLabel,
    required this.firstSubtitle,
    required this.firstIcon,
    required this.onFirst,
    required this.secondLabel,
    required this.secondSubtitle,
    required this.secondIcon,
    required this.onSecond,
  });

  final String firstLabel;
  final String firstSubtitle;
  final IconData firstIcon;
  final VoidCallback onFirst;
  final String secondLabel;
  final String secondSubtitle;
  final IconData secondIcon;
  final VoidCallback onSecond;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogOptionTile(
            label: firstLabel,
            subtitle: firstSubtitle,
            icon: firstIcon,
            onTap: onFirst,
          ),
          const SizedBox(height: 10),
          CatalogOptionTile(
            label: secondLabel,
            subtitle: secondSubtitle,
            icon: secondIcon,
            onTap: onSecond,
          ),
        ],
      ),
    );
  }
}

/// @deprecated Usar [CatalogOptionTile] o [CatalogBinaryPicker].
class CatalogAssetCard extends StatelessWidget {
  const CatalogAssetCard({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CatalogOptionTile(
      label: label,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
    );
  }
}

/// Selector de categoría de vehículo (grid).
class CatalogCategoryPicker extends StatelessWidget {
  const CatalogCategoryPicker({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<String> onSelected;

  static const _items = <({String code, String label, String subtitle, IconData icon})>[
    (code: 'CAR', label: 'Carros', subtitle: 'Automóviles y sedanes', icon: Icons.directions_car_outlined),
    (code: 'SUV', label: 'Camionetas', subtitle: 'SUV, pick-up y 4x4', icon: Icons.airport_shuttle_outlined),
    (code: 'MOTO', label: 'Motos', subtitle: 'Motocicletas y scooters', icon: Icons.two_wheeler_outlined),
    (
      code: 'COLLECTION',
      label: 'Carros de colección',
      subtitle: 'Clásicos y edición especial',
      icon: Icons.auto_awesome_outlined,
    ),
    (code: 'TRUCK', label: 'Camiones', subtitle: 'Carga y comerciales', icon: Icons.local_shipping_outlined),
    (code: 'NAUTICAL', label: 'Náutica', subtitle: 'Botes y embarcaciones', icon: Icons.sailing_outlined),
    (
      code: 'HEAVY_MACHINERY',
      label: 'Maquinaria pesada',
      subtitle: 'Construcción e industrial',
      icon: Icons.agriculture_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        for (final item in _items) ...[
          CatalogOptionTile(
            label: item.label,
            subtitle: item.subtitle,
            icon: item.icon,
            onTap: () => onSelected(item.code),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

