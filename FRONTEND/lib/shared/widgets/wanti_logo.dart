import 'package:flutter/material.dart';

enum WantiLogoVariant { full, wordmark, mark }

/// Official Wanti logo assets (approved brand files).
class WantiLogo extends StatelessWidget {
  const WantiLogo({
    super.key,
    this.variant = WantiLogoVariant.full,
    this.height = 220,
    this.width,
    this.surface = false,
    this.surfaceColor = Colors.white,
    this.surfaceRadius = 24,
    this.surfacePadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    this.alignment = Alignment.centerLeft,
  });

  final WantiLogoVariant variant;
  final double height;
  final double? width;
  final bool surface;
  final Color surfaceColor;
  final double surfaceRadius;
  final EdgeInsets surfacePadding;
  final Alignment alignment;

  static const _assets = {
    WantiLogoVariant.full: 'assets/images/wanti_logo_full.png',
    WantiLogoVariant.wordmark: 'assets/images/wanti_logo_wordmark.png',
    WantiLogoVariant.mark: 'assets/images/wanti_logo_mark.png',
  };

  /// Content aspect ratios after trimming transparent padding.
  static const _aspectRatios = {
    WantiLogoVariant.full: 652 / 771,
    WantiLogoVariant.wordmark: 652 / 623,
    WantiLogoVariant.mark: 522 / 433,
  };

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatios[variant]!;
    final logoWidth = width ?? height * ratio;

    Widget logo = SizedBox(
      height: height,
      width: logoWidth,
      child: Image.asset(
        _assets[variant]!,
        fit: BoxFit.contain,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );

    if (!surface) return logo;

    return Container(
      padding: surfacePadding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(surfaceRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: logo,
    );
  }
}
