import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/screens/lists/list_detail_controller.dart';
import 'package:mitlist/services/scan/bundled_grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';

class _FakeBundledSuggestions extends BundledGrocerySuggestionService {
  @override
  Future<List<GrocerySuggestion>> suggest(
    String query, {
    int limit = 8,
  }) async {
    return const [
      GrocerySuggestion(
        canonicalItemId: 'milk',
        name: 'Milk',
        category: 'dairy',
        unit: 'l',
      ),
    ];
  }
}

class _ControlledBundledSuggestions extends BundledGrocerySuggestionService {
  final Completer<List<GrocerySuggestion>> completer = Completer();

  @override
  Future<List<GrocerySuggestion>> suggest(
    String query, {
    int limit = 8,
  }) =>
      completer.future;
}

void main() {
  testWidgets('bundled suggestions do not require resolved group metadata',
      (tester) async {
    ListDetailController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bundledGrocerySuggestionServiceProvider.overrideWithValue(
            _FakeBundledSuggestions(),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              controller ??= ListDetailController(
                ref: ref,
                listId: 'list-1',
                initialListName: 'Groceries',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    addTearDown(() => controller?.dispose());

    expect(controller!.groupId, isNull);

    await controller!.refreshSuggestions('mil');

    expect(controller!.suggestions, hasLength(1));
    expect(controller!.suggestions.single.canonicalItemId, 'milk');
  });

  testWidgets('text changes invalidate an older query before debounce fires',
      (tester) async {
    final service = _ControlledBundledSuggestions();
    ListDetailController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bundledGrocerySuggestionServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              controller ??= ListDetailController(
                ref: ref,
                listId: 'list-1',
                initialListName: 'Groceries',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    final oldQuery = controller!.refreshSuggestions('mi');
    controller!.refreshSuggestionsDebounced('mil');
    service.completer.complete(const [
      GrocerySuggestion(
        canonicalItemId: 'stale',
        name: 'Stale result',
        category: '',
        unit: '',
      ),
    ]);
    await oldQuery;

    final suggestions = controller!.suggestions;
    controller!.dispose();
    controller = null;
    expect(suggestions, isEmpty);
  });
}
