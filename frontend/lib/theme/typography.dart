import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class MitlistTypography {
  static TextStyle _grotesk({
    required double size,
    required FontWeight weight,
    required double height,
    required double spacing,
    Color? color,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? MitlistColors.textPrimary,
    );
  }

  static TextTheme get lightTextTheme => TextTheme(
        displayLarge: _grotesk(size: 57, weight: FontWeight.w700, height: 64 / 57, spacing: -0.25),
        displayMedium: _grotesk(size: 45, weight: FontWeight.w700, height: 52 / 45, spacing: 0),
        displaySmall: _grotesk(size: 36, weight: FontWeight.w700, height: 44 / 36, spacing: 0),
        headlineLarge: _grotesk(size: 32, weight: FontWeight.w700, height: 40 / 32, spacing: 0),
        headlineMedium: _grotesk(size: 28, weight: FontWeight.w700, height: 36 / 28, spacing: 0),
        headlineSmall: _grotesk(size: 24, weight: FontWeight.w700, height: 32 / 24, spacing: 0),
        titleLarge: _grotesk(size: 22, weight: FontWeight.w700, height: 28 / 22, spacing: 0),
        titleMedium: _grotesk(size: 16, weight: FontWeight.w700, height: 24 / 16, spacing: 0.15),
        titleSmall: _grotesk(size: 14, weight: FontWeight.w700, height: 20 / 14, spacing: 0.1),
        bodyLarge: _grotesk(size: 16, weight: FontWeight.w400, height: 24 / 16, spacing: 0.5),
        bodyMedium: _grotesk(size: 14, weight: FontWeight.w400, height: 20 / 14, spacing: 0.25),
        bodySmall: _grotesk(size: 12, weight: FontWeight.w400, height: 16 / 12, spacing: 0.4, color: MitlistColors.textSecondary),
        labelLarge: _grotesk(size: 14, weight: FontWeight.w700, height: 20 / 14, spacing: 0.1),
        labelMedium: _grotesk(size: 12, weight: FontWeight.w700, height: 16 / 12, spacing: 0.5, color: MitlistColors.textSecondary),
        labelSmall: _grotesk(size: 11, weight: FontWeight.w700, height: 16 / 11, spacing: 0.5, color: MitlistColors.textTertiary),
      );

  static TextTheme get darkTextTheme => TextTheme(
        displayLarge: _grotesk(size: 57, weight: FontWeight.w700, height: 64 / 57, spacing: -0.25, color: MitlistColors.surfaceSoft),
        displayMedium: _grotesk(size: 45, weight: FontWeight.w700, height: 52 / 45, spacing: 0, color: MitlistColors.surfaceSoft),
        displaySmall: _grotesk(size: 36, weight: FontWeight.w700, height: 44 / 36, spacing: 0, color: MitlistColors.surfaceSoft),
        headlineLarge: _grotesk(size: 32, weight: FontWeight.w700, height: 40 / 32, spacing: 0, color: MitlistColors.surfaceSoft),
        headlineMedium: _grotesk(size: 28, weight: FontWeight.w700, height: 36 / 28, spacing: 0, color: MitlistColors.surfaceSoft),
        headlineSmall: _grotesk(size: 24, weight: FontWeight.w700, height: 32 / 24, spacing: 0, color: MitlistColors.surfaceSoft),
        titleLarge: _grotesk(size: 22, weight: FontWeight.w700, height: 28 / 22, spacing: 0, color: MitlistColors.surfaceSoft),
        titleMedium: _grotesk(size: 16, weight: FontWeight.w700, height: 24 / 16, spacing: 0.15, color: MitlistColors.surfaceSoft),
        titleSmall: _grotesk(size: 14, weight: FontWeight.w700, height: 20 / 14, spacing: 0.1, color: MitlistColors.surfaceSoft),
        bodyLarge: _grotesk(size: 16, weight: FontWeight.w400, height: 24 / 16, spacing: 0.5, color: MitlistColors.surfaceSoft),
        bodyMedium: _grotesk(size: 14, weight: FontWeight.w400, height: 20 / 14, spacing: 0.25, color: MitlistColors.surfaceSoft),
        bodySmall: _grotesk(size: 12, weight: FontWeight.w400, height: 16 / 12, spacing: 0.4, color: MitlistColors.neutral300),
        labelLarge: _grotesk(size: 14, weight: FontWeight.w700, height: 20 / 14, spacing: 0.1, color: MitlistColors.surfaceSoft),
        labelMedium: _grotesk(size: 12, weight: FontWeight.w700, height: 16 / 12, spacing: 0.5, color: MitlistColors.neutral300),
        labelSmall: _grotesk(size: 11, weight: FontWeight.w700, height: 16 / 11, spacing: 0.5, color: MitlistColors.neutral400),
      );

  static TextStyle labelXSmall({Color? color}) => _grotesk(
        size: 10,
        weight: FontWeight.w700,
        height: 1.2,
        spacing: 0.6,
        color: color ?? MitlistColors.textTertiary,
      );

  static TextStyle monoBody({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.43,
        letterSpacing: 0,
        color: color ?? MitlistColors.textPrimary,
      );

  // Logo uses Space Grotesk (google_fonts package) as fallback.
// TODO: Replace with bundled Mathilde font when asset files are provided:
// 1. Add `fonts: - family: Mathilde assets: assets/fonts/Mathilde-Regular.otf` to pubspec.yaml
// 2. Change to: `fontFamily: 'Mathilde'` with `fontLoader.load('assets/fonts/Mathilde-Regular.otf')` in main.dart
// Note: google_fonts fetches at runtime - bundle assets for offline support.
  static TextStyle logo({Color? color}) => GoogleFonts.spaceGrotesk(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: color ?? MitlistColors.textPrimary,
      );
}
