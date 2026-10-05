import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/oauth_provider.dart';
import 'package:mitlist/screens/tour/tour_screen.dart';
import 'package:mitlist/services/auth_service.dart';
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

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/tour',
        routes: [
          GoRoute(
            path: '/tour',
            name: 'tour',
            builder: (context, state) => const TourScreen(),
          ),
          GoRoute(
            path: '/signup',
            name: 'signup',
            builder: (context, state) => const Scaffold(body: Text('signup')),
          ),
          GoRoute(
            path: '/login',
            name: 'login',
            builder: (context, state) => const Scaffold(body: Text('login')),
          ),
        ],
      );

  Future<ProviderContainer> pumpTour(
    WidgetTester tester, {
    required _GuestAuthService authService,
    bool guest = false,
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProviderAsync.overrideWith((ref) async => authService),
          oauthProvidersProvider.overrideWith(
            (ref) async =>
                (google: true, apple: false, password: true, guest: guest),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp.router(
              routerConfig: buildRouter(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> next(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('TourScreen', () {
    testWidgets(
        'walks three pages on one sample household, ending on the '
        'account choice', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final authService = _GuestAuthService(user: guestUser);
      final container =
          await pumpTour(tester, authService: authService, guest: true);

      // 1 — lists.
      expect(find.text('One list. Everyone adds. Whoever is at the shop buys.'),
          findsOneWidget);
      await tester.tap(find.text('Coffee beans'));
      await tester.pumpAndSettle();
      await next(tester, 'NEXT');

      // 2 — money: leaving Ines out moves the balance.
      expect(find.text('Overall, you are owed \$8.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour-split-ines')));
      await tester.pumpAndSettle();
      expect(find.text('Sam owes you \$21.00'), findsOneWidget);
      expect(find.text('Overall, you are owed \$1.00'), findsOneWidget);
      await next(tester, 'NEXT');

      // 3 — chores: ticking mine shows who gets it next.
      await tester.tap(find.text('Clean bathroom'));
      await tester.pumpAndSettle();
      expect(find.text('Next: Sam, in 7 days'), findsOneWidget);

      // The account choice sits under the chores; no page of its own, no
      // Next and no Skip left.
      expect(find.text('Now do it with the people you actually live with.'),
          findsOneWidget);
      expect(find.text('NEXT'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      await tester.ensureVisible(find.text('Continue as guest'));
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      expect(authService.guestCreated, isTrue);
      expect(container.read(authStateProvider), isTrue);
      expect(container.read(isGuestProvider), isTrue);
      expect(container.read(pendingAuthNavigationProvider), '/onboarding');
    });

    testWidgets('the guest door is closed unless the server offers it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final authService = _GuestAuthService(user: guestUser);
      await pumpTour(tester, authService: authService);
      await next(tester, 'NEXT');
      await next(tester, 'NEXT');

      expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
      expect(find.text('CONTINUE WITH APPLE'), findsNothing);
      expect(find.text('Continue with email'), findsOneWidget);
      expect(find.text('Continue as guest'), findsNothing);
      expect(authService.guestCreated, isFalse);

      // Ghost buttons keep their case; only the provider buttons shout.
      await tester.ensureVisible(find.text('Continue with email'));
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      expect(find.text('signup'), findsOneWidget);
    });

    testWidgets('skip on the first page goes straight to sign-up',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final authService = _GuestAuthService(user: guestUser);
      await pumpTour(tester, authService: authService);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('signup'), findsOneWidget);
      expect(authService.guestCreated, isFalse);
    });
  });
}
