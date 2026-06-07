import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Trailing [IconButton]s shared across primary shell tabs so the top bar
/// stays predictable next to the bottom navigation.
///
/// Intentionally kept to two icons — screens often add their own actions, so
/// three shell icons quickly crowds the bar. Calendar is available from the
/// Home hub; notifications and account cover the time-sensitive cases.
List<Widget> shellTrailingActions(BuildContext context) {
  return [
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
  ];
}
