import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/utils/notification_navigation.dart';

/// Regression tests for tapping a notification from the inbox.
///
/// The inbox (`/you/notifications`) is a root-level route sitting above the
/// app's StatefulShellRoute. Pushing a shell-branch route from there builds a
/// second shell while the first is still mounted, and both claim the same
/// branch navigatorKey GlobalKeys:
///
///   'package:flutter/src/widgets/navigator.dart': Failed assertion:
///   '!keyReservation.contains(key)': is not true.
///
/// The flat router in notification_navigation_test.dart cannot catch this — it
/// has no shell — so the structure is mirrored here.
final _homeNavKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _choresNavKey = GlobalKey<NavigatorState>(debugLabel: 'chores');

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => shell,
        branches: [
          StatefulShellBranch(navigatorKey: _homeNavKey, routes: [
            GoRoute(
                path: '/home',
                name: 'home',
                builder: (_, __) => const Text('HOME')),
          ]),
          StatefulShellBranch(navigatorKey: _choresNavKey, routes: [
            GoRoute(
                path: '/chores',
                name: 'chores',
                builder: (_, __) => const Text('CHORES')),
          ]),
        ],
      ),
      GoRoute(
        path: '/you',
        name: 'you',
        builder: (_, __) => const Text('YOU'),
        routes: [
          GoRoute(
              path: 'notifications',
              name: 'notifications',
              builder: (_, __) => const Text('INBOX')),
        ],
      ),
      GoRoute(
        path: '/weekly-summary/:groupId',
        name: 'weeklySummary',
        builder: (_, state) =>
            Text('SUMMARY:${state.pathParameters['groupId']}'),
      ),
    ],
  );
}

/// Reproduces the real sequence: the user is on a shell tab, opens the inbox,
/// then taps a notification.
Future<GoRouter> _openInbox(WidgetTester tester) async {
  final router = _buildRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  unawaited(router.pushNamed('notifications'));
  await tester.pumpAndSettle();
  expect(find.text('INBOX'), findsOneWidget);
  return router;
}

void main() {
  testWidgets(
      'opening a shell-branch destination from the inbox does not '
      'duplicate the branch navigator keys', (tester) async {
    final router = await _openInbox(tester);

    for (final payload in [
      {'screen': 'householdHub'},
      {'screen': 'choreDetail'},
    ]) {
      expect(
        await navigateNotificationPayload(router, payload, preserveInbox: true),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'navigating to ${payload['screen']} threw',
      );
    }
  });

  testWidgets(
      'a shell destination replaces the inbox rather than stacking '
      'on top of it', (tester) async {
    final router = await _openInbox(tester);

    await navigateNotificationPayload(router, {'screen': 'householdHub'},
        preserveInbox: true);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    // go, not push: the inbox is no longer on the stack underneath, so there
    // is nothing to pop back to. (Asserting on the URI would prove nothing —
    // go_router reports the base location for imperative pushes either way.)
    expect(router.canPop(), isFalse);
  });

  testWidgets('the weekly summary is pushed, keeping the inbox underneath',
      (tester) async {
    final router = await _openInbox(tester);

    expect(
      await navigateNotificationPayload(
        router,
        {'screen': 'weeklySummary', 'group_id': 'group-1'},
        preserveInbox: true,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SUMMARY:group-1'), findsOneWidget);

    // Pushed, so back returns to the inbox the notification was tapped in.
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('INBOX'), findsOneWidget);
  });

  testWidgets('a weekly summary payload without a group falls back to the hub',
      (tester) async {
    final router = await _openInbox(tester);

    expect(
      await navigateNotificationPayload(router, {'screen': 'weeklySummary'},
          preserveInbox: true),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('an FCM tap (preserveInbox: false) still reaches the summary',
      (tester) async {
    final router = _buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      await navigateNotificationPayload(
        router,
        {'screen': 'weeklySummary', 'group_id': 'group-2'},
        preserveInbox: false,
      ),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SUMMARY:group-2'), findsOneWidget);
  });
}
