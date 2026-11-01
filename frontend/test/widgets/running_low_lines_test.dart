import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/services/restock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mitlist/widgets/list/running_low_lines.dart';

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

/// Pumps [RunningLowLines] inside a localized [MaterialApp] backed by a
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
          body: RunningLowLines(
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RunningLowLines', () {
    // 1. Renders suggestions
    testWidgets('shows a line for each suggestion', (tester) async {
      await _pumpStrip(tester, suggestions: [_milk, _eggs]);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
      // Each line says why: the reason, then when it was last bought.
      expect(find.text('Due again · 9d ago'), findsOneWidget);
      expect(find.text('Goes with this list · 6d ago'), findsOneWidget);
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
    testWidgets('tapping a line calls onAdd with matching suggestion',
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

    testWidgets('a swiped-away line stays away, even on the next visit',
        (tester) async {
      await _pumpStrip(tester, suggestions: [_milk, _eggs]);

      await tester.drag(find.text('Milk'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);

      // Leave and come back: the swipe was remembered for the household.
      await tester.pumpWidget(const SizedBox());
      await _pumpStrip(tester, suggestions: [_milk, _eggs]);
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Eggs'), findsOneWidget);
    });

    testWidgets('shows at most three', (tester) async {
      await _pumpStrip(tester, suggestions: [
        for (var i = 0; i < 5; i++)
          RestockSuggestion(
            canonicalItemId: 'x$i',
            name: 'Thing $i',
            intervalDays: 7,
            daysSince: 8,
            reason: RestockReason.usual,
          ),
      ]);
      expect(find.textContaining('Thing '), findsNWidgets(3));
    });
  });
}
