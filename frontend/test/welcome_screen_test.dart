import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/screens/auth/welcome_screen.dart';
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
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIGN IN'));
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
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CREATE FREE HOUSEHOLD'));
      await tester.pumpAndSettle();

      expect(find.text('signup:SUNNY-TACO'), findsOneWidget);
    });

    testWidgets('guest continue with invite queues join landing navigation',
        (tester) async {
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
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      expect(authService.guestCreated, isTrue);
      expect(container.read(authStateProvider), isTrue);
      expect(
        container.read(pendingAuthNavigationProvider),
        '/join/SUNNY-TACO',
      );
    });

    testWidgets('guest continue without invite queues onboarding navigation',
        (tester) async {
      final authService = _GuestAuthService(user: guestUser);
      final router = GoRouter(
        initialLocation: '/welcome',
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
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue as guest'));
      await tester.pumpAndSettle();

      expect(container.read(pendingAuthNavigationProvider), '/onboarding');
    });
  });
}
