import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/widgets/app_button.dart';
import 'package:mitlist/widgets/app_dialog.dart';

// The app's tabs live in StatefulShellRoute branches, each with its own
// Navigator, while showAppDialog pushes onto the root navigator. A dialog
// action that pops via the screen's context pops the branch's last page
// instead of the dialog (a go_router assertion in debug, a null check in
// release) and the caller never sees a result. Actions must pop the root.
void main() {
  testWidgets('dialog actions return a result from a shell branch screen',
      (tester) async {
    bool? confirmed;
    final router = GoRouter(routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(builder: (context) {
                  return TextButton(
                    onPressed: () async {
                      confirmed = await showAppDialog<bool>(
                        context: context,
                        title: 'Delete?',
                        body: const Text('Sure?'),
                        actions: [
                          AppButton(
                            text: 'Delete',
                            onPressed: () =>
                                Navigator.of(context, rootNavigator: true)
                                    .pop(true),
                          ),
                        ],
                      );
                    },
                    child: const Text('open'),
                  );
                }),
              ),
            ),
          ]),
        ],
      ),
    ]);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sure?'), findsOneWidget);

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(confirmed, isTrue);
    expect(find.text('Sure?'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
