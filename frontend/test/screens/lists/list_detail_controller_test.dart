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
  /// Called from `dispose` whenever the session added (or restored) an item.
  @override
  Future<void> flushListNotifications(String listId) async {}

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
  int createCalls = 0;
  final List<UpdateListItemRequest> updates = [];
  final List<String> amountAdds = [];

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
  Future<ListItem> createItemOfflineFirst(
    String listId,
    CreateListItemRequest req, {
    bool deferImmediateSync = false,
  }) async {
    createCalls++;
    return ListItem(
      id: 'created-$createCalls',
      listId: listId,
      name: req.name,
      quantity: 1,
      unit: '',
      checked: false,
      position: cachedItems.length,
      canonicalItemId: req.canonicalItemId,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<ListItem> addItemAmountOfflineFirst(
    String listId, {
    required String name,
    required double amount,
    String unit = '',
    String note = '',
    String? canonicalItemId,
    bool deferImmediateSync = false,
  }) async {
    amountAdds.add(name);
    return ListItem(
      id: 'amount-${amountAdds.length}',
      listId: listId,
      name: name,
      quantity: amount,
      unit: unit,
      checked: false,
      position: cachedItems.length,
      canonicalItemId: canonicalItemId,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    updates.add(req);
    final existing = cachedItems.firstWhere((item) => item.id == itemId);
    return ListItem(
      id: existing.id,
      listId: existing.listId,
      name: existing.name,
      quantity: existing.quantity,
      unit: existing.unit,
      checked: req.checked ?? existing.checked,
      position: req.position ?? existing.position,
      canonicalItemId: existing.canonicalItemId,
      createdAt: existing.createdAt,
      updatedAt: DateTime.utc(2026, 1, 2),
    );
  }

  @override
  void triggerAutoSync() {}

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
  String? name,
  String unit = '',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ListItem(
    id: id,
    listId: 'list-1',
    name: name ?? 'Item $id',
    quantity: 1,
    unit: unit,
    checked: checked,
    position: position,
    canonicalItemId: canonicalItemId,
    createdAt: now,
    updatedAt: now,
  );
}

/// Builds a loaded controller over [repo] with every async suggestion source
/// stubbed out, so the assertions below see only what the controller itself
/// contributes.
Future<ListDetailController> _loadedController(
  WidgetTester tester,
  _ControlledListRepository repo, {
  BundledGrocerySuggestionService? bundled,
}) async {
  ListDetailController? controller;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      grocerySeedProvider.overrideWith((ref) async {}),
      listServiceProviderAsync
          .overrideWith((ref) async => _UnusedListService()),
      listRepositoryProvider.overrideWith((ref) async => repo),
      if (bundled != null)
        bundledGrocerySuggestionServiceProvider.overrideWithValue(bundled),
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
  return controller!;
}

class _NoBundledSuggestions extends BundledGrocerySuggestionService {
  @override
  Future<List<GrocerySuggestion>> suggest(String query,
          {int limit = 8}) async =>
      const [];
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

  testWidgets('re-adding a checked-off name unchecks it instead of duplicating',
      (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [
        _item('a', 0, name: 'Milk', checked: true),
        _item('b', 1, name: 'Bread'),
      ],
      // No group id on purpose: it would start the canonical backfill, which
      // wants the real grocery database and embedding isolate. None of the
      // behaviour below depends on it.
      refreshError: StateError('offline'),
    );
    final controller = await _loadedController(tester, repo);

    // Typed with different casing on purpose — the match is on the normalised
    // name, the way a user retypes a thing they bought last week.
    expect(await controller.addItem('milk'), AddItemOutcome.restored);

    expect(repo.createCalls, 0);
    expect(repo.updates, hasLength(1));
    expect(repo.updates.single.checked, isFalse);
    // Parked below the last row, where a fresh add would have landed.
    expect(repo.updates.single.position, 2);
  });

  testWidgets('re-adding a name that is still open leaves the list alone',
      (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [_item('a', 0, name: 'Milk')],
      refreshError: StateError('offline'),
    );
    final controller = await _loadedController(tester, repo);

    expect(await controller.addItem('Milk'), AddItemOutcome.alreadyOnList);

    expect(repo.createCalls, 0);
    expect(repo.updates, isEmpty);
  });

  testWidgets('an open row wins over a checked one with the same name',
      (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [
        _item('a', 0, name: 'Milk', checked: true),
        _item('b', 1, name: 'Milk'),
      ],
      refreshError: StateError('offline'),
    );
    final controller = await _loadedController(tester, repo);

    expect(await controller.addItem('milk'), AddItemOutcome.alreadyOnList);
    expect(repo.updates, isEmpty);
  });

  testWidgets('a bare add still matches a row that carries a unit',
      (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [_item('a', 0, name: 'Milk', unit: 'l', checked: true)],
      refreshError: StateError('offline'),
    );
    final controller = await _loadedController(tester, repo);

    expect(await controller.addItem('milk'), AddItemOutcome.restored);
    expect(repo.updates.single.checked, isFalse);
  });

  testWidgets('a quantity add tops up the existing row under its own spelling',
      (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [_item('a', 0, name: 'Milk', unit: 'l')],
      // No group id, so the write skips canonical enrichment — that path wants
      // a seeded grocery database this harness deliberately does not stand up.
      refreshError: StateError('offline'),
    );
    final controller = await _loadedController(tester, repo);

    expect(await controller.addItem('2 l MILK'), AddItemOutcome.increased);
    expect(repo.createCalls, 0);
    expect(repo.amountAdds, ['Milk']);
  });

  testWidgets('a new name is still created', (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [_item('a', 0, name: 'Milk', checked: true)],
      refreshError: StateError('offline'),
    );
    final controller = await _loadedController(tester, repo);

    expect(await controller.addItem('Bread'), AddItemOutcome.created);
    expect(repo.createCalls, 1);
    expect(repo.updates, isEmpty);
  });

  testWidgets('the composer offers checked-off rows first', (tester) async {
    final repo = _ControlledListRepository(
      cachedItems: [
        _item('a', 0, name: 'Almond milk'),
        _item('b', 1, name: 'Milk', checked: true),
      ],
      refreshError: StateError('offline'),
    );
    final controller = await _loadedController(
      tester,
      repo,
      bundled: _NoBundledSuggestions(),
    );

    await controller.refreshSuggestions('mil');
    final suggestions = controller.suggestions;
    expect(suggestions.map((s) => s.name), ['Milk', 'Almond milk']);
    expect(suggestions.every((s) => s.isOnList), isTrue);
    expect(suggestions.first.onListChecked, isTrue);
    expect(suggestions.last.onListChecked, isFalse);

    // An empty composer has nothing to re-add — those cards belong to restock.
    await controller.refreshSuggestions('');
    expect(controller.suggestions, isEmpty);
  });
}
