import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/widgets/pinwall_link_chip.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [PinwallLinkChip] inside a localized [MaterialApp].
Future<void> _pumpChip(
  WidgetTester tester, {
  required String entityType,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PinwallLinkChip(
          entityType: entityType,
          color: Colors.grey,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PinwallLinkChip', () {
    // 1. Chore type renders correct label
    testWidgets('renders "Linked chore" for entityType chore', (tester) async {
      await _pumpChip(tester, entityType: 'chore');
      expect(find.text('Linked chore'), findsOneWidget);
    });

    // 2. List type renders correct label
    testWidgets('renders "Linked list" for entityType list', (tester) async {
      await _pumpChip(tester, entityType: 'list');
      expect(find.text('Linked list'), findsOneWidget);
    });

    // 3. Expense type renders correct label
    testWidgets('renders "Linked expense" for entityType expense',
        (tester) async {
      await _pumpChip(tester, entityType: 'expense');
      expect(find.text('Linked expense'), findsOneWidget);
    });

    // 4. Tapping the chip calls onTap exactly once
    testWidgets('tapping the chip calls onTap exactly once', (tester) async {
      int tapCount = 0;
      await _pumpChip(
        tester,
        entityType: 'chore',
        onTap: () => tapCount++,
      );

      await tester.tap(find.text('Linked chore'));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    // 5. Unknown entity type renders nothing (SizedBox.shrink)
    testWidgets('renders nothing for unknown entityType', (tester) async {
      await _pumpChip(tester, entityType: 'bogus');

      // No label text should appear
      expect(find.text('Linked chore'), findsNothing);
      expect(find.text('Linked list'), findsNothing);
      expect(find.text('Linked expense'), findsNothing);
      // The icon should not appear either
      expect(find.byIcon(Icons.link), findsNothing);
    });
  });
}
