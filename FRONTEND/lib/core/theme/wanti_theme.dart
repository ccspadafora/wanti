import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'wanti_colors.dart';

class WantiTheme {
  WantiTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: WantiColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: WantiColors.navy,
        secondary: WantiColors.teal,
        surface: WantiColors.canvas,
        error: WantiColors.error,
        onPrimary: WantiColors.onDark,
        onSecondary: WantiColors.onTeal,
        onSurface: WantiColors.ink,
      ),
    );

    final nunito = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: WantiColors.ink,
      displayColor: WantiColors.ink,
    );

    return base.copyWith(
      textTheme: nunito,
      appBarTheme: AppBarTheme(
        backgroundColor: WantiColors.canvas,
        foregroundColor: WantiColors.ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: WantiColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WantiColors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WantiColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WantiColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: WantiColors.borderFocus, width: 1.5),
        ),
        hintStyle: GoogleFonts.nunito(color: WantiColors.inkFaint, fontSize: 16),
        labelStyle: GoogleFonts.nunito(
          color: WantiColors.inkMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WantiColors.navy,
          foregroundColor: WantiColors.onDark,
          disabledBackgroundColor: WantiColors.navy.withValues(alpha: 0.4),
          disabledForegroundColor: WantiColors.onDark,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: WantiColors.teal,
          textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
