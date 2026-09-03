import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show appDatabaseProvider;
import 'package:mitlist/screens/auth/join_landing_screen.dart';
import 'package:mitlist/storage/app_database.dart';

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

/// The container behind the most recent [_buildApp], so a test can read
/// what the screen left in the shared providers.
late ProviderContainer _container;

Widget _buildApp(String code, FakeGroupService fakeGroupService) {
  final router = _buildRouter(code, fakeGroupService);
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => true),
      groupServiceProviderAsync.overrideWith((ref) async => fakeGroupService),
      // Accepting seeds the Drift household cache, so the screen needs a
      // database. In-memory keeps it hermetic.
      appDatabaseProvider.overrideWithValue(
        AppDatabase(drift.DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        )),
      ),
    ],
    child: Builder(
      builder: (context) {
        _container = ProviderScope.containerOf(context);
        return MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    ),
  );
}

InvitePreview _preview({
  String name = 'Casa Verde',
  int members = 3,
  InviteStatus status = InviteStatus.valid,
}) =>
    InvitePreview(
      code: 'ABCD-1234',
      groupId: 'g1',
      groupName: name,
      memberCount: members,
      expiresAt: DateTime.utc(2030, 1, 1),
      status: status,
    );

/// Pumps until the preview lookup has resolved and the entry page is up.
Future<void> _pumpApp(
  WidgetTester tester,
  String code,
  FakeGroupService fake,
) async {
  await tester.pumpWidget(_buildApp(code, fake));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('JoinLandingScreen', () {
    testWidgets('looks the invite up and shows the household', (tester) async {
      final fake = FakeGroupService();
      fake.previewResult = _preview(name: 'Casa Verde', members: 3);

      await _pumpApp(tester, 'abcd-1234', fake);

      expect(fake.previewCalls, ['ABCD-1234']);
      expect(find.text('Join household'), findsOneWidget);
      expect(find.text("You've been invited to join"), findsOneWidget);
      expect(find.text('Casa Verde'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
      expect(find.text('ABCD-1234'), findsOneWidget);
      // Both choices are offered. AppButton uppercases its label.
      expect(find.text('ACCEPT INVITE'), findsOneWidget);
      expect(find.text('DECLINE'), findsOneWidget);
    });

    testWidgets('accepting calls joinGroup with the uppercased code',
        (tester) async {
      final fake = FakeGroupService();
      fake.joinResult = Group(
          id: 'g1',
          name: 'My House',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));

      await _pumpApp(tester, 'sunny-taco', fake);

      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      expect(fake.joinCalls, hasLength(1));
      expect(fake.joinCalls.first.code, 'SUNNY-TACO');
    });

    testWidgets('shows success state after accepting', (tester) async {
      final fake = FakeGroupService();
      fake.joinResult = Group(
          id: 'g1',
          name: 'My House',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));

      await _pumpApp(tester, 'ABCD-1234', fake);

      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      expect(find.text('My House'), findsOneWidget);
      expect(find.text("You're in."), findsOneWidget);
      expect(find.text('GO TO HOUSEHOLD'), findsOneWidget);
    });

    testWidgets('accepting puts the household in the shared cache',
        (tester) async {
      // The hub reads this cache to decide between the household and the
      // setup flow; a join that left it empty sent new members to setup.
      final fake = FakeGroupService();
      fake.joinResult = Group(
          id: 'g1',
          name: 'My House',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));
      fake.listResult = [fake.joinResult];

      await _pumpApp(tester, 'ABCD-1234', fake);

      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      final groups = await _container.read(cachedGroupsProvider.future);
      expect(groups.map((g) => g.id), contains('g1'));
    });

    testWidgets('a failed join shows the error and stays on the page',
        (tester) async {
      final fake = FakeGroupService();
      fake.throwOnJoin = Exception('Invalid or expired code');

      await _pumpApp(tester, 'ABCD-1234', fake);

      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('household switcher'), findsOneWidget);
      expect(find.text("You're in."), findsNothing);
      expect(find.text('ACCEPT INVITE'), findsOneWidget);
    });

    testWidgets('declining navigates home without joining', (tester) async {
      final fake = FakeGroupService();

      await _pumpApp(tester, 'ABCD-1234', fake);

      await tester.tap(find.text('DECLINE'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(fake.joinCalls, isEmpty);
    });

    testWidgets('Go to household navigates home after success', (tester) async {
      final fake = FakeGroupService();
      fake.joinResult = Group(
          id: 'g1',
          name: 'My House',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));

      await _pumpApp(tester, 'ABCD-1234', fake);

      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('GO TO HOUSEHOLD'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('an expired invite cannot be accepted', (tester) async {
      final fake = FakeGroupService();
      fake.previewResult = _preview(status: InviteStatus.expired);

      await _pumpApp(tester, 'ABCD-1234', fake);

      expect(find.textContaining('has expired'), findsOneWidget);
      expect(find.text('ACCEPT INVITE'), findsNothing);
      expect(find.text('DISMISS'), findsOneWidget);
    });

    testWidgets('an existing member is offered the household instead',
        (tester) async {
      final fake = FakeGroupService();
      fake.previewResult =
          _preview(name: 'Casa Verde', status: InviteStatus.alreadyMember);

      await _pumpApp(tester, 'ABCD-1234', fake);

      expect(find.textContaining('already a member of Casa Verde'),
          findsOneWidget);
      expect(find.text('ACCEPT INVITE'), findsNothing);

      await tester.tap(find.text('GO TO HOUSEHOLD'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(fake.joinCalls, isEmpty);
    });

    testWidgets('a failed lookup still lets the user try to accept',
        (tester) async {
      final fake = FakeGroupService();
      fake.throwOnPreview = Exception('offline');

      await _pumpApp(tester, 'ABCD-1234', fake);

      expect(
          find.textContaining("Couldn't load invite details"), findsOneWidget);
      expect(find.text('ABCD-1234'), findsOneWidget);
      expect(find.text('ACCEPT INVITE'), findsOneWidget);
      expect(find.text('DECLINE'), findsOneWidget);
    });
  });
}
