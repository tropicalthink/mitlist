import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/screens/lists/list_detail_controller.dart';
import 'package:mitlist/services/list_service.dart';
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

class _UnusedListService implements ListService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not implemented on _UnusedListService',
      );
}

class _ControlledListRepository implements ListRepository {
  _ControlledListRepository({
    this.cachedItems = const [],
    this.cachedGroupId,
    this.refreshGate,
    this.refreshError,
    this.deleteError,
    this.reorderError,
  });

  final List<ListItem> cachedItems;
  final String? cachedGroupId;
  final Completer<void>? refreshGate;
  final Error? refreshError;
  final Error? deleteError;
  final Error? reorderError;
  int refreshCalls = 0;

  @override
  Stream<List<ListItem>> watchItemsByList(String listId) =>
      Stream.value(cachedItems);

  @override
  Future<List<ListItem>> getItemsByListOnce(String listId) async => cachedItems;

  @override
  Future<String?> getGroupId(String listId) async => cachedGroupId;

  @override
  Future<void> refreshListDetail(String listId) async {
    refreshCalls++;
    await refreshGate?.future;
    if (refreshError case final error?) throw error;
  }

  @override
  Future<void> deleteItemOfflineFirst(String listId, String itemId) async {
    if (deleteError case final error?) throw error;
  }

  @override
  Future<void> reorderItemsOfflineFirst(
    String listId,
    List<String> itemIdsInOrder,
  ) async {
    if (reorderError case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not implemented on _ControlledListRepository',
      );
}

ListItem _item(String id, int position) {
  final now = DateTime.utc(2026, 1, 1);
  return ListItem(
    id: id,
    listId: 'list-1',
    name: 'Item $id',
    quantity: 1,
    unit: '',
    checked: false,
    position: position,
    createdAt: now,
    updatedAt: now,
  );
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

  testWidgets('cached content survives a failed refresh', (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [_item('a', 0)],
      cachedGroupId: 'group-1',
      refreshError: StateError('offline'),
    );
    ListDetailController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grocerySeedProvider.overrideWith((ref) async {}),
          listServiceProviderAsync
              .overrideWith((ref) async => _UnusedListService()),
          listRepositoryProvider.overrideWith((ref) async => repo),
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

    await controller!.load();

    expect(controller!.hasError, isFalse);
    expect(controller!.items, hasLength(1));
    expect(controller!.consumeRefreshFailure(), isTrue);
    expect(controller!.consumeRefreshFailure(), isFalse);
  });

  testWidgets('concurrent refresh requests share one load', (tester) async {
    final gate = Completer<void>();
    final repo = _ControlledListRepository(
      refreshGate: gate,
      refreshError: StateError('offline'),
    );
    ListDetailController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grocerySeedProvider.overrideWith((ref) async {}),
          listServiceProviderAsync
              .overrideWith((ref) async => _UnusedListService()),
          listRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              controller ??= ListDetailController(
                ref: ref,
                listId: 'list-1',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    addTearDown(() => controller?.dispose());

    final first = controller!.load();
    final second = controller!.load();
    await tester.pump();
    expect(repo.refreshCalls, 1);

    gate.complete();
    await Future.wait([first, second]);
    expect(repo.refreshCalls, 1);
  });

  testWidgets('failed optimistic delete restores the item', (tester) async {
    final item = _item('a', 0);
    final repo = _ControlledListRepository(
      cachedItems: [item],
      cachedGroupId: 'group-1',
      refreshError: StateError('offline'),
      deleteError: StateError('database write failed'),
    );
    ListDetailController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grocerySeedProvider.overrideWith((ref) async {}),
          listServiceProviderAsync
              .overrideWith((ref) async => _UnusedListService()),
          listRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              controller ??= ListDetailController(
                ref: ref,
                listId: 'list-1',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    addTearDown(() => controller?.dispose());
    await controller!.load();

    await expectLater(controller!.deleteItem(item), throwsStateError);

    expect(controller!.items.map((value) => value.id), ['a']);
    expect(controller!.dirty, isFalse);
  });

  testWidgets('failed optimistic reorder restores positions', (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [_item('a', 0), _item('b', 1)],
      cachedGroupId: 'group-1',
      refreshError: StateError('offline'),
      reorderError: StateError('database write failed'),
    );
    ListDetailController? controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grocerySeedProvider.overrideWith((ref) async {}),
          listServiceProviderAsync
              .overrideWith((ref) async => _UnusedListService()),
          listRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              controller ??= ListDetailController(
                ref: ref,
                listId: 'list-1',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    addTearDown(() => controller?.dispose());
    await controller!.load();

    await expectLater(controller!.reorderOpen(0, 2), throwsStateError);

    expect(controller!.openItemsSorted.map((value) => value.id), ['a', 'b']);
    expect(controller!.dirty, isFalse);
  });
}
