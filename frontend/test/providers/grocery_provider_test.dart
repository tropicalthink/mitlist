import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show appDatabaseProvider;

import '../support/grocery_seed_test_helper.dart';

void main() {
  test('autocomplete and restock share the same household prior instance', () {
    final db = memoryDb();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final prior = container.read(householdPriorServiceProvider);
    final autocomplete = container.read(grocerySuggestionServiceProvider);
    final restock = container.read(restockServiceProvider);

    expect(identical(autocomplete.priorService, prior), isTrue);
    expect(identical(restock.priorService, prior), isTrue);
  });
}
