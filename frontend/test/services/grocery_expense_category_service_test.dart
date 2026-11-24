import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/grocery_expense_category_service.dart';

void main() {
  group('GroceryExpenseCategoryService', () {
    test('recognises known grocery merchants without invoking the resolver',
        () async {
      var resolverCalls = 0;
      final service = GroceryExpenseCategoryService.withResolver(
        (text, groupId) async {
          resolverCalls++;
          return null;
        },
      );

      expect(
        await service.suggest('Weekly shop at REWE', 'group-1'),
        'groceries',
      );
      expect(resolverCalls, 0);
    });

    test('uses a high-confidence grocery match', () async {
      final service = GroceryExpenseCategoryService.withResolver(
        (text, groupId) async =>
            text.toLowerCase() == 'milk' ? 'canonical-milk' : null,
      );

      expect(await service.suggest('milk', 'group-1'), 'groceries');
    });

    test('checks bounded receipt-like description fragments', () async {
      final seen = <String>[];
      final service = GroceryExpenseCategoryService.withResolver(
        (text, groupId) async {
          seen.add(text);
          return text.toLowerCase() == 'bread' ? 'canonical-bread' : null;
        },
      );

      expect(
        await service.suggest('Saturday errands; bread', 'group-1'),
        'groceries',
      );
      expect(seen, contains('bread'));
    });

    test('leaves unrelated expenses uncategorised', () async {
      final service = GroceryExpenseCategoryService.withResolver(
        (text, groupId) async => null,
      );

      expect(await service.suggest('Train ticket', 'group-1'), isNull);
      expect(await service.suggest(' ', 'group-1'), isNull);
    });

    test('food words in a bill or a night out are not groceries', () async {
      // The resolver would call every one of these a grocery item.
      final service = GroceryExpenseCategoryService.withResolver(
        (text, groupId) async => 'canonical-anything',
      );

      for (final description in [
        'Water bill',
        'Coffee at the café',
        'Beers at the bar',
        'Pizza takeaway',
        'Wasserrechnung',
        'Abendessen Pizza',
      ]) {
        expect(await service.suggest(description, 'group-1'), isNull,
            reason: description);
      }
    });

    test('a grocery delivery is still groceries', () async {
      final service = GroceryExpenseCategoryService.withResolver(
        (text, groupId) async => text == 'Milk delivery' ? 'milk' : null,
      );
      expect(await service.suggest('Milk delivery', 'group-1'), 'groceries');
    });

    test('chain names that are ordinary words only count alone', () async {
      final service = GroceryExpenseCategoryService.withResolver(
        (text, groupId) async => null,
      );

      expect(await service.suggest('Penny', 'group-1'), 'groceries');
      expect(await service.suggest('Netto Markt', 'group-1'), 'groceries');
      expect(await service.suggest('Penny stocks', 'group-1'), isNull);
      expect(await service.suggest('Netto Gehalt Juni', 'group-1'), isNull);
    });
  });
}
