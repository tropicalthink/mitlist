import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../app_icon.dart';

/// A suggested item drawn as a faint line of the list itself: an icon where
/// the checkbox would be, the name, and a quiet note on the right. Tapping it
/// puts the item on the list. Suggestions look like what they become, so
/// they need no cards, colours or headings of their own to be understood.
class ListSuggestionLine extends StatelessWidget {
  const ListSuggestionLine({
    super.key,
    required this.name,
    required this.onTap,
    this.icon = 'plus',
    this.detail,
    this.semanticLabel,
  });

  final String name;
  final VoidCallback onTap;

  /// `plus` adds; other icons say the tap does something else (an item
  /// already on the list, a checked-off one coming back).
  final String icon;

  /// Quiet text at the end of the line: a category, "on the list", a reason.
  final String? detail;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel ?? name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                SizedBox(
                  width: MitlistSpacing.space11,
                  child: Center(
                    child: AppIcon(
                      name: icon,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(width: MitlistSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
