import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/list_models.dart';
import '../services/list_service.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';

class ListRepository {
  final AppDatabase _db;
  final ListService _remote;
  final Uuid _uuid;

  SseService? _sseService;
  StreamSubscription<SseEvent>? _sseSub;

  ListRepository({
    required AppDatabase db,
    required ListService remote,
    Uuid? uuid,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid();

  Stream<List<ItemList>> watchListsByGroup(String groupId) {
    return _db
        .watchListsByGroup(groupId)
        .map((rows) => rows.map(_toItemList).toList());
  }

  Future<List<ItemList>> getListsByGroupOnce(String groupId) async {
    final rows = await _db.getListsByGroupOnce(groupId);
    return rows.map(_toItemList).toList();
  }

  Stream<List<ListItem>> watchItemsByList(String listId) {
    return _db
        .watchItemsByList(listId)
        .map((rows) => rows.map(_toListItem).toList());
  }

  Future<List<ListItem>> getItemsByListOnce(String listId) async {
    final rows = await _db.getItemsByListOnce(listId);
    return rows.map(_toListItem).toList();
  }

  Future<int> refreshLists(String groupId,
      {int limit = 200, int offset = 0}) async {
    final remote =
        await _remote.listLists(groupId, limit: limit, offset: offset);
    await _db.clearListsForGroup(groupId);
    await _db.upsertListsRows(remote.map(_toListsRow));
    return remote.length;
  }

  Future<int> refreshItems(String listId,
      {int limit = 500, int offset = 0}) async {
    final remote =
        await _remote.listItems(listId, limit: limit, offset: offset);
    await _db.deleteItemsForList(listId);
    await _db.upsertListItemsRows(remote.map(_toListItemsRow));
    return remote.length;
  }

  Future<void> refreshListDetail(String listId) async {
    final results = await Future.wait<Object>([
      _remote.getList(listId),
      _remote.listItems(listId, limit: 500, offset: 0),
    ]);
    final list = results[0] as ItemList;
    final items = results[1] as List<ListItem>;
    await _db.upsertListsRows([_toListsRow(list)]);
    await _db.deleteItemsForList(listId);
    await _db.upsertListItemsRows(items.map(_toListItemsRow));
  }

  // ---------------------------------------------------------------------------
  // Offline-first writes (optimistic local + outbox)
  // ---------------------------------------------------------------------------

  Future<ListItem> createItemOfflineFirst(
      String listId, CreateListItemRequest req) async {
    final tempId = _uuid.v4();
    final now = DateTime.now();

    final local = ListItem(
      id: tempId,
      listId: listId,
      name: req.name,
      quantity: req.quantity,
      unit: req.unit,
      note: req.note,
      checked: false,
      position: 0,
      createdAt: now,
      updatedAt: now,
    );

    await _db.upsertListItemsRows([_toListItemsRow(local)]);
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createItem',
      payload: {
        'listId': listId,
        'tempId': tempId,
        'name': req.name,
        'quantity': req.quantity,
        'unit': req.unit,
        'note': req.note,
      },
      idempotencyKey: 'createItem:$tempId',
    );

    // Best-effort immediate sync.
    await drainOutboxOnce();
    return local;
  }

  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    // Optimistic local patch
    final existingRow = (await _db.getItemsByListOnce(listId))
        .firstWhere((e) => e.id == itemId);
    final existing = _toListItem(existingRow);
    final patched = ListItem(
      id: existing.id,
      listId: existing.listId,
      name: req.name ?? existing.name,
      quantity: req.quantity ?? existing.quantity,
      unit: req.unit ?? existing.unit,
      note: req.note ?? existing.note,
      checked: req.checked ?? existing.checked,
      position: req.position ?? existing.position,
      priceCents: req.priceCents ?? existing.priceCents,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await _db.upsertListItemsRows([_toListItemsRow(patched)]);

    // Record purchase signal when item transitions to checked.
    if ((req.checked ?? false) && !existing.checked) {
      _recordPurchaseSignal(listId, itemId, existingRow);
    }

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'updateItem',
      payload: {
        'listId': listId,
        'itemId': itemId,
        'patch': req.toJson(),
      },
      idempotencyKey:
          'updateItem:$itemId:${patched.updatedAt.toIso8601String()}',
    );

    await drainOutboxOnce();
    return patched;
  }

