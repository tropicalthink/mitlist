import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/utils/notification_navigation.dart';

void main() {
  testWidgets('routes every supported notification payload', (tester) async {
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/home', name: 'home', builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/chores',
            name: 'chores',
            builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/money',
            name: 'money',
            builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/lists/:listId',
            name: 'listDetail',
            builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/recipes/:recipeId',
            name: 'recipeDetail',
            builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/meal-plan',
            name: 'mealPlan',
            builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/recurring',
            name: 'recurringExpenses',
            builder: (_, __) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final cases = <Map<String, dynamic>, String>{
      {'screen': 'choreDetail'}: '/chores',
      {'screen': 'expenseDetail'}: '/money',
      {'screen': 'settlements'}: '/money',
      {'screen': 'listDetail', 'id': 'list-1'}: '/lists/list-1',
      {'screen': 'recipeDetail', 'id': 'recipe-1'}: '/recipes/recipe-1',
      {'screen': 'mealPlan'}: '/meal-plan',
      {'screen': 'householdHub'}: '/home',
      {'screen': 'recurringExpenses'}: '/recurring',
    };

    for (final entry in cases.entries) {
      expect(
        await navigateNotificationPayload(
          router,
          entry.key,
          preserveInbox: false,
        ),
        isTrue,
      );
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, entry.value);
    }
  });

  testWidgets(
      'switches household before navigation and rejects unknown payloads',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, __) => const SizedBox()),
        GoRoute(
            path: '/home', name: 'home', builder: (_, __) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    String? selectedGroup;
    expect(
      await navigateNotificationPayload(
        router,
        {'screen': 'householdHub', 'group_id': 'group-2'},
        preserveInbox: false,
        switchGroup: (groupId) async => selectedGroup = groupId,
      ),
      isTrue,
    );
    expect(selectedGroup, 'group-2');
    expect(
      await navigateNotificationPayload(
        router,
        {'screen': 'unknown'},
        preserveInbox: false,
      ),
      isFalse,
    );
  });
}
