import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/services/restock_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/household_suggestion_engine.dart';

const _milk = GrocerySuggestion(
  canonicalItemId: 'milk',
  name: 'Milk',
  category: 'dairy',
  unit: 'l',
);

void main() {
  test('merges catalog and bundled results by canonical identity', () {
    final engine = HouseholdSuggestionEngine()..beginQuery('mil');

    engine.setGrocerySuggestions(
      HouseholdSuggestionSource.bundled,
      const [_milk],
    );
    engine.setGrocerySuggestions(
      HouseholdSuggestionSource.catalog,
      const [_milk],
    );

    expect(engine.suggestions, hasLength(1));
    expect(engine.suggestions.single.sources, {
      HouseholdSuggestionSource.catalog,
      HouseholdSuggestionSource.bundled,
    });
  });

  test('merges legacy product result into canonical candidate by name', () {
    final engine = HouseholdSuggestionEngine()..beginQuery('mil');
    engine.setGrocerySuggestions(
      HouseholdSuggestionSource.catalog,
      const [_milk],
    );
    engine.setProducts([
      Product(
        id: 'product-1',
        groupId: 'group-1',
        name: 'Milk',
        unit: 'l',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);

    expect(engine.suggestions, hasLength(1));
    expect(engine.suggestions.single.canonicalItemId, 'milk');
    expect(
      engine.suggestions.single.sources,
      contains(HouseholdSuggestionSource.product),
    );
  });

  test('ranks due restock candidates first for an empty composer', () {
    final engine = HouseholdSuggestionEngine()..beginQuery('');
    engine.setGrocerySuggestions(
      HouseholdSuggestionSource.bundled,
      const [_milk],
    );
    engine.setRestockSuggestions(const [
      RestockSuggestion(
        canonicalItemId: 'eggs',
        name: 'Eggs',
        intervalDays: 7,
        daysSince: 9,
      ),
    ]);

    expect(engine.suggestions.first.canonicalItemId, 'eggs');
    expect(engine.suggestions.first.sources,
        contains(HouseholdSuggestionSource.restock));
  });
}
