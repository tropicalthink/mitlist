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
import 'package:shared_preferences/shared_preferences.dart';

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

/// A group service whose roster answers, for the welcome after joining.
class _RosterGroupService extends FakeGroupService {
  _RosterGroupService(this.roster);

  final List<GroupMemberProfile> roster;
  final List<String> rosterCalls = [];

  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async {
    rosterCalls.add(groupId);
    return roster;
  }
}

GroupMemberProfile _member(String id, String name, {DateTime? leftAt}) =>
    GroupMemberProfile(
      userId: id,
      displayName: name,
      role: 'member',
      leftAt: leftAt,
    );

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
  setUp(() {
    // Joining records the joiner checklist marker; opening the household
    // resets the shell's remembered tab.
    SharedPreferences.setMockInitialValues({});
  });

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
      expect(find.text('OPEN MY HOUSE'), findsOneWidget);
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

    testWidgets('Open {household} goes to Home, not the last tab',
        (tester) async {
      SharedPreferences.setMockInitialValues({'nav_last_tab_index': 3});
      final fake = FakeGroupService();
      fake.joinResult = Group(
          id: 'g1',
          name: 'My House',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));

      await _pumpApp(tester, 'ABCD-1234', fake);

      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN MY HOUSE'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('nav_last_tab_index'), 0);
      // Joined, not created: Home gives them the joiner checklist.
      expect(prefs.getBool('hub_quick_start_joined:g1'), isTrue);
    });

    testWidgets('after joining, shows who is already in the household',
        (tester) async {
      final fake = _RosterGroupService([
        _member('u1', 'Sam Rivera'),
        _member('u2', 'Ines Ortiz'),
        _member('u3', 'Ada Lovelace'),
        _member('u4', 'Tim Gone', leftAt: DateTime.utc(2026, 2, 1)),
      ]);
      fake.joinResult = Group(
          id: 'g1',
          name: 'Flat 3B',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));

      await _pumpApp(tester, 'ABCD-1234', fake);
      // Nobody is shown before the person has joined.
      expect(fake.rosterCalls, isEmpty);

      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      expect(fake.rosterCalls, ['g1']);
      expect(find.text('SR'), findsOneWidget);
      expect(find.text('IO'), findsOneWidget);
      expect(find.text('AL'), findsOneWidget);
      // Someone who left is not part of the household any more.
      expect(find.text('TG'), findsNothing);
      expect(find.bySemanticsLabel('Sam Rivera, Ines Ortiz, Ada Lovelace'),
          findsOneWidget);
      expect(find.text('OPEN FLAT 3B'), findsOneWidget);
    });

    testWidgets('a big household shows five faces and counts the rest',
        (tester) async {
      final fake = _RosterGroupService([
        for (final name in [
          'Ann A',
          'Ben B',
          'Cat C',
          'Dan D',
          'Eve E',
          'Fay F',
          'Gus G',
        ])
          _member(name, name),
      ]);
      fake.joinResult = Group(
          id: 'g1',
          name: 'Big House',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));

      await _pumpApp(tester, 'ABCD-1234', fake);
      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      for (final initials in ['AA', 'BB', 'CC', 'DD', 'EE']) {
        expect(find.text(initials), findsOneWidget);
      }
      expect(find.text('FF'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('a roster that fails to load still lets them in',
        (tester) async {
      // The default fake has no roster: listMembers throws.
      final fake = FakeGroupService();
      fake.joinResult = Group(
          id: 'g1',
          name: 'My House',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1));

      await _pumpApp(tester, 'ABCD-1234', fake);
      await tester.tap(find.text('ACCEPT INVITE'));
      await tester.pumpAndSettle();

      expect(find.text("You're in."), findsOneWidget);
      expect(find.text('OPEN MY HOUSE'), findsOneWidget);
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