  Future<void> deleteListLocal(String listId) async {
    await (_db.delete(_db.listsTable)..where((t) => t.id.equals(listId))).go();
    await (_db.delete(_db.listItemsTable)
          ..where((t) => t.listId.equals(listId)))
        .go();
  }

  Future<void> deleteItemOfflineFirst(String listId, String itemId) async {
    // Optimistic local delete
    await (_db.delete(_db.listItemsTable)..where((t) => t.id.equals(itemId)))
        .go();

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'deleteItem',
      payload: {
        'listId': listId,
        'itemId': itemId,
      },
      idempotencyKey: 'deleteItem:$itemId',
    );

    await drainOutboxOnce();
  }

  Future<void> drainOutboxOnce() async {
    final batch = await _db.getOutboxBatchByTypes(
      ['createItem', 'updateItem', 'deleteItem'],
      limit: 25,
    );
    if (batch.isEmpty) return;

    for (final op in batch) {
      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
      } catch (_) {
        await _db.deleteOutboxOp(op.id);
        continue;
      }

      try {
        switch (op.type) {
          case 'createItem':
            await _syncCreateItem(op.id, payload);
            break;
          case 'updateItem':
            await _syncUpdateItem(op.id, payload);
            break;
          case 'deleteItem':
            await _syncDeleteItem(op.id, payload);
            break;
        }
      } catch (e) {
        await _db.markOutboxAttempt(op.id, error: 'Something went wrong.');
        // Stop early: keep ordering and avoid hammering the server.
        return;
      }
    }
  }

  Future<void> _syncCreateItem(
      String opId, Map<String, dynamic> payload) async {
    final listId = payload['listId'] as String?;
    final tempId = payload['tempId'] as String?;
    final name = payload['name'] as String?;
    if (listId == null || tempId == null || name == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final created = await _remote.createItem(
      listId,
      CreateListItemRequest(
        name: name,
        quantity: (payload['quantity'] as num?)?.toDouble() ?? 1,
        unit: payload['unit'] as String? ?? '',
        note: payload['note'] as String? ?? '',
      ),
    );

    await _db.replaceTempItemId(tempId: tempId, server: created);
    await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncUpdateItem(
      String opId, Map<String, dynamic> payload) async {
    final listId = payload['listId'] as String?;
    final itemId = payload['itemId'] as String?;
    final patch = payload['patch'];
    if (listId == null || itemId == null || patch is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final updated = await _remote.updateItem(
      listId,
      itemId,
      UpdateListItemRequest(
        name: patch['name'] as String?,
        quantity: (patch['quantity'] as num?)?.toDouble(),
        unit: patch['unit'] as String?,
        note: patch['note'] as String?,
        checked: patch['checked'] as bool?,
        position: patch['position'] as int?,
      ),
    );

    await _db.upsertListItemsRows([_toListItemsRow(updated)]);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncDeleteItem(
      String opId, Map<String, dynamic> payload) async {
    final listId = payload['listId'] as String?;
    final itemId = payload['itemId'] as String?;
    if (listId == null || itemId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    await _remote.deleteItem(listId, itemId);
    await _db.deleteOutboxOp(opId);
  }

  // ---------------------------------------------------------------------------
  // SSE real-time sync
  // ---------------------------------------------------------------------------

  /// Start receiving real-time updates for [groupId] via SSE.
  ///
  /// Events that mutate list items are applied directly to local SQLite,
  /// which causes the existing [watchItemsByList] Drift streams to fire.
  void attachSse(SseService sseService, String groupId) {
    if (_sseService == sseService) return;
    _sseSub?.cancel();
    _sseService = sseService;
    sseService.connect(groupId);
    _sseSub = sseService.events.listen(_handleSseEvent);
  }

  /// Stop the active SSE subscription without closing the service itself.
  void detachSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseService = null;
  }

  Future<void> _handleSseEvent(SseEvent event) async {
    switch (event.type) {
      case 'list:item_created':
      case 'list:item_updated':
        final item = _itemFromPayload(event.payload);
        if (item != null) {
          await _db.upsertListItemsRows([_toListItemsRow(item)]);
        }
      case 'list:item_deleted':
        final id = event.payload['id'] as String?;
        if (id != null) {
          await (_db.delete(_db.listItemsTable)..where((t) => t.id.equals(id)))
              .go();
        }
      case 'list:items_cleared':
        final listId = event.payload['list_id'] as String?;
        if (listId != null) {
          await refreshItems(listId);
        }
    }
  }

  ListItem? _itemFromPayload(Map<String, dynamic> payload) {
    try {
      return ListItem.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping
  // ---------------------------------------------------------------------------

  ListsTableCompanion _toListsRow(ItemList list) {
    return ListsTableCompanion(
      id: Value(list.id),
      groupId: Value(list.groupId),
      name: Value(list.name),
      type: Value(list.type),
      itemCount: Value(list.itemCount),
      itemPreviewJson: Value(jsonEncode(list.itemPreview)),
      createdAt: Value(list.createdAt),
      updatedAt: Value(list.updatedAt),
    );
  }

  ItemList _toItemList(ListsTableData row) {
    final preview = _safeStringList(row.itemPreviewJson);
    return ItemList(
      id: row.id,
      groupId: row.groupId,
      name: row.name,
      type: row.type,
      itemCount: row.itemCount,
      itemPreview: preview,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ListItemsTableCompanion _toListItemsRow(ListItem item) {
    return ListItemsTableCompanion(
      id: Value(item.id),
      listId: Value(item.listId),
      name: Value(item.name),
      quantity: Value(item.quantity),
      unit: Value(item.unit),
      checked: Value(item.checked),
      position: Value(item.position),
      priceCents: Value(item.priceCents),
      createdAt: Value(item.createdAt),
      updatedAt: Value(item.updatedAt),
    );
  }

  ListItem _toListItem(ListItemsTableData row) {
    return ListItem(
      id: row.id,
      listId: row.listId,
      name: row.name,
      quantity: row.quantity,
      unit: row.unit,
      note: '',
      checked: row.checked,
      position: row.position,
      priceCents: row.priceCents,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 6: purchase signal on item check-off
  // ---------------------------------------------------------------------------

  /// Records a purchase event and increments co-occurrence counts when an item
  /// transitions to checked. Fire-and-forget; errors are silently swallowed
  /// because this is a background signal, not a critical write.
  void _recordPurchaseSignal(
    String listId,
    String itemId,
    ListItemsTableData row,
  ) {
    unawaited(_doPurchaseSignal(listId, itemId, row));
  }

  Future<void> _doPurchaseSignal(
    String listId,
    String itemId,
    ListItemsTableData row,
  ) async {
    try {
      final canonicalId = row.canonicalItemId;
      if (canonicalId == null) return;

      final groupId = await _db.getListGroupId(listId);
      if (groupId == null) return;
      // Insert a purchase_history row.
      await _db.insertPurchaseHistory(PurchaseHistoryTableCompanion.insert(
        id: _uuid.v4(),
        groupId: groupId,
        canonicalItemId: Value(canonicalId),
        listItemId: Value(itemId),
        quantity: Value(row.quantity),
        unit: Value(row.unit),
        version: const Value(0),
        purchasedAt: DateTime.now(),
      ));

      // Increment co-occurrence with every other checked item in the same list.
      final peers = await _db.getCheckedItemsWithCanonical(listId);
      for (final peer in peers) {
        if (peer.id == itemId) continue;
        final peerCanonicalId = peer.canonicalItemId;
        if (peerCanonicalId == null) continue;
        await _db.incrementCooccurrence(
          groupId: groupId,
          itemAId: canonicalId,
          itemBId: peerCanonicalId,
        );
      }
    } catch (_) {
      // Best-effort; never throw from a background signal.
    }
  }

  List<String> _safeStringList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      // Failed to parse JSON string list; return empty.
    }
    return const [];
  }
}
