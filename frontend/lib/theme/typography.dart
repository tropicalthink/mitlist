import 'package:flutter/material.dart';
import 'colors.dart';

class MitlistTypography {
  /// Bundled brand display/heading face. See pubspec `fonts:`.
  static const String groteskFamily = 'Space Grotesk';

  /// Bundled monospace face used for numerals and code-like values.
  static const String monoFamily = 'JetBrains Mono';

  static TextStyle _grotesk({
    required double size,
    required FontWeight weight,
    required double height,
    double spacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: groteskFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color ?? MitlistColors.textPrimary,
    );
  }

  /// One step heavier, for the "bold text" readability setting: w400/w500 →
  /// w600, w600 → w700, w700 stays put. Both bundled faces are variable fonts,
  /// so the in-between weights render as real weights rather than a synthetic
  /// smear.
  static TextStyle? _heavier(TextStyle? style) {
    if (style == null) return style;
    return switch (style.fontWeight) {
      FontWeight.w400 || FontWeight.w500 =>
        style.copyWith(fontWeight: FontWeight.w600),
      FontWeight.w600 => style.copyWith(fontWeight: FontWeight.w700),
      _ => style,
    };
  }

  static TextTheme _bolder(TextTheme base) => TextTheme(
        displayLarge: _heavier(base.displayLarge),
        displayMedium: _heavier(base.displayMedium),
        displaySmall: _heavier(base.displaySmall),
        headlineLarge: _heavier(base.headlineLarge),
        headlineMedium: _heavier(base.headlineMedium),
        headlineSmall: _heavier(base.headlineSmall),
        titleLarge: _heavier(base.titleLarge),
        titleMedium: _heavier(base.titleMedium),
        titleSmall: _heavier(base.titleSmall),
        bodyLarge: _heavier(base.bodyLarge),
        bodyMedium: _heavier(base.bodyMedium),
        bodySmall: _heavier(base.bodySmall),
        labelLarge: _heavier(base.labelLarge),
        labelMedium: _heavier(base.labelMedium),
        labelSmall: _heavier(base.labelSmall),
      );

  /// The light text theme, optionally in the heavier weights the readability
  /// setting asks for.
  static TextTheme lightTextThemeWith({bool bold = false}) {
    final base = _lightTextTheme;
    return bold ? _bolder(base) : base;
  }

  /// The dark text theme, optionally in the heavier weights the readability
  /// setting asks for.
  static TextTheme darkTextThemeWith({bool bold = false}) {
    final base = _darkTextTheme;
    return bold ? _bolder(base) : base;
  }

  static TextTheme get lightTextTheme => lightTextThemeWith();

  static TextTheme get darkTextTheme => darkTextThemeWith();

  static TextTheme get _lightTextTheme => TextTheme(
        displayLarge: _grotesk(
            size: 57, weight: FontWeight.w700, height: 64 / 57, spacing: -0.25),
        displayMedium: _grotesk(
            size: 45, weight: FontWeight.w700, height: 52 / 45, spacing: 0),
        displaySmall: _grotesk(
            size: 36, weight: FontWeight.w700, height: 44 / 36, spacing: 0),
        headlineLarge: _grotesk(
            size: 32, weight: FontWeight.w700, height: 40 / 32, spacing: 0),
        headlineMedium: _grotesk(
            size: 28, weight: FontWeight.w700, height: 36 / 28, spacing: 0),
        headlineSmall: _grotesk(
            size: 24, weight: FontWeight.w700, height: 32 / 24, spacing: 0),
        titleLarge: _grotesk(
            size: 22, weight: FontWeight.w700, height: 28 / 22, spacing: 0),
        titleMedium: _grotesk(
            size: 16, weight: FontWeight.w600, height: 24 / 16, spacing: 0.15),
        titleSmall: _grotesk(
            size: 14, weight: FontWeight.w600, height: 20 / 14, spacing: 0.1),
        bodyLarge: _grotesk(
            size: 16, weight: FontWeight.w400, height: 24 / 16, spacing: 0.5),
        bodyMedium: _grotesk(
            size: 14, weight: FontWeight.w400, height: 20 / 14, spacing: 0.25),
        bodySmall: _grotesk(
            size: 12,
            weight: FontWeight.w400,
            height: 16 / 12,
            spacing: 0.4,
            color: MitlistColors.textSecondary),
        labelLarge: _grotesk(
            size: 14, weight: FontWeight.w600, height: 20 / 14, spacing: 0.1),
        labelMedium: _grotesk(
            size: 12,
            weight: FontWeight.w500,
            height: 16 / 12,
            spacing: 0.5,
            color: MitlistColors.textSecondary),
        labelSmall: _grotesk(
            size: 11,
            weight: FontWeight.w500,
            height: 16 / 11,
            spacing: 0.5,
            color: MitlistColors.textTertiary),
      );

