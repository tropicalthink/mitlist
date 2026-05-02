import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Trailing [IconButton]s shared across primary shell tabs so the top bar
/// stays predictable next to the bottom navigation.
List<Widget> shellTrailingActions(BuildContext context) {
  return [
    IconButton(
      tooltip: 'Calendar',
      icon: const Icon(Icons.calendar_month_outlined),
      onPressed: () => context.pushNamed('calendar'),
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
  ];
}
