import 'package:flutter/material.dart';

import 'colors.dart';

/// A household member's colour for initials badges: a pastel note colour
/// with dark ink in light mode, its dark tone with light ink in dark mode
/// (every pair at least 4.5:1, see test/theme/member_colors_test.dart).
///
/// Distinct within a household: members are numbered in a stable order
/// ([roster], sorted ids), so up to six people never share a colour. Without
/// a roster the id's own stable hash picks one.
class MemberColors {
  const MemberColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  static const _light = MitlistColors.notePalette;
  static const _dark = MitlistColors.notePaletteDark;

  static int get count => _light.length;

  /// The palette slot for [userId].
  static int indexFor(String userId, [Iterable<String> roster = const []]) {
    final ordered = roster.toSet().toList()..sort();
    final i = ordered.indexOf(userId);
    if (i >= 0) return i % _light.length;
    // FNV-1a: stable across runs and platforms, unlike String.hashCode.
    var hash = 0x811c9dc5;
    for (final unit in userId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash % _light.length;
  }

  static MemberColors of(
    String userId,
    Brightness brightness, [
    Iterable<String> roster = const [],
  ]) {
    final i = indexFor(userId, roster);
    return brightness == Brightness.dark
        ? MemberColors(
            background: _dark[i], foreground: MitlistColors.surfaceSoft)
        : MemberColors(
            background: _light[i], foreground: MitlistColors.textPrimary);
  }
}