  static TextTheme get _darkTextTheme => TextTheme(
        displayLarge: _grotesk(
            size: 57,
            weight: FontWeight.w700,
            height: 64 / 57,
            spacing: -0.25,
            color: MitlistColors.surfaceSoft),
        displayMedium: _grotesk(
            size: 45,
            weight: FontWeight.w700,
            height: 52 / 45,
            spacing: 0,
            color: MitlistColors.surfaceSoft),
        displaySmall: _grotesk(
            size: 36,
            weight: FontWeight.w700,
            height: 44 / 36,
            spacing: 0,
            color: MitlistColors.surfaceSoft),
        headlineLarge: _grotesk(
            size: 32,
            weight: FontWeight.w700,
            height: 40 / 32,
            spacing: 0,
            color: MitlistColors.surfaceSoft),
        headlineMedium: _grotesk(
            size: 28,
            weight: FontWeight.w700,
            height: 36 / 28,
            spacing: 0,
            color: MitlistColors.surfaceSoft),
        headlineSmall: _grotesk(
            size: 24,
            weight: FontWeight.w700,
            height: 32 / 24,
            spacing: 0,
            color: MitlistColors.surfaceSoft),
        titleLarge: _grotesk(
            size: 22,
            weight: FontWeight.w700,
            height: 28 / 22,
            spacing: 0,
            color: MitlistColors.surfaceSoft),
        titleMedium: _grotesk(
            size: 16,
            weight: FontWeight.w600,
            height: 24 / 16,
            spacing: 0.15,
            color: MitlistColors.surfaceSoft),
        titleSmall: _grotesk(
            size: 14,
            weight: FontWeight.w600,
            height: 20 / 14,
            spacing: 0.1,
            color: MitlistColors.surfaceSoft),
        bodyLarge: _grotesk(
            size: 16,
            weight: FontWeight.w400,
            height: 24 / 16,
            spacing: 0.5,
            color: MitlistColors.surfaceSoft),
        bodyMedium: _grotesk(
            size: 14,
            weight: FontWeight.w400,
            height: 20 / 14,
            spacing: 0.25,
            color: MitlistColors.surfaceSoft),
        bodySmall: _grotesk(
            size: 12,
            weight: FontWeight.w400,
            height: 16 / 12,
            spacing: 0.4,
            color: MitlistColors.neutral300),
        labelLarge: _grotesk(
            size: 14,
            weight: FontWeight.w600,
            height: 20 / 14,
            spacing: 0.1,
            color: MitlistColors.surfaceSoft),
        labelMedium: _grotesk(
            size: 12,
            weight: FontWeight.w500,
            height: 16 / 12,
            spacing: 0.5,
            color: MitlistColors.neutral300),
        labelSmall: _grotesk(
            size: 11,
            weight: FontWeight.w500,
            height: 16 / 11,
            spacing: 0.5,
            color: MitlistColors.neutral400),
      );

  static TextStyle labelXSmall({Color? color}) => _grotesk(
        size: 10,
        weight: FontWeight.w500,
        height: 1.2,
        spacing: 0.6,
        color: color ?? MitlistColors.textTertiary,
      );

  static TextStyle monoBody(
          {Color? color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: 14,
        fontWeight: weight,
        height: 1.43,
        letterSpacing: 0,
        color: color ?? MitlistColors.textPrimary,
      );

  // Logo uses Space Grotesk, the brand display face.
  static TextStyle logo({Color? color}) => _grotesk(
        size: 48,
        weight: FontWeight.w700,
        height: 1.0,
        color: color ?? MitlistColors.textPrimary,
      );
}
