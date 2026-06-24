import 'dart:async';

import 'package:dio/dio.dart';

import 'package:mitlist/models/finance_models.dart' as finance;
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/services/chore_service.dart';
import 'package:mitlist/services/connectivity_service.dart';
import 'package:mitlist/services/finance_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/services/list_service.dart';
import 'package:mitlist/services/pinwall_service.dart';
import 'package:mitlist/services/token_store.dart';

// ---------------------------------------------------------------------------
// FakeConnectivityService
// ---------------------------------------------------------------------------

/// Controllable stand-in for [ConnectivityService].
///
/// Call [setOnline] to push a value to [onStatusChange] and to change the
/// result returned by [isOnline].
class FakeConnectivityService implements ConnectivityService {
  final _controller = StreamController<bool>.broadcast();
  bool _online;

  FakeConnectivityService({bool initiallyOnline = true})
      : _online = initiallyOnline;

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<bool> isOnline({bool forceProbe = false}) async => _online;

  @override
  void dispose() {
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// FakeFinanceService
// ---------------------------------------------------------------------------

/// Records calls, returns canned responses, and can be made to throw on demand.
class FakeFinanceService implements FinanceService {
  final List<finance.CreateExpenseRequest> createCalls = [];
  final List<UpdateExpenseCall> updateCalls = [];
  final List<String> deleteCalls = [];

  /// When non-null, the next [createExpense] call will throw this exception.
  Exception? throwOnCreate;

  /// When non-null, the next [updateExpense] call will throw this exception.
  Exception? throwOnUpdate;

  /// Server ID returned by [createExpense] (default: a fixed UUID).
  String serverExpenseId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  @override
  Future<finance.Expense> createExpense(
      finance.CreateExpenseRequest req) async {
    createCalls.add(req);
    if (throwOnCreate != null) {
      final err = throwOnCreate!;
      throwOnCreate = null;
      throw err;
    }
    return finance.Expense(
      id: serverExpenseId,
      groupId: req.groupId,
      payerId: req.payerId,
      amount: req.amount,
      baseAmount: req.baseAmount,
      fxRate: req.fxRate,
      description: req.description,
      category: req.category,
      currency: req.currency,
      notes: req.notes,
      date: req.date,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<finance.Expense> updateExpense(
      String id, finance.UpdateExpenseRequest req) async {
    updateCalls.add(UpdateExpenseCall(id, req));
    if (throwOnUpdate != null) {
      final err = throwOnUpdate!;
      throwOnUpdate = null;
      throw err;
    }
    return finance.Expense(
      id: id,
      groupId: 'group-1',
      payerId: req.payerId ?? 'payer-1',
      amount: req.amount ?? 0,
      baseAmount: req.baseAmount ?? req.amount ?? 0,
      fxRate: req.fxRate ?? 1.0,
      description: req.description ?? '',
      category: req.category ?? 'other',
      currency: req.currency ?? 'USD',
      notes: req.notes ?? '',
      date: req.date ?? DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    deleteCalls.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented on FakeFinanceService');
}

class UpdateExpenseCall {
  final String id;
  final finance.UpdateExpenseRequest req;
  UpdateExpenseCall(this.id, this.req);
}

// ---------------------------------------------------------------------------
// FakeListService
// ---------------------------------------------------------------------------

/// Records calls, returns canned responses, and can be made to throw on demand.
class FakeListService implements ListService {
  final List<CreateItemCall> createItemCalls = [];
  final List<UpdateItemCall> updateItemCalls = [];
  final List<String> deleteItemCalls = [];
  final List<ReorderItemsCall> reorderItemsCalls = [];
  final List<AddItemAmountCall> addItemAmountCalls = [];
  final List<ClearItemsCall> clearItemsCalls = [];

  /// Cumulative server-side quantity per (list|name|unit), so [addItemAmount]
  /// echoes additive merge semantics like the real endpoint.
  final Map<String, double> _amountByKey = {};

  Exception? throwOnCreateItem;

  /// When non-null, the next [reorderItems] call will throw this exception.
  Exception? throwOnReorderItems;

  /// Prefix used when constructing the server ID for [createItem].
  String serverItemIdPrefix = 'server-item-';
  int _counter = 0;

  /// Items returned by [listItems]. Set this in tests that need a seeded server
  /// response (e.g. to exercise the restore-pending path after a refresh).
  List<ListItem> itemsToReturn = const [];

  @override
  Future<ListItem> createItem(String listId, CreateListItemRequest req) async {
    createItemCalls.add(CreateItemCall(listId, req));
    if (throwOnCreateItem != null) {
      final err = throwOnCreateItem!;
      throwOnCreateItem = null;
      throw err;
    }
    _counter++;
    final now = DateTime.utc(2026, 1, 1);
    return ListItem(
      id: '$serverItemIdPrefix$_counter',
      listId: listId,
      name: req.name,
      quantity: req.quantity,
      unit: req.unit,
      note: req.note,
      canonicalItemId: req.canonicalItemId,
      checked: false,
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ListItem> updateItem(
      String listId, String itemId, UpdateListItemRequest req) async {
    updateItemCalls.add(UpdateItemCall(listId, itemId, req));
    final now = DateTime.utc(2026, 1, 1);
    return ListItem(
      id: itemId,
      listId: listId,
      name: req.name ?? 'Updated',
      quantity: req.quantity ?? 1,
      unit: req.unit ?? '',
      checked: req.checked ?? false,
      position: req.position ?? 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ListItem> addItemAmount(
      String listId, AddListItemAmountRequest req) async {
    addItemAmountCalls.add(AddItemAmountCall(listId, req));
    final key = '$listId|${req.name}|${req.unit}';
    final total = (_amountByKey[key] ?? 0) + req.amount;
    _amountByKey[key] = total;
    _counter++;
    final now = DateTime.utc(2026, 1, 1);
    return ListItem(
      id: '$serverItemIdPrefix$_counter',
      listId: listId,
      name: req.name,
      quantity: total,
      unit: req.unit,
      note: req.note,
      checked: false,
      position: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> deleteItem(String listId, String itemId) async {
    deleteItemCalls.add(itemId);
  }

  @override
  Future<void> reorderItems(String listId, ReorderItemsRequest req) async {
    reorderItemsCalls.add(ReorderItemsCall(listId, req.itemIds));
    if (throwOnReorderItems != null) {
      final err = throwOnReorderItems!;
      throwOnReorderItems = null;
      throw err;
    }
  }

  @override
  Future<Map<String, dynamic>> clearItems(
    String listId, {
    bool onlyChecked = false,
  }) async {
    clearItemsCalls.add(ClearItemsCall(listId, onlyChecked));
    return {'cleared': true};
  }

  @override
  Future<List<ListItem>> listItems(String listId,
      {int limit = 50, int offset = 0}) async {
    return itemsToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented on FakeListService');
}

class ClearItemsCall {
  final String listId;
  final bool onlyChecked;
  ClearItemsCall(this.listId, this.onlyChecked);
}

class ReorderItemsCall {
  final String listId;
  final List<String> itemIds;
  ReorderItemsCall(this.listId, this.itemIds);
}

class CreateItemCall {
  final String listId;
  final CreateListItemRequest req;
  CreateItemCall(this.listId, this.req);
}

class AddItemAmountCall {
  final String listId;
  final AddListItemAmountRequest req;
  AddItemAmountCall(this.listId, this.req);
}

class UpdateItemCall {
  final String listId;
  final String itemId;
  final UpdateListItemRequest req;
  UpdateItemCall(this.listId, this.itemId, this.req);
}

// ---------------------------------------------------------------------------
// FakeTokenStore
// ---------------------------------------------------------------------------

/// In-memory [TokenStore] for use in tests. No platform dependencies.
class FakeTokenStore implements TokenStore {
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

// ---------------------------------------------------------------------------
// FakeGroupService
// ---------------------------------------------------------------------------

/// Minimal fake for [GroupService] that records [joinGroup] calls and can be
/// made to throw on demand.
class FakeGroupService implements GroupService {
  final List<JoinGroupRequest> joinCalls = [];

  /// When non-null, the next [joinGroup] call will throw this exception.
  Exception? throwOnJoin;

  /// The [Group] returned by [joinGroup] (when not throwing).
  Group joinResult = Group(
    id: 'group-fake-1',
    name: 'Test Household',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  /// Number of times [listGroups] has been called.
  int listCalls = 0;

  /// When non-null, [listGroups] throws this (simulates being offline).
  Exception? throwOnList;

  /// The list returned by [listGroups] when not throwing.
  List<Group> listResult = const [];

  @override
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async {
    listCalls++;
    if (throwOnList != null) throw throwOnList!;
    return listResult;
  }

  @override
  Future<Group> joinGroup(JoinGroupRequest request) async {
    joinCalls.add(request);
    if (throwOnJoin != null) {
      final err = throwOnJoin!;
      throwOnJoin = null;
      throw err;
    }
    return joinResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented on FakeGroupService');
}

// ---------------------------------------------------------------------------
// FakeChoreService
// ---------------------------------------------------------------------------

/// Minimal fake for [ChoreService]. Every method throws by default, simulating
/// an offline device — exactly the condition under which the repository's
/// optimistic cache patches must survive (the swallowed drain/refresh can't
/// overwrite them).
class FakeChoreService implements ChoreService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('offline: ${invocation.memberName}');
}

// ---------------------------------------------------------------------------
// FakePinwallService
// ---------------------------------------------------------------------------

/// Minimal fake for [PinwallService]; all methods throw (offline). The
/// offline-first create/delete paths never touch it synchronously.
class FakePinwallService implements PinwallService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('offline: ${invocation.memberName}');
}

// ---------------------------------------------------------------------------
// DioException helper
// ---------------------------------------------------------------------------

DioException fakeDioException({int statusCode = 500, Object? data}) {
  return DioException(
    requestOptions: RequestOptions(path: '/fake'),
    response: Response(
      requestOptions: RequestOptions(path: '/fake'),
      statusCode: statusCode,
      data: data ?? {'detail': 'server error'},
    ),
    type: DioExceptionType.badResponse,
  );
}
