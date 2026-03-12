import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lexiq_colors.dart';

class AppTheme {
  static ThemeData build() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: LexiqColors.imperialBlue,
      onPrimary: LexiqColors.ivoryText,
      secondary: LexiqColors.emeraldJustice,
      onSecondary: LexiqColors.obsidianBlack,
      error: LexiqColors.crimsonAlert,
      onError: LexiqColors.ivoryText,
      surface: LexiqColors.deepNavy,
      onSurface: LexiqColors.ivoryText,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LexiqColors.obsidianBlack,
      useMaterial3: true,
    );

    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.cairo(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: LexiqColors.ivoryText,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: LexiqColors.ivoryText,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: LexiqColors.ivoryText,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: LexiqColors.ivoryText,
      ),
      bodyLarge: GoogleFonts.cairo(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: LexiqColors.ivoryText,
      ),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14,
        color: LexiqColors.slateGray,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: LexiqColors.ivoryText,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: LexiqColors.ivoryText,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LexiqColors.deepNavy.withValues(alpha: 0.75),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: LexiqColors.slateGray.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: LexiqColors.slateGray.withValues(alpha: 0.25)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: LexiqColors.imperialBlue, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: LexiqColors.deepNavy.withValues(alpha: 0.82),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: LexiqColors.slateGray.withValues(alpha: 0.18)),
        ),
      ),
      dividerColor: LexiqColors.slateGray.withValues(alpha: 0.25),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LexiqColors.imperialBlue,
          foregroundColor: LexiqColors.ivoryText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
    );
  }
}
