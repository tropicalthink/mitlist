import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/sheets/chore_detail_sheet.dart';

void main() {
  Widget host({String? zone}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChoreDetailSheet(
            choreId: 'c1',
            title: 'Wipe counters',
            statusLabel: 'Due today',
            assignee: 'Sam',
            frequencyLabel: 'Weekly',
            zone: zone,
            dueDate: DateTime(2026, 9, 22),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the zone the chore is filed under', (tester) async {
    await tester.pumpWidget(host(zone: 'Kitchen'));
    await tester.pumpAndSettle();

    expect(find.text('Zone'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
  });

  testWidgets('omits the zone row for an unfiled chore', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Zone'), findsNothing);
  });

  testWidgets('omits the zone row for an empty zone', (tester) async {
    await tester.pumpWidget(host(zone: ''));
    await tester.pumpAndSettle();

    expect(find.text('Zone'), findsNothing);
  });
}
