import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/wanti_colors.dart';
import '../../core/utils/formatters.dart';

class WantiButton extends StatelessWidget {
  const WantiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.variant = WantiButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final WantiButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    Color bg;
    Color fg;
    switch (variant) {
      case WantiButtonVariant.primary:
        bg = WantiColors.navy;
        fg = WantiColors.onDark;
      case WantiButtonVariant.teal:
        bg = WantiColors.teal;
        fg = WantiColors.onTeal;
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.4),
          disabledForegroundColor: fg,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

enum WantiButtonVariant { primary, teal }

class WantiField extends StatelessWidget {
  const WantiField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.textInputAction,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.24,
            color: WantiColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          validator: validator,
          maxLines: obscure ? 1 : maxLines,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          style: GoogleFonts.nunito(fontSize: 16, color: WantiColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class WantiDropdown<T> extends StatelessWidget {
  const WantiDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.24,
            color: WantiColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: value,
          hint: hint != null ? Text(hint!) : null,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          decoration: const InputDecoration(),
          style: GoogleFonts.nunito(fontSize: 16, color: WantiColors.ink),
        ),
      ],
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            color: WantiColors.ink,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: WantiColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.label,
    required this.step,
    required this.total,
  });

  final String label;
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkMuted),
              ),
              const Spacer(),
              Text(
                'Paso $step de $total',
                style: GoogleFonts.nunito(fontSize: 13, color: WantiColors.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 8,
              backgroundColor: WantiColors.borderLight,
              color: WantiColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class DotsProgress extends StatelessWidget {
  const DotsProgress({super.key, required this.step, this.total = 3});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (i) {
            final active = i + 1 == step;
            final done = i + 1 < step;
            if (active || done) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: WantiColors.teal,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: WantiColors.border,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Paso $step de $total',
          style: GoogleFonts.nunito(fontSize: 12, color: WantiColors.inkFaint),
        ),
      ],
    );
  }
}

/// Campo monetario COP: conserva foco, permite borrar y reformatea miles.
class WantiCopField extends StatelessWidget {
  const WantiCopField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return WantiField(
      label: label,
      controller: controller,
      hint: hint ?? r'Ej. $75.000.000',
      keyboardType: TextInputType.number,
      inputFormatters: [CopInputFormatter()],
      onChanged: onChanged,
    );
  }
}
