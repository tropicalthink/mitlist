import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/group_provider.dart';
import '../../theme/spacing.dart';
import '../app_icon.dart';

/// Renders the "shared with `<group>`" banner. Isolated as its own
/// [ConsumerWidget] so `cachedGroupsProvider` changes only rebuild this widget,
/// not the entire list screen.
class ListGroupBanner extends ConsumerWidget {
  const ListGroupBanner({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(cachedGroupsProvider).valueOrNull ?? const [];
    final groupName = groups.where((g) => g.id == groupId).firstOrNull?.name;
    if (groupName == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.xs,
      ),
      child: Row(
        children: [
          AppIcon(
              name: 'userGroup', size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: MitlistSpacing.xs),
          Expanded(
            child: Text(
              l10n.listSharedWith(groupName),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
