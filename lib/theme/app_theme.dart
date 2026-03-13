import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lexiq_colors.dart';

class AppTheme {
  static ThemeData build({required bool isArabic}) {
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

    final headlineLarge = isArabic ? GoogleFonts.cairo : GoogleFonts.manrope;
    final headlineMedium = isArabic ? GoogleFonts.cairo : GoogleFonts.manrope;
    final titleLarge = isArabic ? GoogleFonts.cairo : GoogleFonts.manrope;
    final titleMedium = isArabic ? GoogleFonts.cairo : GoogleFonts.manrope;
    final bodyLarge = isArabic ? GoogleFonts.cairo : GoogleFonts.manrope;
    final bodyMedium = isArabic ? GoogleFonts.cairo : GoogleFonts.manrope;
    final labelLarge = isArabic ? GoogleFonts.cairo : GoogleFonts.manrope;

    final textTheme =
        (isArabic
                ? GoogleFonts.cairoTextTheme(base.textTheme)
                : GoogleFonts.manropeTextTheme(base.textTheme))
            .copyWith(
              headlineLarge: headlineLarge(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: LexiqColors.ivoryText,
              ),
              headlineMedium: headlineMedium(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: LexiqColors.ivoryText,
              ),
              titleLarge: titleLarge(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LexiqColors.ivoryText,
              ),
              titleMedium: titleMedium(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LexiqColors.ivoryText,
              ),
              bodyLarge: bodyLarge(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: LexiqColors.ivoryText,
              ),
              bodyMedium: bodyMedium(
                fontSize: 14,
                color: LexiqColors.slateGray,
              ),
              labelLarge: labelLarge(
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
          borderSide: BorderSide(
            color: LexiqColors.slateGray.withValues(alpha: 0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: LexiqColors.slateGray.withValues(alpha: 0.25),
          ),
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
          side: BorderSide(
            color: LexiqColors.slateGray.withValues(alpha: 0.18),
          ),
        ),
      ),
      dividerColor: LexiqColors.slateGray.withValues(alpha: 0.25),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LexiqColors.imperialBlue,
          foregroundColor: LexiqColors.ivoryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
    );
  }
}
