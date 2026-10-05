import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/oauth_provider.dart';
import 'package:mitlist/screens/auth/signup_screen.dart';
import 'package:mitlist/services/auth_service.dart';

/// Covers the registration password rules (the complexity policy, and that
/// it is not reachable past the form), the single password field with its
/// show/hide button (plans/048 stage 6), and that a successful registration
/// asks for the emailed code on the same screen.
///
/// The default auth service override throws deliberately — every password
/// case here must be rejected by client-side validation before any network
/// call is attempted. If one of them ever fails with `UnimplementedError`,
/// the form let a bad password through to the API.
Future<void> _pumpSignup(
  WidgetTester tester, {
  AuthService? authService,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProviderAsync.overrideWith(
          (ref) async =>
              authService ??
              (throw UnimplementedError('network must not be used')),
        ),
        // Password-only: no provider buttons, so the form is unfolded from
        // the first frame and these cases reach it without a tap.
        oauthProvidersProvider.overrideWith(
          (ref) async =>
              (google: false, apple: false, password: true, guest: false),
        ),
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

Future<void> _fillForm(WidgetTester tester, {required String password}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Ada Lovelace');
  await tester.enterText(fields.at(1), 'ada@example.com');
  await tester.enterText(fields.at(2), password);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  // The solid button variant renders its label uppercased.
  await tester.tap(find.text('CREATE ACCOUNT'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _FakeAuthService implements AuthService {
  RegisterRequest? registered;
  bool loginCalled = false;

  @override
  Future<RegistrationResult> register(
    RegisterRequest request, {
    bool rememberMe = true,
  }) async {
    registered = request;
    return const RegistrationResult(verificationRequired: true);
  }

  /// The account cannot sign in before its email is confirmed, so sign-up
  /// must never try.
  @override
  Future<TokenPair> login(
    LoginRequest request, {
    bool rememberMe = true,
  }) {
    loginCalled = true;
    throw StateError('sign-up must not sign in before the code step');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('one password field, with a show/hide button instead of a '
      'confirmation field', (tester) async {
    await _pumpSignup(tester);
    expect(find.text('CONFIRM PASSWORD'), findsNothing);
    // name, email, password
    expect(find.byType(TextField), findsNWidgets(3));

    final password = find.byType(TextField).at(2);
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('renders the requirement checklist', (tester) async {
    await _pumpSignup(tester);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('One uppercase letter'), findsOneWidget);
    expect(find.text('One number'), findsOneWidget);
    expect(find.text('One special character'), findsOneWidget);
  });

  testWidgets('blocks a password missing an uppercase letter', (tester) async {
    await _pumpSignup(tester);
    await _fillForm(tester, password: 'passw0rd!');
    await _submit(tester);

    expect(find.text('Password does not meet the requirements below.'),
        findsOneWidget);
  });

  testWidgets('blocks a password missing a number', (tester) async {
    await _pumpSignup(tester);
    await _fillForm(tester, password: 'Password!');
    await _submit(tester);

    expect(find.text('Password does not meet the requirements below.'),
        findsOneWidget);
  });

  testWidgets('blocks a password missing a special character', (tester) async {
    await _pumpSignup(tester);
    await _fillForm(tester, password: 'Passw0rdd');
    await _submit(tester);

    expect(find.text('Password does not meet the requirements below.'),
        findsOneWidget);
  });

  testWidgets('a short password reports length, not the generic policy error',
      (tester) async {
    await _pumpSignup(tester);
    await _fillForm(tester, password: 'Pa0!');
    await _submit(tester);

    expect(
        find.text('Password must be at least 8 characters.'), findsOneWidget);
  });

  testWidgets('a valid registration asks for the emailed code on the same '
      'screen', (tester) async {
    final auth = _FakeAuthService();
    await _pumpSignup(tester, authService: auth);
    await _fillForm(tester, password: 'Passw0rd!');
    await _submit(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(auth.registered?.email, 'ada@example.com');
    expect(auth.registered?.password, 'Passw0rd!');
    expect(find.text('Enter the code we emailed to ada@example.com.'),
        findsOneWidget);
    expect(auth.loginCalled, isFalse);
  });
}
