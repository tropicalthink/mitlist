import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/services/restock_service.dart';
import 'package:mitlist/widgets/list/running_low_strip.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Two pre-built suggestions used across several tests.
const _milk = RestockSuggestion(
  canonicalItemId: 'c1',
  name: 'Milk',
  intervalDays: 7,
  daysSince: 9,
  reason: RestockReason.due,
);
const _eggs = RestockSuggestion(
  canonicalItemId: 'c2',
  name: 'Eggs',
  intervalDays: 5,
  daysSince: 6,
  reason: RestockReason.goesWith,
);

/// Pumps [RunningLowStrip] inside a localized [MaterialApp] backed by a
/// [ProviderScope] that overrides [runningLowProvider] with [suggestions].
Future<void> _pumpStrip(
  WidgetTester tester, {
  required List<RestockSuggestion> suggestions,
  Set<String> currentItemNames = const {},
  void Function(RestockSuggestion)? onAdd,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runningLowProvider('g1').overrideWith(
          (ref) async => suggestions,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RunningLowStrip(
            groupId: 'g1',
            currentItemNames: currentItemNames,
            onAdd: onAdd ?? (_) {},
          ),
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
  group('RunningLowStrip', () {
    // 1. Renders suggestions
    testWidgets('shows a card for each suggestion', (tester) async {
      await _pumpStrip(tester, suggestions: [_milk, _eggs]);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('Due again'), findsOneWidget);
      expect(find.text('Goes with this list'), findsOneWidget);
      expect(find.text('You might also need'), findsOneWidget);
    });

    // 2. Excludes current items
    testWidgets('excludes items whose name is in currentItemNames',
        (tester) async {
      await _pumpStrip(
        tester,
        suggestions: [_milk, _eggs],
        currentItemNames: {'milk'}, // lowercased match
      );

      expect(find.text('Milk'), findsNothing);
      expect(find.text('Eggs'), findsOneWidget);
    });

    // 3. Empty → invisible (no heading or card text)
    testWidgets('renders nothing when suggestions list is empty',
        (tester) async {
      await _pumpStrip(tester, suggestions: []);

      // No heading and no card names should appear.
      expect(find.text('Running low'), findsNothing);
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Eggs'), findsNothing);
    });

    // 4. Tap calls onAdd with the correct suggestion
    testWidgets('tapping a card calls onAdd with matching suggestion',
        (tester) async {
      RestockSuggestion? added;

      await _pumpStrip(
        tester,
        suggestions: [_milk, _eggs],
        onAdd: (s) => added = s,
      );

      await tester.tap(find.text('Eggs'));
      await tester.pumpAndSettle();

      expect(added, isNotNull);
      expect(added!.canonicalItemId, 'c2');
    });
  });
}
