import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/oauth_provider.dart';
import 'package:mitlist/screens/auth/signup_screen.dart';

/// Covers the registration password rules: the confirmation field, the
/// complexity policy, and the fact that neither is reachable past the form.
///
/// The auth service override throws deliberately — every case here must be
/// rejected by client-side validation before any network call is attempted.
/// If one of these tests ever fails with `UnimplementedError`, the form let a
/// bad password through to the API.
Future<void> _pumpSignup(WidgetTester tester) async {
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
          (ref) async => throw UnimplementedError('network must not be used'),
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

Future<void> _fillForm(
  WidgetTester tester, {
  required String password,
  required String confirmPassword,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Ada Lovelace');
  await tester.enterText(fields.at(1), 'ada@example.com');
  await tester.enterText(fields.at(2), password);
  await tester.enterText(fields.at(3), confirmPassword);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  // The solid button variant renders its label uppercased.
  await tester.tap(find.text('CREATE ACCOUNT'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('signup form has a password confirmation field', (tester) async {
    await _pumpSignup(tester);
    expect(find.text('CONFIRM PASSWORD'),
        findsOneWidget); // AppInput uppercases labels
    // name, email, password, confirm password
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('renders the requirement checklist', (tester) async {
    await _pumpSignup(tester);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(find.text('One uppercase letter'), findsOneWidget);
    expect(find.text('One number'), findsOneWidget);
    expect(find.text('One special character'), findsOneWidget);
  });

  testWidgets('blocks submission when the two passwords differ',
      (tester) async {
    await _pumpSignup(tester);
    await _fillForm(
      tester,
      password: 'Passw0rd!',
      confirmPassword: 'Passw0rd!different',
    );
    await _submit(tester);

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('blocks a password missing an uppercase letter', (tester) async {
    await _pumpSignup(tester);
    await _fillForm(
      tester,
      password: 'passw0rd!',
      confirmPassword: 'passw0rd!',
    );
    await _submit(tester);

    expect(find.text('Password does not meet the requirements below.'),
        findsOneWidget);
  });

  testWidgets('blocks a password missing a number', (tester) async {
    await _pumpSignup(tester);
    await _fillForm(
      tester,
      password: 'Password!',
      confirmPassword: 'Password!',
    );
    await _submit(tester);

    expect(find.text('Password does not meet the requirements below.'),
        findsOneWidget);
  });

  testWidgets('blocks a password missing a special character', (tester) async {
    await _pumpSignup(tester);
    await _fillForm(
      tester,
      password: 'Passw0rdd',
      confirmPassword: 'Passw0rdd',
    );
    await _submit(tester);

    expect(find.text('Password does not meet the requirements below.'),
        findsOneWidget);
  });

  testWidgets('a short password reports length, not the generic policy error',
      (tester) async {
    await _pumpSignup(tester);
    await _fillForm(tester, password: 'Pa0!', confirmPassword: 'Pa0!');
    await _submit(tester);

    expect(
        find.text('Password must be at least 8 characters.'), findsOneWidget);
  });

  testWidgets('requires the confirmation field to be filled in',
      (tester) async {
    await _pumpSignup(tester);
    await _fillForm(tester, password: 'Passw0rd!', confirmPassword: '');
    await _submit(tester);

    expect(find.text('Please confirm your password.'), findsOneWidget);
  });
}
