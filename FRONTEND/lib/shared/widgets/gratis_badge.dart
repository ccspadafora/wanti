import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/wanti_colors.dart';

/// Small visual cue that publishing is free.
class GratisBadge extends StatelessWidget {
  const GratisBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 10,
        vertical: compact ? 1 : 4,
      ),
      decoration: BoxDecoration(
        color: WantiColors.surfaceTeal,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WantiColors.teal.withValues(alpha: 0.35)),
      ),
      child: Text(
        'GRATIS',
        style: GoogleFonts.nunito(
          fontSize: compact ? 8 : 11,
          fontWeight: FontWeight.w800,
          color: WantiColors.tealDark,
          letterSpacing: 0.3,
          height: 1.1,
        ),
      ),
    );
  }
}
