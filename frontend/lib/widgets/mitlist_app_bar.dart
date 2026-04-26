import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/spacing.dart';
import '../providers/group_provider.dart';
import '../services/group_id_validator.dart';
import '../sheets/invite_household_sheet.dart';

/// A consistent, hub-style top app bar used across screens.
///
/// Intent:
/// - Flat (no elevation / no scrolled-under tint)
/// - Surface background (matches hub `SliverAppBar`)
/// - Consistent trailing spacing for action icons
class MitlistAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const MitlistAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.showStandardActions = true,
  });

  final Widget title;
  final Widget? leading;
  /// Screen-specific actions that appear before the standard ones.
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool showStandardActions;

  factory MitlistAppBar.titleText(
    String title, {
    Key? key,
    Widget? leading,
    List<Widget>? actions,
    bool? centerTitle,
  }) {
    return MitlistAppBar(
      key: key,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Future<void> openInvite() async {
      try {
        final svc = await ref.read(groupServiceProviderAsync.future);
        final groups = await svc.listGroups(limit: 1);
        final groupId = groups.isEmpty ? null : groups.first.id;
        if (!isValidGroupId(groupId)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No household to invite to yet')),
          );
          return;
        }
        if (!context.mounted) return;
        await InviteHouseholdSheet.show(context, groupId: groupId!);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t create invite: $e')),
        );
      }
    }

    final standardActions = showStandardActions
        ? <Widget>[
            IconButton(
              tooltip: 'Invite',
              icon: const Icon(Icons.group_add_outlined),
              onPressed: openInvite,
            ),
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_outlined),
              onPressed: () => context.pushNamed('notifications'),
            ),
            IconButton(
              tooltip: 'Account',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.pushNamed('you'),
            ),
          ]
        : const <Widget>[];

    final mergedActions = <Widget>[
      ...?actions,
      ...standardActions,
    ];

    final actionsWithPad = mergedActions.isEmpty
        ? null
        : <Widget>[
            ...mergedActions,
            const SizedBox(width: MitlistSpacing.xs),
          ];

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      leading: leading,
      title: title,
      centerTitle: centerTitle,
      actions: actionsWithPad,
    );
  }
}

