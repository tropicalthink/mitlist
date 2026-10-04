import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/providers/outbox_provider.dart';
import 'package:mitlist/router.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/widgets/offline_banner.dart';

/// The banner is mounted above the Navigator, exactly as in `app.dart`, so a
/// modal barrier never covers it and the guard in the banner itself is the
/// only thing keeping repeated taps from stacking sheets.
Widget _harness({required OutboxState state}) {
  return ProviderScope(
    overrides: [
      outboxStateProvider.overrideWith((ref) => Stream.value(state)),
      pendingOutboxOpsProvider
          .overrideWith((ref) => Stream.value(const <OutboxOp>[])),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child!),
        ],
      ),
      home: const Scaffold(body: SizedBox.expand()),
    ),
  );
}

void main() {
  testWidgets('repeated taps on the syncing banner open a single sheet',
      (tester) async {
    await tester.pumpWidget(_harness(
      state: const OutboxState(status: OutboxStatus.syncing, pendingCount: 2),
    ));
    await tester.pump();

    final banner = find.byType(OfflineBanner);
    expect(banner, findsOneWidget);

    // Three quick taps, as a user drumming on the bar while a sheet animates
    // in. None of them is covered by the sheet's barrier.
    await tester.tap(banner, warnIfMissed: false);
    await tester.pump();
    await tester.tap(banner, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(banner, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Sync Status'), findsOneWidget);
    expect(find.text('Waiting to sync'), findsOneWidget);

    // Release the guard for the next test: it is app-wide state, and an open
    // sheet at the end of a test would otherwise carry over.
    rootNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Sync Status'), findsNothing);
  });

  testWidgets('the banner opens the sheet again once it has been dismissed',
      (tester) async {
    await tester.pumpWidget(_harness(
      state: const OutboxState(status: OutboxStatus.syncing, pendingCount: 1),
    ));
    await tester.pump();

    await tester.tap(find.byType(OfflineBanner), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Sync Status'), findsOneWidget);

    rootNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Sync Status'), findsNothing);

    await tester.tap(find.byType(OfflineBanner), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Sync Status'), findsOneWidget);
  });
}
