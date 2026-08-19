import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/repositories/grocery_repository.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/screens/lists/list_detail_controller.dart';
import 'package:mitlist/services/household_prior_service.dart';
import 'package:mitlist/services/list_service.dart';
import 'package:mitlist/services/restock_service.dart';
import 'package:mitlist/services/scan/bundled_grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';

import '../../support/grocery_seed_test_helper.dart';

class _CapturingGrocerySuggestions extends GrocerySuggestionService {
  _CapturingGrocerySuggestions(AppDatabase db)
      : super(db, prior: HouseholdPriorService(db));

  GrocerySuggestionContext? lastContext;
  List<String>? lastContextIds;

  @override
  Future<List<GrocerySuggestion>> suggest(
    String query,
    String groupId, {
    required GrocerySuggestionContext suggestionContext,
    List<String> listContextIds = const [],
    int limit = 8,
  }) async {
    lastContext = suggestionContext;
    lastContextIds = [...listContextIds];
    return const [];
  }
}

class _CapturingRestock extends RestockService {
  _CapturingRestock(AppDatabase db)
      : super(db, prior: HouseholdPriorService(db));

  var calls = 0;
  List<String>? lastContextIds;

  @override
  Future<List<RestockSuggestion>> due({
    required String groupId,
    Set<String> currentItemNames = const {},
    List<String> listContextIds = const [],
    int limit = 8,
  }) async {
    calls++;
    lastContextIds = [...listContextIds];
    return const [];
  }
}

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
    this.cachedListType = 'shopping',
    this.refreshGate,
    this.refreshError,
    this.deleteError,
    this.reorderError,
  });

  final List<ListItem> cachedItems;
  final String? cachedGroupId;
  final String? cachedListType;
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
  Future<String?> getListType(String listId) async => cachedListType;

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

ListItem _item(
  String id,
  int position, {
  bool checked = false,
  String? canonicalItemId,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ListItem(
    id: id,
    listId: 'list-1',
    name: 'Item $id',
    quantity: 1,
    unit: '',
    checked: checked,
    position: position,
    canonicalItemId: canonicalItemId,
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

  testWidgets('shopping suggestions receive distinct unchecked canonical IDs',
      (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    final grocery = _CapturingGrocerySuggestions(db);
    final restock = _CapturingRestock(db);
    final repo = _ControlledListRepository(
      cachedItems: [
        _item('a', 0, canonicalItemId: 'milk'),
        _item('b', 1, checked: true, canonicalItemId: 'eggs'),
        _item('c', 2),
        _item('d', 3, canonicalItemId: 'milk'),
      ],
      cachedGroupId: 'group-1',
      cachedListType: 'shopping',
      refreshError: StateError('offline'),
    );
    ListDetailController? controller;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        grocerySeedProvider.overrideWith((ref) async {}),
        listServiceProviderAsync
            .overrideWith((ref) async => _UnusedListService()),
        listRepositoryProvider.overrideWith((ref) async => repo),
        groceryRepositoryProvider.overrideWith(
          (ref) async => GroceryRepository(db: db, dio: Dio()),
        ),
        grocerySuggestionServiceProvider.overrideWithValue(grocery),
        restockServiceProvider.overrideWithValue(restock),
        bundledGrocerySuggestionServiceProvider.overrideWithValue(
          _FakeBundledSuggestions(),
        ),
      ],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          controller ??= ListDetailController(ref: ref, listId: 'list-1');
          return const SizedBox.shrink();
        }),
      ),
    ));
    addTearDown(() => controller?.dispose());
    await controller!.load();

    await controller!.refreshSuggestions('mi');
    expect(grocery.lastContext, GrocerySuggestionContext.shoppingList);
    expect(grocery.lastContextIds, ['milk']);

    await controller!.refreshSuggestions('');
    expect(restock.calls, 1);
    expect(restock.lastContextIds, ['milk']);
  });

  testWidgets('non-shopping lists use lexical-only mode and skip restock',
      (tester) async {
    final db = memoryDb();
    addTearDown(db.close);
    final grocery = _CapturingGrocerySuggestions(db);
    final restock = _CapturingRestock(db);
    final repo = _ControlledListRepository(
      cachedItems: [_item('a', 0, canonicalItemId: 'milk')],
      cachedGroupId: 'group-1',
      cachedListType: 'todo',
      refreshError: StateError('offline'),
    );
    ListDetailController? controller;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        grocerySeedProvider.overrideWith((ref) async {}),
        listServiceProviderAsync
            .overrideWith((ref) async => _UnusedListService()),
        listRepositoryProvider.overrideWith((ref) async => repo),
        grocerySuggestionServiceProvider.overrideWithValue(grocery),
        restockServiceProvider.overrideWithValue(restock),
        bundledGrocerySuggestionServiceProvider.overrideWithValue(
          _FakeBundledSuggestions(),
        ),
      ],
      child: MaterialApp(
        home: Consumer(builder: (context, ref, _) {
          controller ??= ListDetailController(ref: ref, listId: 'list-1');
          return const SizedBox.shrink();
        }),
      ),
    ));
    addTearDown(() => controller?.dispose());
    await controller!.load();

    await controller!.refreshSuggestions('mi');
    expect(grocery.lastContext, GrocerySuggestionContext.nonShoppingList);
    await controller!.refreshSuggestions('');
    expect(restock.calls, 0);
  });
}
