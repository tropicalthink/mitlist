import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/spacing.dart';
import '../app_icon.dart';
import '../odometer.dart';

/// Collapsible "Checked off" section header with a live count odometer.
class ListDoneSectionHeader extends StatelessWidget {
  const ListDoneSectionHeader({
    super.key,
    required this.doneCount,
    required this.expanded,
    required this.onToggle,
  });

  final int doneCount;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              Text(l10n.listDetailCheckedOff, style: headerStyle),
              const SizedBox(width: MitlistSpacing.sm),
              MitlistOdometer(value: doneCount, textStyle: headerStyle),
              const Spacer(),
              AppIcon(
                name: expanded ? 'chevronUp' : 'chevronDown',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
