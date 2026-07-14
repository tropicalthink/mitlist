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
  });
}
