import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/screens/auth/welcome_screen.dart';

Widget _buildApp({required Locale locale}) {
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

  return ProviderScope(
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  group('WelcomeScreen localization', () {
    testWidgets('renders English tagline', (tester) async {
      await tester.pumpWidget(_buildApp(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Your household, organized.'), findsOneWidget);
      // Ghost button is not uppercased
      expect(find.text('Continue as guest'), findsOneWidget);
    });

    testWidgets('renders German tagline and guest button', (tester) async {
      await tester.pumpWidget(_buildApp(locale: const Locale('de')));
      await tester.pumpAndSettle();

      expect(find.text('Dein Haushalt, organisiert.'), findsOneWidget);
      expect(find.text('Als Gast fortfahren'), findsOneWidget);
    });
  });
}
