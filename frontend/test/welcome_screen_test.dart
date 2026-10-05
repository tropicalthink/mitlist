import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/screens/auth/welcome_screen.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GuestAuthService implements AuthService {
  _GuestAuthService({required this.user});

  final User user;
  bool guestCreated = false;

  @override
  Future<TokenPair> createGuest({bool rememberMe = true}) async {
    guestCreated = true;
    return TokenPair(
      accessToken: 'guest-access',
      refreshToken: 'guest-refresh',
      user: user,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Answers the signed-out invite lookup; a null [result] fails it the way
/// an unknown code (404) or a dropped connection does.
class _PreviewGroupService implements GroupService {
  _PreviewGroupService(this.result);

  final PublicInvitePreview? result;
  final List<String> calls = [];

  @override
  Future<PublicInvitePreview> previewInvitePublic(String code) async {
    calls.add(code);
    final preview = result;
    if (preview == null) throw Exception('invite not found');
    return preview;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The welcome screen opened from an invite link, with [service] behind the
/// preview lookup.
Future<void> _pumpInviteWelcome(
  WidgetTester tester,
  _PreviewGroupService service, {
  String code = 'sunny-taco',
}) async {
  final router = GoRouter(
    initialLocation: '/welcome?invite=$code',
    routes: [
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => service),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final guestUser = User(
    id: '22222222-2222-2222-2222-222222222222',
    email: 'guest@example.com',
    firstName: 'Guest',
    lastName: 'User',
    isActive: true,
    isVerified: false,
    isGuest: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WelcomeScreen', () {
    testWidgets('preserves invite when navigating to login', (tester) async {
      final router = GoRouter(
        initialLocation: '/welcome?invite=SUNNY-TACO',
        routes: [
          GoRoute(
            path: '/welcome',
            name: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/login',
            name: 'login',
            builder: (context, state) => Scaffold(
              body: Text('login:${state.uri.queryParameters['invite']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIGN IN TO JOIN'));
      await tester.pumpAndSettle();

      expect(find.text('login:SUNNY-TACO'), findsOneWidget);
    });

    testWidgets('preserves invite when navigating to signup', (tester) async {
      final router = GoRouter(
        initialLocation: '/welcome?invite=SUNNY-TACO',
        routes: [
          GoRoute(
            path: '/welcome',
            name: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/signup',
            name: 'signup',
            builder: (context, state) => Scaffold(
              body: Text('signup:${state.uri.queryParameters['invite']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CREATE ACCOUNT TO JOIN'));
      await tester.pumpAndSettle();

      expect(find.text('signup:SUNNY-TACO'), findsOneWidget);
    });

    // The long-deferred "guest continue with invite" case (plans/048 stage
    // 7): re-deferred. An invitee is offered an account or sign-in, never a
    // guest door; whether a guest may join through an invite stays a product
    // question, and this pins today's answer.
    testWidgets('invite landing does not offer guest continue', (tester) async {
      final authService = _GuestAuthService(user: guestUser);
      final router = GoRouter(
        initialLocation: '/welcome?invite=SUNNY-TACO',
        routes: [
          GoRoute(
            path: '/welcome',
            name: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
        ],
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProviderAsync.overrideWith((ref) async => authService),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue as guest'), findsNothing);
      expect(find.text('CREATE ACCOUNT TO JOIN'), findsOneWidget);
      expect(find.text('SIGN IN TO JOIN'), findsOneWidget);
      expect(authService.guestCreated, isFalse);
      expect(container.read(authStateProvider), isFalse);
      expect(
        container.read(pendingAuthNavigationProvider),
        isNull,
      );
    });

    testWidgets('get started opens the tour', (tester) async {
      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/welcome',
            name: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/tour',
            name: 'tour',
            builder: (context, state) => const Scaffold(body: Text('tour')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The guest door is no longer on the welcome screen.
      expect(find.text('Continue as guest'), findsNothing);

      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      expect(find.text('tour'), findsOneWidget);
    });

    testWidgets('have an account goes to login', (tester) async {
      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/welcome',
            name: 'welcome',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/login',
            name: 'login',
            builder: (context, state) => const Scaffold(body: Text('login')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I HAVE AN ACCOUNT'));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
    });
  });

  group('WelcomeScreen invite preview', () {
    testWidgets('names who sent the invite and where it leads',
        (tester) async {
      final service = _PreviewGroupService(const PublicInvitePreview(
        householdName: 'Flat 3B',
        inviterName: 'Sam',
        memberCount: 3,
        status: InviteStatus.valid,
      ));
      await _pumpInviteWelcome(tester, service);

      expect(service.calls, ['SUNNY-TACO']);
      expect(find.text('SAM INVITED YOU'), findsOneWidget);
      expect(find.text('to Flat 3B \u00b7 3 people'), findsOneWidget);
      expect(find.text("YOU'RE INVITED"), findsNothing);
      // The code and the two doors stay.
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('TACO'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT TO JOIN'), findsOneWidget);
      expect(find.text('SIGN IN TO JOIN'), findsOneWidget);
    });

    testWidgets('without an inviter it still names the household',
        (tester) async {
      await _pumpInviteWelcome(
        tester,
        _PreviewGroupService(const PublicInvitePreview(
          householdName: 'Flat 3B',
          memberCount: 1,
          status: InviteStatus.valid,
        )),
      );

      expect(find.text("YOU'RE INVITED"), findsOneWidget);
      expect(find.text('Join Flat 3B to share lists, chores and money.'),
          findsOneWidget);
    });

    testWidgets('an expired invite says so', (tester) async {
      await _pumpInviteWelcome(
        tester,
        _PreviewGroupService(const PublicInvitePreview(
          householdName: 'Flat 3B',
          inviterName: 'Sam',
          memberCount: 3,
          status: InviteStatus.expired,
        )),
      );

      expect(find.text('THIS INVITE HAS EXPIRED'), findsOneWidget);
      expect(find.text('Ask whoever sent it for a new link.'), findsOneWidget);
      expect(find.text('SAM INVITED YOU'), findsNothing);
      expect(find.text('CREATE ACCOUNT TO JOIN'), findsOneWidget);
    });

    testWidgets('a failed lookup keeps the generic invite', (tester) async {
      await _pumpInviteWelcome(tester, _PreviewGroupService(null));

      expect(find.text("YOU'RE INVITED"), findsOneWidget);
      expect(
        find.text('Join the household to share lists, chores, and money.'),
        findsOneWidget,
      );
      expect(find.text('CREATE ACCOUNT TO JOIN'), findsOneWidget);
    });
  });
}
