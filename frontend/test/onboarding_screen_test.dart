import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/screens/auth/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingScreen', () {
    testWidgets('shows loading indicator while checking existing groups',
        (tester) async {
      final groupsCompleter = Completer<List<Group>>();
      addTearDown(() {
        if (!groupsCompleter.isCompleted) {
          groupsCompleter.complete(const []);
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cachedGroupsProvider.overrideWith((ref) => groupsCompleter.future),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Create a household'), findsNothing);
    });

    testWidgets('redirects to home when user already has a household',
        (tester) async {
      final household = Group(
        id: '11111111-1111-1111-1111-111111111111',
        name: 'Flat 4B',
        isPersonal: false,
        memberCount: 2,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) =>
                const Scaffold(body: Text('HOME_MARKER')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cachedGroupsProvider.overrideWith((ref) async => [household]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HOME_MARKER'), findsOneWidget);
      expect(find.text('Create a household'), findsNothing);
    });
  });
}
