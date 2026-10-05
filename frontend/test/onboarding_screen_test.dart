import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show appDatabaseProvider;
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/screens/auth/onboarding_screen.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _newGroupId = '33333333-3333-3333-3333-333333333333';

class _FakeGroupService implements GroupService {
  Group? created;
  String? joinedWith;

  @override
  Future<Group> createGroup(CreateGroupRequest request) async {
    created = Group(
      id: _newGroupId,
      name: request.name,
      isPersonal: false,
      memberCount: 1,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    return created!;
  }

  @override
  Future<Group> joinGroup(JoinGroupRequest request) async {
    joinedWith = request.code;
    return Group(
      id: '44444444-4444-4444-4444-444444444444',
      name: 'Flat 3B',
      isPersonal: false,
      memberCount: 3,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<GroupInvite> inviteMember(
    String groupId,
    InviteMemberRequest request,
  ) async {
    return GroupInvite(
      id: 'invite-1',
      groupId: groupId,
      code: 'SUNNY-TACO',
      expiresAt: DateTime.utc(2027, 1, 1),
      usedBy: null,
      usedAt: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// The screen under a router with a Home marker, a fake group service and
  /// an in-memory database (creating or joining seeds the household cache).
  Future<_FakeGroupService> pumpOnboarding(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeGroupService();
    final db = AppDatabase(drift.DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
    addTearDown(db.close);
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
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => const []),
          groupServiceProviderAsync.overrideWith((ref) async => service),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  /// Create → name → pin, leaving the invite beat on screen.
  Future<_FakeGroupService> createHousehold(WidgetTester tester) async {
    final service = await pumpOnboarding(tester);
    await tap(tester, 'Create a household');
    await tester.enterText(find.byType(TextField).first, 'Flat 4B');
    await tester.pumpAndSettle();
    await tap(tester, 'PIN IT TO THE BOARD');
    return service;
  }

  group('OnboardingScreen', () {
    testWidgets('holds the board until membership resolves, then shows choose',
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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();

      // Membership unknown: the bare board holds, no create/join flash that
      // would have to be yanked away from an existing account.
      expect(find.text('Create a household'), findsNothing);
      expect(find.text('Have an invite code?'), findsNothing);

      // Slow check: the hint paper appears rather than dead cork.
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Opening your board…'), findsOneWidget);

      groupsCompleter.complete(const []);
      await tester.pumpAndSettle();

      expect(find.text('Opening your board…'), findsNothing);
      // Join and create on one screen, the code field right there.
      expect(find.text('Have an invite code?'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Create a household'), findsOneWidget);
    });

    testWidgets('redirects to home when user already has a household',
        (tester) async {
      // Deliberately no `isPersonal`: the backend never serializes that field,
      // so this is what a real household looks like after `GET /groups`. The
      // old `isPersonal == false` check failed exactly this shape and re-ran
      // onboarding on every OAuth sign-in.
      final household = Group(
        id: '11111111-1111-1111-1111-111111111111',
        name: 'Flat 4B',
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
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HOME_MARKER'), findsOneWidget);
      expect(find.text('Create a household'), findsNothing);
    });

    testWidgets('joining with a pasted link goes straight home',
        (tester) async {
      final service = await pumpOnboarding(tester);

      // Whatever people were sent works: the link turns into its code.
      await tester.enterText(
        find.byType(TextField),
        'https://app.mitlist.me/join/sunny-taco',
      );
      await tester.pumpAndSettle();
      await tap(tester, 'JOIN');

      expect(service.joinedWith, 'SUNNY-TACO');
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('create flow: name, invite or later, then what first',
        (tester) async {
      final service = await pumpOnboarding(tester);

      await tap(tester, 'Create a household');
      expect(find.text('Name your household'), findsOneWidget);
      // The currency is a guess shown in a line, not a question.
      expect(find.text('Currency: USD'), findsOneWidget);
      await tap(tester, 'Change');
      expect(find.text('Currency: USD'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Flat 4B');
      await tester.pumpAndSettle();
      await tap(tester, 'PIN IT TO THE BOARD');

      expect(service.created?.name, 'Flat 4B');
      expect(find.text('Bring in your flatmates'), findsOneWidget);
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('TACO'), findsOneWidget);

      // Inviting can wait: Home's checklist asks again.
      await tap(tester, 'LATER');

      // The old "three things to know" recap is gone; one question instead.
      expect(find.text('Your household is ready'), findsNothing);
      expect(find.text('What do you want to sort out first?'), findsOneWidget);
      expect(find.text('SHOPPING LISTS'), findsOneWidget);
      expect(find.text('CHORES'), findsOneWidget);
      expect(find.text('Just looking'), findsOneWidget);

      await tap(tester, 'SPLITTING COSTS');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hub_quick_start_intent:$_newGroupId'), 'money');
      expect(prefs.getBool('hub_quick_start_invited:$_newGroupId'), isNull);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('copying the link counts as inviting and says Continue',
        (tester) async {
      // A clipboard that accepts the copy.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await createHousehold(tester);
      expect(find.text('LATER'), findsOneWidget);

      await tap(tester, 'Copy link');

      expect(find.text('CONTINUE'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('hub_quick_start_invited:$_newGroupId'), isTrue);
    });

    testWidgets('"Just looking" stores no intent', (tester) async {
      await createHousehold(tester);
      await tap(tester, 'LATER');
      await tap(tester, 'Just looking');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hub_quick_start_intent:$_newGroupId'), isNull);
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
