import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_icon.dart';

/// The small heart shown next to a supporter's name.
///
/// This is the social half of the supporter pack: a theme is private, but the
/// badge is what a housemate notices. Rendered in the accent colour so it
/// picks up whatever the viewer has chosen.
class SupporterBadge extends StatelessWidget {
  const SupporterBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.supporterBadgeLabel;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: AppIcon(
          name: 'heartSolid',
          size: size,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
