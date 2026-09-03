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
  }) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProviderAsync.overrideWith((ref) async => authService),
          oauthProvidersProvider.overrideWith(
            (ref) async => (google: true, apple: false, password: true),
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
    testWidgets('walks six pages on one shared sample household',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final authService = _GuestAuthService(user: guestUser);
      final container = await pumpTour(tester, authService: authService);

      // 1 — why
      expect(find.text('Who bought milk, who owes what, whose turn is it?'),
          findsOneWidget);
      expect(find.text('Weekend groceries · 4 to buy'), findsOneWidget);
      expect(find.text('Overall, you are owed \$8.00'), findsOneWidget);
      expect(find.text('Take out bins is overdue'), findsOneWidget);
      await next(tester, 'SHOW ME');

      // 2 — lists: ticking an item changes the count seen later.
      expect(find.text('One list. Everyone adds. Whoever is at the shop buys.'),
          findsOneWidget);
      await tester.tap(find.text('Coffee beans'));
      await tester.pumpAndSettle();
      await next(tester, 'NEXT');

      // 3 — money: leaving Ines out moves the balance.
      expect(find.text('Overall, you are owed \$8.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour-split-ines')));
      await tester.pumpAndSettle();
      expect(find.text('Sam owes you \$21.00'), findsOneWidget);
      expect(find.text('Overall, you are owed \$1.00'), findsOneWidget);
      await next(tester, 'NEXT');

      // 4 — chores: ticking mine shows who gets it next.
      await tester.tap(find.text('Clean bathroom'));
      await tester.pumpAndSettle();
      expect(find.text('Next: Sam, in 7 days'), findsOneWidget);
      await next(tester, 'NEXT');

      // 5 — recipes: ingredients land on the list from page 2.
      expect(find.text('Weekend groceries · 3 to buy'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour-add-ingredients')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('tour-ingredients-added')), findsOneWidget);
      expect(find.text('Weekend groceries · 6 to buy'), findsOneWidget);
      // Let the toast run out so no timer is left pending.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await next(tester, 'NEXT');

      // 6 — account choice, with the guest door.
      expect(find.text('Now do it with the people you actually live with.'),
          findsOneWidget);
      expect(find.text('NEXT'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      expect(authService.guestCreated, isTrue);
      expect(container.read(authStateProvider), isTrue);
      expect(container.read(isGuestProvider), isTrue);
      expect(container.read(pendingAuthNavigationProvider), '/onboarding');
    });

    testWidgets('skip jumps to the account page and email goes to signup',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final authService = _GuestAuthService(user: guestUser);
      await pumpTour(tester, authService: authService);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Now do it with the people you actually live with.'),
          findsOneWidget);
      expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
      expect(find.text('CONTINUE WITH APPLE'), findsNothing);

      // Ghost buttons keep their case; only the provider buttons shout.
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();

      expect(find.text('signup'), findsOneWidget);
      expect(authService.guestCreated, isFalse);
    });
  });
}
