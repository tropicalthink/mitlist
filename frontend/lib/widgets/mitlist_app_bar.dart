import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import 'shell_trailing_actions.dart';

/// A consistent, hub-style top app bar used across screens.
///
/// Intent:
/// - Flat (no elevation / no scrolled-under tint)
/// - Surface background (matches hub `SliverAppBar`)
/// - Consistent trailing spacing for action icons
///
/// When [showStandardActions] is true, appends [shellTrailingActions] after
/// any screen-specific [actions] (calendar, notifications, account).
class MitlistAppBar extends StatelessWidget implements PreferredSizeWidget {
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

  /// Screen-specific actions that appear before the shell standard ones.
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool showStandardActions;

  factory MitlistAppBar.titleText(
    String title, {
    Key? key,
    Widget? leading,
    List<Widget>? actions,
    bool? centerTitle,
    bool showStandardActions = true,
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
      showStandardActions: showStandardActions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final standardActions =
        showStandardActions ? shellTrailingActions(context) : const <Widget>[];

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
