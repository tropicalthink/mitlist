import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/spacing.dart';
import 'chip.dart';

/// Common things to start with, under an empty state's main action. A tap
/// opens the usual create sheet prefilled, so nothing exists until the person
/// confirms it: sample chores or expenses in a shared household could be
/// mistaken for real obligations (plans/048, Decision 2).
class EmptyStateSuggestions extends StatelessWidget {
  const EmptyStateSuggestions({super.key, required this.suggestions});

  final List<({String label, VoidCallback onTap})> suggestions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.emptyStateSuggestionsTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final s in suggestions)
              Semantics(
                button: true,
                child: AppChip(
                  label: s.label,
                  leading: const Icon(Icons.add),
                  onSelected: (_) => s.onTap(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
