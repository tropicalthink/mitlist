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
    final scheme = Theme.of(context).colorScheme;
    final quietStyle = headerStyle.copyWith(color: scheme.onSurfaceVariant);
    // A divider and a quiet count, like a note's ticked items: the done
    // part of the list should read as finished, not as another heading.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              Text(l10n.listDetailCheckedOff, style: quietStyle),
              const SizedBox(width: MitlistSpacing.sm),
              MitlistOdometer(value: doneCount, textStyle: quietStyle),
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
