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
      // Solid and outline buttons are uppercased.
      expect(find.text('GET STARTED'), findsOneWidget);
      expect(find.text('I HAVE AN ACCOUNT'), findsOneWidget);
      // The guest door lives at the end of the tour now, not here.
      expect(find.text('Continue as guest'), findsNothing);
    });

    testWidgets('renders German tagline and buttons', (tester) async {
      await tester.pumpWidget(_buildApp(locale: const Locale('de')));
      await tester.pumpAndSettle();

      expect(find.text('Dein Haushalt, organisiert.'), findsOneWidget);
      expect(find.text('LOSLEGEN'), findsOneWidget);
      expect(find.text('ICH HABE EIN KONTO'), findsOneWidget);
    });
  });
}
