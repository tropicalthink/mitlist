import 'package:flutter/material.dart';

import 'colors.dart';

/// The accent colours a person can pick for the app.
///
/// [clementine] is the default and what everyone gets; the others are part of
/// the supporter pack. An accent replaces the primary ramp of the theme and
/// nothing else — surfaces, text, and the status colours stay the same, so
/// every accent reads as the same app in a different jacket.
///
/// Persisted by name, so never rename a value without a migration in
/// `AccentNotifier`.
enum MitlistAccent {
  clementine(MitlistAccentPalette(
    s50: MitlistColors.primary50,
    s100: MitlistColors.primary100,
    s200: MitlistColors.primary200,
    s300: MitlistColors.primary300,
    s400: MitlistColors.primary400,
    s500: MitlistColors.primary500,
    s600: MitlistColors.primary600,
    s700: MitlistColors.primary700,
    s800: MitlistColors.primary800,
    s900: MitlistColors.primary900,
    s950: MitlistColors.primary950,
  )),
  moss(MitlistAccentPalette(
    s50: Color(0xFFF0FDFA),
    s100: Color(0xFFCCFBF1),
    s200: Color(0xFF99F6E4),
    s300: Color(0xFF5EEAD4),
    s400: Color(0xFF2DD4BF),
    s500: Color(0xFF14B8A6),
    s600: Color(0xFF0D9488),
    s700: Color(0xFF0F766E),
    s800: Color(0xFF115E59),
    s900: Color(0xFF134E4A),
    s950: Color(0xFF042F2E),
  )),
  sky(MitlistAccentPalette(
    s50: Color(0xFFF0F9FF),
    s100: Color(0xFFE0F2FE),
    s200: Color(0xFFBAE6FD),
    s300: Color(0xFF7DD3FC),
    s400: Color(0xFF38BDF8),
    s500: Color(0xFF0EA5E9),
    s600: Color(0xFF0284C7),
    s700: Color(0xFF0369A1),
    s800: Color(0xFF075985),
    s900: Color(0xFF0C4A6E),
    s950: Color(0xFF082F49),
  )),
  berry(MitlistAccentPalette(
    s50: Color(0xFFFDF2F8),
    s100: Color(0xFFFCE7F3),
    s200: Color(0xFFFBCFE8),
    s300: Color(0xFFF9A8D4),
    s400: Color(0xFFF472B6),
    s500: Color(0xFFEC4899),
    s600: Color(0xFFDB2777),
    s700: Color(0xFFBE185D),
    s800: Color(0xFF9D174D),
    s900: Color(0xFF831843),
    s950: Color(0xFF500724),
  )),
  violet(MitlistAccentPalette(
    s50: Color(0xFFF5F3FF),
    s100: Color(0xFFEDE9FE),
    s200: Color(0xFFDDD6FE),
    s300: Color(0xFFC4B5FD),
    s400: Color(0xFFA78BFA),
    s500: Color(0xFF8B5CF6),
    s600: Color(0xFF7C3AED),
    s700: Color(0xFF6D28D9),
    s800: Color(0xFF5B21B6),
    s900: Color(0xFF4C1D95),
    s950: Color(0xFF2E1065),
  ));

  const MitlistAccent(this.palette);

  /// The primary colour ramp this accent supplies to the theme.
  final MitlistAccentPalette palette;

  /// What everyone gets without the supporter pack.
  static const MitlistAccent defaultAccent = MitlistAccent.clementine;

  /// Whether this accent is free for everyone or part of the supporter pack.
  bool get isFree => this == defaultAccent;

  /// Parses a persisted name, falling back to the default for anything
  /// unknown so a removed accent can never wedge the app on startup.
  static MitlistAccent fromName(String? name) {
    for (final accent in values) {
      if (accent.name == name) return accent;
    }
    return defaultAccent;
  }
}

/// An eleven-step colour ramp, lightest to darkest, mirroring the
/// `MitlistColors.primaryNNN` constants the theme was originally built on.
class MitlistAccentPalette {
  const MitlistAccentPalette({
    required this.s50,
    required this.s100,
    required this.s200,
    required this.s300,
    required this.s400,
    required this.s500,
    required this.s600,
    required this.s700,
    required this.s800,
    required this.s900,
    required this.s950,
  });

  final Color s50;
  final Color s100;
  final Color s200;
  final Color s300;
  final Color s400;
  final Color s500;
  final Color s600;
  final Color s700;
  final Color s800;
  final Color s900;
  final Color s950;
}
