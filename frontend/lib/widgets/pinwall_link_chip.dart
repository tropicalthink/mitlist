import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// A small tappable chip shown on a pinwall note that links to a chore, list, or
/// expense. Navigation-agnostic: the parent supplies [onTap]. Renders nothing for
/// unknown types (returns an empty widget) so a stray value is safe.
class PinwallLinkChip extends StatelessWidget {
  const PinwallLinkChip({
    super.key,
    required this.entityType, // 'chore' | 'list' | 'expense'
    required this.onTap,
    required this.color,
  });

  final String entityType;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (entityType) {
      'chore' => l10n.pinwallLinkedChore,
      'list' => l10n.pinwallLinkedList,
      'expense' => l10n.pinwallLinkedExpense,
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: l10n.pinwallLinkedTo(label),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
