import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/screens/auth/join_landing_screen.dart';

import 'support/fakes.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal GoRouter with the screen under test and a HOME marker.
GoRouter _buildRouter(String code, FakeGroupService fakeGroupService) {
  return GoRouter(
    initialLocation: '/join/$code',
    routes: [
      GoRoute(
        path: '/join/:code',
        name: 'joinLanding',
        builder: (context, state) =>
            JoinLandingScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('HOME'))),
      ),
    ],
  );
}

Widget _buildApp(String code, FakeGroupService fakeGroupService) {
  final router = _buildRouter(code, fakeGroupService);
  return ProviderScope(
    overrides: [
      groupServiceProviderAsync
          .overrideWith((ref) async => fakeGroupService),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('JoinLandingScreen', () {
    testWidgets('renders the code and headline', (tester) async {
      final fake = FakeGroupService();
      await tester.pumpWidget(_buildApp('ABCD-1234', fake));
      await tester.pump();

      expect(find.text('Join household'), findsOneWidget);
      // Code segments are rendered in separate Text widgets per part
      expect(find.text('ABCD'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
    });

    testWidgets('tapping Join household calls joinGroup with uppercased code',
        (tester) async {
      final fake = FakeGroupService();
      fake.joinResult = Group(id: 'g1', name: 'My House', createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1));

      await tester.pumpWidget(_buildApp('sunny-taco', fake));
      await tester.pump();

      // AppButton solid variant uppercases the label text
      await tester.tap(find.text('JOIN NOW'));
      await tester.pumpAndSettle();

      expect(fake.joinCalls, hasLength(1));
      expect(fake.joinCalls.first.code, 'SUNNY-TACO');
    });

    testWidgets('shows success state after successful join', (tester) async {
      final fake = FakeGroupService();
      fake.joinResult = Group(id: 'g1', name: 'My House', createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1));

      await tester.pumpWidget(_buildApp('ABCD-1234', fake));
      await tester.pump();

      await tester.tap(find.text('JOIN NOW'));
      await tester.pumpAndSettle();

      expect(find.text('My House'), findsOneWidget);
      expect(find.text("You're in."), findsOneWidget);
      // Primary button in success state
      expect(find.text('GO TO HOUSEHOLD'), findsOneWidget);
    });

    testWidgets('failure shows AppAlert and no success state', (tester) async {
      final fake = FakeGroupService();
      fake.throwOnJoin = Exception('Invalid or expired code');

      await tester.pumpWidget(_buildApp('ABCD-1234', fake));
      await tester.pump();

      await tester.tap(find.text('JOIN NOW'));
      await tester.pumpAndSettle();

      // Error alert should be visible
      expect(find.textContaining('household switcher'), findsOneWidget);
      // Success state must NOT appear
      expect(find.text("You're in."), findsNothing);
    });

    testWidgets('Not now navigates to home', (tester) async {
      final fake = FakeGroupService();

      await tester.pumpWidget(_buildApp('ABCD-1234', fake));
      await tester.pump();

      await tester.tap(find.text('NOT NOW'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('Go to household navigates to home after success',
        (tester) async {
      final fake = FakeGroupService();
      fake.joinResult = Group(id: 'g1', name: 'My House', createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1));

      await tester.pumpWidget(_buildApp('ABCD-1234', fake));
      await tester.pump();

      await tester.tap(find.text('JOIN NOW'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('GO TO HOUSEHOLD'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
