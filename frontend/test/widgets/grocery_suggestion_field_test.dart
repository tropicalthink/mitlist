import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show grocerySeedProvider;
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/widgets/grocery_suggestion_field.dart';

import '../support/grocery_seed_test_helper.dart';

class _CapturingSuggestions extends GrocerySuggestionService {
  _CapturingSuggestions(AppDatabase db)
      : super(db, prior: HouseholdPriorService(db));

  GrocerySuggestionContext? context;

  @override
  Future<List<GrocerySuggestion>> suggest(
    String query,
    String groupId, {
    required GrocerySuggestionContext suggestionContext,
    List<String> listContextIds = const [],
    int limit = 8,
  }) {
    context = suggestionContext;
    return super.suggest(
      query,
      groupId,
      suggestionContext: suggestionContext,
      listContextIds: listContextIds,
      limit: limit,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('waits for grocery data and returns the selected default unit',
      (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    final now = DateTime.utc(2026, 1, 1);
    await db.upsertCanonicalItems([
      CanonicalItemsTableCompanion.insert(
        id: 'milk',
        groupId: '__global__',
        nameEn: const drift.Value('Milk'),
        defaultUnit: const drift.Value('l'),
        isGlobal: const drift.Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await db.upsertItemAliases([
      ItemAliasesTableCompanion.insert(
        id: 'milk-alias',
        groupId: '__global__',
        canonicalItemId: 'milk',
        aliasText: 'milk',
        source: const drift.Value('seed'),
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    GrocerySuggestion? selected;
    final suggestions = _CapturingSuggestions(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grocerySeedProvider.overrideWith((ref) async {}),
          grocerySuggestionServiceProvider.overrideWithValue(
            suggestions,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: GrocerySuggestionField(
                controller: controller,
                groupId: 'group-1',
                suggestionContext: GrocerySuggestionContext.shoppingList,
                onSelected: (suggestion) => selected = suggestion,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'mil');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Milk'));
    await tester.pump();

    expect(controller.text, 'Milk');
    expect(selected?.canonicalItemId, 'milk');
    expect(selected?.unit, 'l');
    expect(suggestions.context, GrocerySuggestionContext.shoppingList);
  });
}
