import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

class _FakeGroupService implements GroupService {
  Group? created;

  @override
  Future<Group> createGroup(CreateGroupRequest request) async {
    created = Group(
      id: '33333333-3333-3333-3333-333333333333',
      name: request.name,
      isPersonal: false,
      memberCount: 1,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    return created!;
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
      expect(find.text('Join with invite code'), findsNothing);

      // Slow check: the hint paper appears rather than dead cork.
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Opening your board…'), findsOneWidget);

      groupsCompleter.complete(const []);
      await tester.pumpAndSettle();

      expect(find.text('Opening your board…'), findsNothing);
      expect(find.text('Create a household'), findsOneWidget);
      expect(find.text('Join with invite code'), findsOneWidget);
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

    testWidgets('create flow ends with a concise map into the real app',
        (tester) async {
      final service = _FakeGroupService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cachedGroupsProvider.overrideWith((ref) async => const []),
            groupServiceProviderAsync.overrideWith((ref) async => service),
            // Creating a household now seeds the Drift household cache, so
            // this screen needs a database. In-memory keeps it hermetic.
            appDatabaseProvider.overrideWithValue(
              AppDatabase(drift.DatabaseConnection(
                NativeDatabase.memory(),
                closeStreamsSynchronously: true,
              )),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Beat 1 → tapping the sticky note opens the inline name stage,
      // not a bottom sheet.
      await tester.tap(find.text('Create a household'));
      await tester.pumpAndSettle();
      expect(find.text('Name your household'), findsOneWidget);
      expect(find.text('HOUSEHOLD NAME'), findsOneWidget);
      expect(find.text('PIN IT TO THE BOARD'), findsOneWidget);

      // Beat 2 → writing the name on the note and pinning it creates the
      // household and tears off the invite slip.
      await tester.enterText(find.byType(TextField).first, 'Flat 4B');
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIN IT TO THE BOARD'));
      await tester.pumpAndSettle();

      expect(service.created?.name, 'Flat 4B');
      expect(find.text('Bring in your flatmates'), findsOneWidget);
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('TACO'), findsOneWidget);
      expect(find.text('CONTINUE'), findsOneWidget);

      // The handoff names the shell's three rules without asking the user to
      // complete a tutorial task or step through every feature.
      await tester.ensureVisible(find.text('CONTINUE'));
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Your household is ready'), findsOneWidget);
      expect(find.text('Home shows what needs attention'), findsOneWidget);
      expect(
        find.text('Tabs keep each part of the household in its place'),
        findsOneWidget,
      );
      expect(
        find.text('The + button adds something from anywhere'),
        findsOneWidget,
      );
      expect(find.text('OPEN FLAT 4B'), findsOneWidget);
    });
  });
}
