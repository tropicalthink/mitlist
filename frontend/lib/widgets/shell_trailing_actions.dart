import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'app_icon.dart';

/// Trailing [IconButton]s shared across primary shell tabs so the top bar
/// stays predictable next to the bottom navigation.
///
/// Intentionally kept to two icons — screens often add their own actions, so
/// three shell icons quickly crowds the bar. Calendar is available from the
/// Home hub; notifications and account cover the time-sensitive cases.
List<Widget> shellTrailingActions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    IconButton(
      tooltip: l10n.shellNotifications,
      icon: const AppIcon(name: 'bellOutline'),
      onPressed: () => context.pushNamed('notifications'),
    ),
    IconButton(
      tooltip: l10n.shellAccount,
      icon: const AppIcon(name: 'userCircle'),
      onPressed: () => context.pushNamed('you'),
    ),
  ];
}
