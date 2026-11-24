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
import 'package:mitlist/services/scan/canonical_link_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import '../../support/fakes.dart';
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
    Set<String> currentCanonicalIds = const {},
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
    String? addedBy,
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
    String? addedBy,
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

class _NoLinks implements CanonicalLinkService {
  @override
  Future<String?> resolveHighConfidence(
    String itemName,
    String groupId, {
    List<String> listContext = const [],
    Object? context,
  }) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not implemented on _NoLinks',
      );
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

  group('undo / redo', () {
    // (The resolver is stubbed: the real one waits on the grocery reference
    // database, which fake async never lets finish.)
    late AppDatabase db;
    late FakeListService remote;
    late ListRepository repo;
    const listId = 'list-1';

    ListItemsTableCompanion row(
      String id, {
      String? name,
      bool checked = false,
      int position = 0,
      double quantity = 1,
      String? canonicalItemId,
    }) =>
        ListItemsTableCompanion(
          id: drift.Value(id),
          listId: const drift.Value(listId),
          name: drift.Value(name ?? 'Item $id'),
          quantity: drift.Value(quantity),
          unit: const drift.Value(''),
          checked: drift.Value(checked),
          position: drift.Value(position),
          canonicalItemId: drift.Value(canonicalItemId),
          createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
          updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
        );

    Future<ListDetailController> open(
      WidgetTester tester,
      List<ListItemsTableCompanion> rows,
    ) async {
      db = AppDatabase(drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ));
      addTearDown(db.close);
      remote = FakeListService();
      repo = ListRepository(db: db, remote: remote, autoSync: false);
      addTearDown(repo.dispose);
      await db.upsertListsRows([
        ListsTableCompanion(
          id: const drift.Value(listId),
          groupId: const drift.Value('group-1'),
          name: const drift.Value('Groceries'),
          type: const drift.Value('todo'),
          createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
          updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
        ),
      ]);
      await db.upsertListItemsRows(rows);
      ListDetailController? controller;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          grocerySeedProvider.overrideWith((ref) async {}),
          listServiceProviderAsync
              .overrideWith((ref) async => _UnusedListService()),
          listRepositoryProvider.overrideWith((ref) async => repo),
          bundledGrocerySuggestionServiceProvider
              .overrideWithValue(_NoBundledSuggestions()),
          canonicalLinkServiceProvider.overrideWithValue(_NoLinks()),
        ],
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            controller ??= ListDetailController(ref: ref, listId: listId);
            return const SizedBox.shrink();
          }),
        ),
      ));
      addTearDown(() => controller?.dispose());
      await controller!.load();
      return controller!;
    }

    Future<Map<String, ListItem>> rows() async => {
          for (final item in await repo.getItemsByListOnce(listId))
            item.id: item,
        };

    Future<List<String>> queued() async =>
        [for (final op in await db.getOutboxBatch()) op.type];

    testWidgets('a field edit undoes and redoes, canonical link included',
        (tester) async {
      final c = await open(tester, [
        row('a', name: 'Milk', canonicalItemId: 'milk', quantity: 1),
      ]);
      final milk = (await rows())['a']!;

      await c.updateItemFields(milk, name: 'Oat milk', quantity: 2);
      expect(c.undoStack.canUndo, isTrue);
      expect((await rows())['a']!.canonicalItemId, isNull,
          reason: 'a rename drops the link');

      expect((await c.undo()).outcome, ListUndoOutcome.applied);
      var a = (await rows())['a']!;
      expect(a.name, 'Milk');
      expect(a.quantity, 1);
      expect(a.canonicalItemId, 'milk', reason: 'undoing the rename relinks');
      expect(c.undoStack.canUndo, isFalse);
      expect(c.undoStack.canRedo, isTrue);

      expect((await c.redo()).outcome, ListUndoOutcome.applied);
      a = (await rows())['a']!;
      expect(a.name, 'Oat milk');
      expect(a.quantity, 2);
      expect(a.canonicalItemId, isNull);
      expect(c.undoStack.canUndo, isTrue);
    });

    testWidgets('a tick undoes and redoes', (tester) async {
      final c = await open(tester, [row('a')]);
      final a = (await rows())['a']!;

      await c.toggleItem(a, true, disableAnimations: true);
      expect((await rows())['a']!.checked, isTrue);

      await c.undo();
      expect((await rows())['a']!.checked, isFalse);
      await c.redo();
      expect((await rows())['a']!.checked, isTrue);
    });

    testWidgets('check all is one step', (tester) async {
      final c = await open(tester, [
        row('a'),
        row('b', position: 1, checked: true),
        row('c', position: 2),
      ]);

      await c.completeAll();
      expect(c.undoStack.undoDepth, 1);
      await c.undo();
      final after = await rows();
      expect(after['a']!.checked, isFalse);
      expect(after['b']!.checked, isTrue,
          reason: 'only the rows check all ticked are unticked');
      expect(after['c']!.checked, isFalse);

      await c.redo();
      expect((await rows()).values.every((i) => i.checked), isTrue);
    });

    testWidgets('an add undoes and redoes under the same id', (tester) async {
      final c = await open(tester, [row('a')]);

      await c.addItem('Eggs');
      final added = (await rows()).values.singleWhere((i) => i.name == 'Eggs');

      await c.undo();
      expect((await rows()).containsKey(added.id), isFalse);
      await c.redo();
      final back = (await rows())[added.id];
      expect(back, isNotNull);
      expect(back!.position, added.position);
      expect(await queued(), ['createItem'],
          reason: 'the queued create and delete cancel out');
    });

    testWidgets(
        'undoing an add after its temp id was adopted deletes the '
        'server row', (tester) async {
      final c = await open(tester, [row('a')]);

      await c.addItem('Eggs');
      await repo.drainOutboxOnce();
      await tester.pump();
      final serverId = '${remote.serverItemIdPrefix}1';
      expect((await rows()).containsKey(serverId), isTrue);

      expect((await c.undo()).outcome, ListUndoOutcome.applied);
      expect((await rows()).containsKey(serverId), isFalse);
      await repo.drainOutboxOnce();
      expect(remote.deleteItemCalls, [serverId]);

      await c.redo();
      expect((await rows()).containsKey(serverId), isTrue);
      expect(await queued(), ['restoreItem']);
    });

    testWidgets('a merged add takes the quantity back', (tester) async {
      final c = await open(tester, [row('a', name: 'Milk', checked: true)]);

      await c.addItem('2 Milk');
      var milk = (await rows())['a']!;
      expect(milk.quantity, 3);
      expect(milk.checked, isFalse);

      await c.undo();
      milk = (await rows())['a']!;
      expect(milk.quantity, 1);
      expect(milk.checked, isTrue);
      await c.redo();
      milk = (await rows())['a']!;
      expect(milk.quantity, 3);
      expect(milk.checked, isFalse);
    });

    testWidgets('re-adding a ticked item undoes to ticked, in place',
        (tester) async {
      final c = await open(tester, [
        row('a', name: 'Milk', checked: true, position: 0),
        row('b', position: 1),
      ]);

      expect(await c.addItem('milk'), AddItemOutcome.restored);
      expect((await rows())['a']!.position, 2);

      await c.undo();
      final milk = (await rows())['a']!;
      expect(milk.checked, isTrue);
      expect(milk.position, 0);
    });

    testWidgets(
        'undoing a delete while it is queued puts the row back as it '
        'was', (tester) async {
      final c = await open(tester, [
        row('a'),
        row('b', position: 1, checked: true, canonicalItemId: 'milk'),
        row('c', position: 2),
      ]);
      final b = (await rows())['b']!;

      await c.deleteItem(b);
      expect((await rows()).containsKey('b'), isFalse);

      final result = await c.undo();
      expect(result.outcome, ListUndoOutcome.applied);
      expect(result.restoredCount, 1);
      final back = (await rows())['b']!;
      expect(back.position, 1);
      expect(back.checked, isTrue);
      expect(back.canonicalItemId, 'milk');
      expect(await queued(), isEmpty);

      await c.redo();
      expect((await rows()).containsKey('b'), isFalse);
    });

    testWidgets('undoing a delete after it synced restores it on the server',
        (tester) async {
      final c = await open(tester, [row('a'), row('b', position: 1)]);

      await c.deleteItem((await rows())['b']!);
      await repo.drainOutboxOnce();
      expect(remote.deleteItemCalls, ['b']);

      await c.undo();
      expect((await rows())['b']!.position, 1);
      await repo.drainOutboxOnce();
      expect(remote.restoreItemCalls, ['b']);
      expect(remote.createItemCalls, isEmpty);
    });

    testWidgets('undoing clear checked restores every cleared row',
        (tester) async {
      final c = await open(tester, [
        row('a'),
        row('b', position: 1, checked: true),
        row('c', position: 2, checked: true),
      ]);

      await c.clearItems(onlyChecked: true);
      expect((await rows()).keys, ['a']);

      final result = await c.undo();
      expect(result.restoredCount, 2);
      expect((await rows()).keys.toSet(), {'a', 'b', 'c'});
      expect(await queued(), isEmpty, reason: 'the queued clear is withdrawn');

      await c.redo();
      expect((await rows()).keys, ['a']);
      await c.undo();
      expect((await rows()).keys.toSet(), {'a', 'b', 'c'});
    });

    testWidgets('a reorder undoes and redoes', (tester) async {
      final c = await open(tester, [
        row('a', position: 0),
        row('b', position: 1),
        row('c', position: 2),
      ]);
      await tester.pump();

      await c.reorderOpen(0, 3); // a to the end
      List<String> order(Map<String, ListItem> byId) => (byId.values.toList()
            ..sort((x, y) => x.position.compareTo(y.position)))
          .map((i) => i.id)
          .toList();
      expect(order(await rows()), ['b', 'c', 'a']);

      await c.undo();
      expect(order(await rows()), ['a', 'b', 'c']);
      await c.redo();
      expect(order(await rows()), ['b', 'c', 'a']);
    });

    testWidgets('a rename and a reminder undo and redo', (tester) async {
      final c = await open(tester, []);
      final at = DateTime.now().add(const Duration(days: 1));

      await c.renameList('Weekend');
      await c.setReminder(at);

      await c.undo();
      expect(c.remindAt, isNull);
      expect((await repo.queuedListReminder(listId))!.remindAt, isNull);
      await c.undo();
      expect(c.listName, 'Groceries');
      expect((await repo.getListOnce(listId))!.name, 'Groceries');

      await c.redo();
      expect(c.listName, 'Weekend');
      await c.redo();
      expect(c.remindAt!.isAtSameMomentAs(at), isTrue);
    });

    testWidgets('a step a housemate changed meanwhile is skipped',
        (tester) async {
      final c = await open(tester, [row('a', name: 'Milk')]);

      await c.updateItemFields((await rows())['a']!, name: 'Oat milk');
      // A household member renames it again over SSE.
      await db.upsertListItemsRows([row('a', name: 'Soy milk')]);

      final result = await c.undo();
      expect(result.outcome, ListUndoOutcome.changedElsewhere);
      expect((await rows())['a']!.name, 'Soy milk');
      expect(c.undoStack.canUndo, isFalse);
      expect(c.undoStack.canRedo, isFalse, reason: 'the step is dropped');
    });

    testWidgets('a removed item cannot be un-ticked', (tester) async {
      final c = await open(tester, [row('a')]);
      await c.toggleItem((await rows())['a']!, true, disableAnimations: true);
      await db.deleteListItemsByIds(['a']); // a housemate deleted it

      expect((await c.undo()).outcome, ListUndoOutcome.changedElsewhere);
    });

    Future<void> canonical(String id, String name) => db.upsertCanonicalItems([
          CanonicalItemsTableCompanion.insert(
            id: id,
            groupId: 'group-1',
            nameEn: drift.Value(name),
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        ]);

    Future<int> count(String table) async =>
        (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
            .read<int>('n');

    testWidgets(
        'undoing a tick takes back its purchase exactly: history, '
        'bought-together counts and its queued ops', (tester) async {
      final c = await open(tester, [
        row('a', name: 'Milk', canonicalItemId: 'milk'),
        row('b', name: 'Bread', canonicalItemId: 'bread', position: 1),
      ]);
      await canonical('milk', 'Milk');
      await canonical('bread', 'Bread');

      await c.toggleItem((await rows())['b']!, true, disableAnimations: true);
      final afterBread = await queued();
      await c.toggleItem((await rows())['a']!, true, disableAnimations: true);
      expect(await count('purchase_history_table'), 2);
      expect(await count('item_cooccurrence_table'), 1,
          reason: 'milk was bought with the bread');

      await c.undo();
      expect((await rows())['a']!.checked, isFalse);
      expect(await count('purchase_history_table'), 1);
      expect(await count('item_cooccurrence_table'), 0);
      expect(await queued(), afterBread,
          reason: "the milk tick's update and purchase never leave the device");

      // Nothing of it reaches the server.
      await repo.drainOutboxOnce();
      expect(remote.groceryPurchaseCalls, hasLength(1));
      expect(remote.updateItemCalls.map((call) => call.itemId), ['b']);

      // Redo records it again, as a new tick would.
      await c.redo();
      expect(await count('purchase_history_table'), 2);
      expect(await count('item_cooccurrence_table'), 1);
    });

    testWidgets(
        'undoing a tick of an unrecognised word puts its tally back, '
        'and takes back a promotion it crossed', (tester) async {
      final c = await open(tester, [row('a', name: 'Fassi')]);

      await c.toggleItem((await rows())['a']!, true, disableAnimations: true);
      expect(await count('local_item_signals_table'), 1);
      await c.undo();
      expect(await count('local_item_signals_table'), 0);
      expect(await queued(), isEmpty);

      // Two earlier shopping trips already counted it: this tick promotes it.
      final seen = DateTime.now().subtract(const Duration(days: 2));
      await db.upsertLocalItemSignal(LocalItemSignalsTableData(
        groupId: 'group-1',
        normalizedName: 'fassi',
        displayName: 'Fassi',
        count: 2,
        firstSeen: seen.subtract(const Duration(days: 7)),
        lastSeen: seen,
      ).toCompanion(false));
      final before = await db.getLocalItemSignal(
          groupId: 'group-1', normalizedName: 'fassi');
      await c.toggleItem((await rows())['a']!, true, disableAnimations: true);
      final minted = (await rows())['a']!.canonicalItemId;
      expect(minted, isNotNull, reason: 'promoted on the third purchase');
      expect(await count('purchase_history_table'), 1);

      await c.undo();
      final signal = await db.getLocalItemSignal(
          groupId: 'group-1', normalizedName: 'fassi');
      expect(signal, before, reason: 'the tally is exactly as it was');
      expect((await rows())['a']!.canonicalItemId, isNull);
      expect(await db.getCanonicalItemsByIds([minted!]), isEmpty);
      expect(await count('purchase_history_table'), 0);
      expect(await queued(), isEmpty);
    });

    testWidgets('an add that is undone never reaches the server',
        (tester) async {
      final c = await open(tester, [row('a')]);

      await c.addItem('Eggs');
      expect(await queued(), ['createItem']);
      await c.undo();
      expect(await queued(), isEmpty);

      await repo.drainOutboxOnce();
      expect(remote.createItemCalls, isEmpty);
      expect(remote.deleteItemCalls, isEmpty);
    });

    testWidgets(
        'a delete that is undone never reaches the server and keeps its '
        'id and place', (tester) async {
      final c = await open(tester, [
        row('a'),
        row('b', position: 1),
        row('c', position: 2),
      ]);

      await c.deleteItem((await rows())['b']!);
      await c.undo();
      final back = (await rows())['b']!;
      expect(back.position, 1);

      await repo.drainOutboxOnce();
      expect(remote.deleteItemCalls, isEmpty);
      expect(remote.restoreItemCalls, isEmpty);
      expect(remote.createItemCalls, isEmpty,
          reason: 'same id, so its photos still hang off it');
    });

    testWidgets(
        'notes are stored on the device and round-trip through '
        'an edit and its undo', (tester) async {
      final c = await open(tester, [row('a', name: 'Milk')]);
      await (db.update(db.listItemsTable)..where((t) => t.id.equals('a')))
          .write(const ListItemsTableCompanion(note: drift.Value('organic')));
      expect((await rows())['a']!.note, 'organic');

      // A name edit leaves the note alone, and so does its undo.
      await c.updateItemFields((await rows())['a']!, name: 'Oat milk');
      expect((await rows())['a']!.note, 'organic');
      await c.undo();
      expect((await rows())['a']!.name, 'Milk');
      expect((await rows())['a']!.note, 'organic');

      // A note edit is stored, and undone back to the note it replaced.
      await c.updateItemFields((await rows())['a']!, note: 'semi-skimmed');
      expect((await rows())['a']!.note, 'semi-skimmed');
      await c.undo();
      expect((await rows())['a']!.note, 'organic');
      await c.redo();
      expect((await rows())['a']!.note, 'semi-skimmed');

      // A new item's note is stored with it, and the server's note lands in
      // the cache on a refresh.
      final added = await repo.createItemOfflineFirst(listId,
          const CreateListItemRequest(name: 'Eggs', note: 'free range'));
      expect((await rows())[added.id]!.note, 'free range');
      remote.itemsToReturn = [
        ListItem(
          id: 'a',
          listId: listId,
          name: 'Milk',
          quantity: 1,
          unit: '',
          note: 'from the farm',
          checked: false,
          position: 0,
          createdAt: DateTime.utc(2026, 1, 5),
          updatedAt: DateTime.utc(2026, 1, 6),
        ),
      ];
      await (db.delete(db.outboxOps)).go();
      await repo.refreshItems(listId);
      expect((await rows())['a']!.note, 'from the farm');
    });

    testWidgets('a new change clears redo', (tester) async {
      final c = await open(tester, [row('a'), row('b', position: 1)]);

      await c.toggleItem((await rows())['a']!, true, disableAnimations: true);
      await c.undo();
      expect(c.undoStack.canRedo, isTrue);

      await c.toggleItem((await rows())['b']!, true, disableAnimations: true);
      expect(c.undoStack.canRedo, isFalse);
      expect((await c.redo()).outcome, ListUndoOutcome.nothing);
    });
  });
}
