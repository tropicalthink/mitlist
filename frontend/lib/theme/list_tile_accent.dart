import 'package:flutter/material.dart';

import 'colors.dart';

/// Pastel tile backgrounds and a header stripe derived from a stable seed
/// (e.g. list id), using Mitlist palette tokens only.
class ListTileAccent {
  const ListTileAccent({
    required this.tileBackground,
    required this.titleColor,
    required this.iconColor,
    required this.stripe,
  });

  final Color tileBackground;
  final Color titleColor;
  final Color iconColor;
  final Color stripe;

  /// Snippet / secondary lines on the tinted card: blends title into tile
  /// so we never use flat gray on a pastel (better contrast + hue harmony).
  Color get snippetOnTile => Color.alphaBlend(
        titleColor.withValues(alpha: 0.58),
        tileBackground,
      );

  static ListTileAccent fromSeed(String seed, Brightness brightness) {
    final i = seed.hashCode.abs() % 5;
    if (brightness == Brightness.dark) {
      const backgrounds = <Color>[
        MitlistColors.neutral800,
        MitlistColors.primary900,
        MitlistColors.neutral900,
        MitlistColors.success900,
        MitlistColors.warning900,
      ];
      return ListTileAccent(
        tileBackground: backgrounds[i],
        titleColor: MitlistColors.surfaceSoft,
        iconColor: MitlistColors.primary300,
        stripe: MitlistColors.primary400,
      );
    }

    const backgrounds = <Color>[
      MitlistColors.primary100,
      MitlistColors.success100,
      MitlistColors.warning100,
      MitlistColors.primary50,
      MitlistColors.neutral100,
    ];
    const icons = <Color>[
      MitlistColors.primary600,
      MitlistColors.success700,
      MitlistColors.warning800,
      MitlistColors.primary500,
      MitlistColors.primary500,
    ];
    return ListTileAccent(
      tileBackground: backgrounds[i],
      titleColor: MitlistColors.textPrimary,
      iconColor: icons[i],
      stripe: MitlistColors.primary500,
    );
  }
}
