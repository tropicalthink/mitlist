import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';

import '../models/list_models.dart';
import '../utils/uuid_validation.dart';
import '../services/list_service.dart';
import '../services/error_reporter.dart';
import '../services/scan/local_item_promotion_service.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';
import 'grocery_repository.dart';
import 'outbox_drainer.dart';

class ListRepository {
  final AppDatabase _db;
  final ListService _remote;
  final Uuid _uuid;
  final bool _autoSync;

  /// Promotes repeatedly-checked-off words the resolver couldn't map into
  /// household-local canonical items. Defaults to a db-backed instance so
  /// direct constructions (tests) still learn; production injects the same.
  final LocalItemPromotionService _promotionService;

  /// Used to push a freshly-promoted alias to the household's other devices.
  /// Optional: when absent (tests / offline construction) promotion still works
  /// locally and the canonical still syncs via the recordPurchase op.
  final GroceryRepository? _groceryRepo;

  bool _isDraining = false;

  /// Set when an op is enqueued while a drain pass is already running. That
  /// pass fetched its batch before the new op existed, so without this flag
  /// the op would sit in the outbox until the next user edit or app resume.
  bool _drainRequested = false;

  SseService? _sseService;
  StreamSubscription<SseEvent>? _sseSub;
  String? _sseGroupId;

  /// SSE item events carry only ids (the body is untrusted and the durable
  /// event log stays small), so each one triggers a refetch of the list's
  /// items. A burst of events for one list is coalesced into a single fetch,
  /// and events arriving while a fetch is in flight queue exactly one more.
  static const _sseRefreshCoalesce = Duration(milliseconds: 250);
  final Map<String, Timer> _sseRefreshTimers = {};
  final Set<String> _sseRefreshInFlight = {};
  final Set<String> _sseRefreshDirty = {};

  ListRepository({
    required AppDatabase db,
    required ListService remote,
    Uuid? uuid,
    bool autoSync = true,
    LocalItemPromotionService? promotionService,
    GroceryRepository? groceryRepo,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _autoSync = autoSync,
        _promotionService = promotionService ?? LocalItemPromotionService(db),
        _groceryRepo = groceryRepo;

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

  /// Creates a list on the server and lands it in the local cache in the same
  /// step. The create sheet used to call the service directly, which left
  /// every DB-backed watcher — the lists grid, the hub quick start — unaware
  /// the list existed until something forced a refresh: the new list simply
  /// didn't appear, and the quick-start step it satisfied stayed unticked.
  Future<ItemList> createList(CreateListRequest req) async {
    final created = await _remote.createList(req);
    await _db.upsertListsRows([_toListsRow(created)]);
    return created;
  }

  Future<int> refreshLists(String groupId,
      {int limit = 200, int offset = 0}) async {
    final remote =
        await _remote.listLists(groupId, limit: limit, offset: offset);
    // Upsert first, never wipe-then-repopulate: a clear before the upsert made
    // the Drift watch stream emit an empty frame, flashing the whole lists
    // grid away on every refresh. Stale local rows (deleted on another device)
    // are pruned only when this page is the complete server set — with a full
    // page we can't tell "missing" from "on a later page".
    await _db.upsertListsRows(remote.map(_toListsRow));
    if (offset == 0 && remote.length < limit) {
      await _db.deleteListsForGroupExcluding(
        groupId,
        remote.map((l) => l.id).toSet(),
      );
    }
    unawaited(_hydrateMissingListPreviews(remote));
    return remote.length;
  }

  /// Persists a rename into the local cache so screens watching the lists
  /// stream (the lists grid) reflect it immediately, whatever route the user
  /// takes back.
  Future<void> renameListLocal(String listId, String name) =>
      _db.updateListName(listId, name);

  Future<int> refreshItems(String listId,
      {int limit = 500, int offset = 0}) async {
    final remote =
        await _remote.listItems(listId, limit: limit, offset: offset);
    if (offset == 0) {
      await _reconcileListItems(listId, remote);
    } else {
      await _db.upsertListItemsRows(remote.map(_toListItemsRow));
    }
    await _patchListPreviewFromLocalItems(listId);
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
    await _reconcileListItems(listId, items);
    await _patchListPreviewFromLocalItems(listId);
  }

  /// Reconciles local items for [listId] with the server's current
  /// [serverItems] without ever wiping the table first: server rows are
  /// upserted immediately (so the watch stream never emits an empty gap), then
  /// only local rows the server no longer has AND that aren't still pending in
  /// the outbox are removed. A row created (or edited) locally moments ago and
  /// not yet synced therefore survives a concurrent refresh untouched instead
  /// of vanishing for the round trip and being restored after the fact.
  Future<void> _reconcileListItems(
    String listId,
    List<ListItem> serverItems,
  ) async {
    // Canonical slugs are an on-device enrichment and are intentionally not
    // sent to the list API unless they happen to be API UUIDs. Preserve that
    // enrichment when an ordinary server refresh returns the same row without
    // a canonical id.
    final beforeRefresh = await _db.getItemsByListOnce(listId);
    final localCanonicalById = {
      for (final row in beforeRefresh)
        if (row.canonicalItemId != null) row.id: row.canonicalItemId!,
    };
    final enrichedServerItems = serverItems
        .map((item) => item.canonicalItemId != null
            ? item
            : _withCanonicalItemId(item, localCanonicalById[item.id]))
        .toList(growable: false);
    final pendingIds = await _db.getPendingListItemIds();
    // A row with an unsynced local edit (or delete) keeps its optimistic state:
    // the server still holds the pre-edit value, and the op's own sync writes
    // the server's answer back. Overwriting it here would flash the old value
    // (or resurrect a deleted row) every time an SSE event lands mid-sync.
    await _db.upsertListItemsRows(enrichedServerItems
        .where((item) => !pendingIds.contains(item.id))
        .map(_toListItemsRow));

    final serverIds = serverItems.map((i) => i.id).toSet();
    final localRows = await _db.getItemsByListOnce(listId);

    final staleIds = localRows
        .where((r) => !serverIds.contains(r.id) && !pendingIds.contains(r.id))
        .map((r) => r.id)
        .toList();
    if (staleIds.isNotEmpty) {
      await _db.deleteListItemsByIds(staleIds);
    }

    // Push any surviving pending (not-yet-synced) rows past the server's max
    // position so they never collide with a synced position and stay
    // appended at the bottom until they sync, matching prior behavior.
    final pendingRows = localRows
        .where((r) => !serverIds.contains(r.id) && pendingIds.contains(r.id))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    if (pendingRows.isNotEmpty) {
      var maxPos = -1;
      for (final i in serverItems) {
        if (i.position > maxPos) maxPos = i.position;
      }
      var pos = maxPos + 1;
      final updates = <ListItemsTableCompanion>[];
      for (final row in pendingRows) {
        if (row.position != pos) {
          final item = _toListItem(row);
          updates.add(_toListItemsRow(
            ListItem(
              id: item.id,
              listId: item.listId,
              name: item.name,
              quantity: item.quantity,
              unit: item.unit,
              checked: item.checked,
              position: pos,
              priceCents: item.priceCents,
              canonicalItemId: item.canonicalItemId,
              createdAt: item.createdAt,
              updatedAt: item.updatedAt,
            ),
          ));
        }
        pos++;
      }
      if (updates.isNotEmpty) {
        await _db.upsertListItemsRows(updates);
      }
    }
  }

  Future<String?> getGroupId(String listId) => _db.getListGroupId(listId);

  Future<String?> getListType(String listId) => _db.getListType(listId);

  // ---------------------------------------------------------------------------
  // Offline-first writes (optimistic local + outbox)
  // ---------------------------------------------------------------------------

  Future<ListItem> createItemOfflineFirst(
    String listId,
    CreateListItemRequest req, {
    bool deferImmediateSync = false,
  }) async {
    final tempId = _uuid.v4();
    final now = DateTime.now();

    // Read existing rows once and reuse them for both the append position and
    // the list-card preview, instead of re-reading the table inside the preview
    // patch. The new row appends one past the highest local position so it lands
    // at the bottom and does not jump when the create syncs.
    final existingRows = await _db.getItemsByListOnce(listId);
    var maxPos = -1;
    for (final r in existingRows) {
      if (r.position > maxPos) maxPos = r.position;
    }

    final local = ListItem(
      id: tempId,
      listId: listId,
      name: req.name,
      quantity: req.quantity,
      unit: req.unit,
      note: req.note,
      checked: false,
      position: maxPos + 1,
      priceCents: req.priceCents,
      canonicalItemId: req.canonicalItemId,
      createdAt: now,
      updatedAt: now,
    );

    // The local row and its durable sync intent are one atomic state change.
    // Otherwise a process death or enqueue failure between the writes leaves
    // an item that can never reach the server.
    await _db.transaction(() async {
      await _db.upsertListItemsRows([_toListItemsRow(local)]);
      await _patchListPreviewFromItems(
        listId,
        [...existingRows.map(_toListItem), local],
        itemCount: existingRows.length + 1,
      );
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
          if (req.priceCents != null) 'priceCents': req.priceCents,
          if (req.canonicalItemId != null)
            'canonicalItemId': req.canonicalItemId,
        },
        idempotencyKey: 'createItem:$tempId',
        entityType: 'listItem',
        entityId: tempId,
      );
    });

    // Best-effort immediate sync.
    if (_autoSync && !deferImmediateSync) unawaited(drainOutboxOnce());
    return local;
  }

  /// Offline-first equivalent of [ListService.addItemAmount]: the optimistic
  /// local write happens immediately (so the row appears instantly) and the
  /// additive server merge is replayed from the outbox.
  ///
  /// Merge semantics mirror the backend: a matching local item (same trimmed
  /// name + unit) has its quantity incremented; otherwise a new optimistic row
  /// is created. Replaying through the `/items/add` endpoint keeps multi-device
  /// increments additive server-side rather than last-write-wins.
  Future<ListItem> addItemAmountOfflineFirst(
    String listId, {
    required String name,
    required double amount,
    String unit = '',
    String note = '',
    String? canonicalItemId,
    bool deferImmediateSync = false,
  }) async {
    final now = DateTime.now();
    final existingRows = await _db.getItemsByListOnce(listId);
    final match = existingRows
        .where((r) => r.name == name && r.unit == unit)
        .sorted((a, b) => a.position.compareTo(b.position))
        .firstOrNull;

    final ListItem local;
    final String entityId;
    String? tempId;
    if (match != null) {
      final existing = _toListItem(match);
      local = ListItem(
        id: existing.id,
        listId: existing.listId,
        name: existing.name,
        quantity: existing.quantity + amount,
        unit: existing.unit,
        note: note.isNotEmpty ? note : existing.note,
        checked: false,
        position: existing.position,
        priceCents: existing.priceCents,
        canonicalItemId: existing.canonicalItemId ?? canonicalItemId,
        claimedBy: existing.claimedBy,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      entityId = existing.id;
    } else {
      tempId = _uuid.v4();
      var maxPos = -1;
      for (final r in existingRows) {
        if (r.position > maxPos) maxPos = r.position;
      }
      local = ListItem(
        id: tempId,
        listId: listId,
        name: name,
        quantity: amount,
        unit: unit,
        note: note,
        checked: false,
        position: maxPos + 1,
        canonicalItemId: canonicalItemId,
        createdAt: now,
        updatedAt: now,
      );
      entityId = tempId;
    }

    await _db.transaction(() async {
      await _db.upsertListItemsRows([_toListItemsRow(local)]);
      await _patchListPreviewFromLocalItems(listId);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'addItemAmount',
        payload: {
          'listId': listId,
          if (tempId != null) 'tempId': tempId,
          'name': name,
          'amount': amount,
          'unit': unit,
          'note': note,
          if (canonicalItemId != null) 'canonicalItemId': canonicalItemId,
        },
        // Each add is a distinct additive op, so the key is unique per enqueue
        // to avoid collapsing two separate "+amount" writes into one.
        idempotencyKey: 'addItemAmount:${_uuid.v4()}',
        entityType: 'listItem',
        entityId: entityId,
      );
    });

    if (_autoSync && !deferImmediateSync) unawaited(drainOutboxOnce());
    return local;
  }

  /// Persists an on-device canonical enrichment without creating a server
  /// update. If the item is still a temp row, its queued create/add payload is
  /// patched in the same transaction so reconciliation retains the link.
  Future<ListItem> setCanonicalItemIdLocal(
    String listId,
    String itemId,
    String? canonicalItemId,
  ) async {
    final row = (await _db.getItemsByListOnce(listId))
        .firstWhereOrNull((candidate) => candidate.id == itemId);
    if (row == null) {
      throw StateError('list item $itemId not found in local cache');
    }
    final item = _toListItem(row);
    final patched = _withCanonicalItemId(item, canonicalItemId);
    await _db.transaction(() async {
      await _db.upsertListItemsRows([_toListItemsRow(patched)]);
      await _db.updatePendingListItemCanonicalId(
        entityId: itemId,
        canonicalItemId: canonicalItemId,
      );
    });
    return patched;
  }

  /// Restarts best-effort sync after a caller briefly deferred it to enrich a
  /// durable optimistic row.
  void triggerAutoSync() {
    if (_autoSync) unawaited(drainOutboxOnce());
  }

  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    // Optimistic local patch
    final existingRow = (await _db.getItemsByListOnce(listId))
        .firstWhereOrNull((e) => e.id == itemId);
    if (existingRow == null) {
      throw StateError('list item $itemId not found in local cache');
    }
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
      canonicalItemId: req.name != null &&
              req.name!.trim().toLowerCase() !=
                  existing.name.trim().toLowerCase()
          ? null
          : existing.canonicalItemId,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await _db.transaction(() async {
      await _db.upsertListItemsRows([_toListItemsRow(patched)]);
      await _patchListPreviewFromLocalItems(listId);

      // Record purchase signal when item transitions to checked.
      if ((req.checked ?? false) && !existing.checked) {
        await _recordPurchaseSignal(listId, itemId, existingRow);
      }

      // Optimistic-concurrency base: the server updated_at this edit was based
      // on. Skip it when an edit is already queued for this item — that chain is
      // all ours, so there's no foreign server base to guard against (and using
      // the locally-bumped value would self-conflict).
      final hasPendingEdit =
          await _db.pendingOpCountForEntity('updateItem', itemId) > 0;
      final expectedUpdatedAt =
          hasPendingEdit ? null : existing.updatedAt.toUtc().toIso8601String();

      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'updateItem',
        payload: {
          'listId': listId,
          'itemId': itemId,
          'patch': req.toJson(),
          if (expectedUpdatedAt != null) 'expectedUpdatedAt': expectedUpdatedAt,
        },
        idempotencyKey:
            'updateItem:$itemId:${patched.updatedAt.toIso8601String()}',
        entityType: 'listItem',
        entityId: itemId,
      );
    });

    if (_autoSync) unawaited(drainOutboxOnce());
    return patched;
  }

  Future<void> deleteListLocal(String listId) async {
    await (_db.delete(_db.listsTable)..where((t) => t.id.equals(listId))).go();
    await (_db.delete(_db.listItemsTable)
          ..where((t) => t.listId.equals(listId)))
        .go();
  }

  Future<void> reorderItemsOfflineFirst(
    String listId,
    List<String> itemIdsInOrder,
  ) async {
    final existingRows = await _db.getItemsByListOnce(listId);
    final byId = {for (final row in existingRows) row.id: _toListItem(row)};

    final patched = <ListItemsTableCompanion>[];
    for (var i = 0; i < itemIdsInOrder.length; i++) {
      final existing = byId[itemIdsInOrder[i]];
      if (existing == null) continue;
      patched.add(
        _toListItemsRow(
          ListItem(
            id: existing.id,
            listId: existing.listId,
            name: existing.name,
            quantity: existing.quantity,
            unit: existing.unit,
            note: existing.note,
            checked: existing.checked,
            position: i,
            priceCents: existing.priceCents,
            canonicalItemId: existing.canonicalItemId,
            claimedBy: existing.claimedBy,
            createdAt: existing.createdAt,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    }

    await _db.transaction(() async {
      await _db.upsertListItemsRows(patched);
      await _patchListPreviewFromLocalItems(listId);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'reorderItems',
        payload: {'listId': listId, 'itemIds': itemIdsInOrder},
        idempotencyKey:
            'reorderItems:$listId:${DateTime.now().toIso8601String()}',
        entityType: 'list',
        entityId: listId,
      );
    });

    if (_autoSync) unawaited(drainOutboxOnce());
  }

  Future<void> deleteItemOfflineFirst(String listId, String itemId) async {
    // Optimistic local delete
    await _db.transaction(() async {
      await (_db.delete(_db.listItemsTable)..where((t) => t.id.equals(itemId)))
          .go();
      await _patchListPreviewFromLocalItems(listId);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteItem',
        payload: {'listId': listId, 'itemId': itemId},
        idempotencyKey: 'deleteItem:$itemId',
        entityType: 'listItem',
        entityId: itemId,
      );
    });

    if (_autoSync) unawaited(drainOutboxOnce());
  }

  /// Offline-first bulk check / uncheck. Flips every row whose `checked`
  /// differs from [checked] in a single local write — one stream emit, so the
  /// whole list updates at once — records a purchase signal for each item that
  /// becomes checked, then queues one `updateItem` per row for the server.
  Future<void> setAllCheckedOfflineFirst(
    String listId, {
    required bool checked,
  }) async {
    final rows = await _db.getItemsByListOnce(listId);
    final targets = rows.where((r) => r.checked != checked).toList();
    if (targets.isEmpty) return;

    final now = DateTime.now();
    final patched = <ListItemsTableCompanion>[];
    for (final r in targets) {
      final existing = _toListItem(r);
      patched.add(_toListItemsRow(ListItem(
        id: existing.id,
        listId: existing.listId,
        name: existing.name,
        quantity: existing.quantity,
        unit: existing.unit,
        note: existing.note,
        checked: checked,
        position: existing.position,
        priceCents: existing.priceCents,
        canonicalItemId: existing.canonicalItemId,
        claimedBy: existing.claimedBy,
        createdAt: existing.createdAt,
        updatedAt: now,
      )));
    }
    await _db.upsertListItemsRows(patched);
    await _patchListPreviewFromLocalItems(listId);

    if (checked) {
      final notYetRecorded = targets.map((row) => row.id).toSet();
      for (final row in targets) {
        notYetRecorded.remove(row.id);
        await _recordPurchaseSignal(
          listId,
          row.id,
          row,
          excludedPeerItemIds: notYetRecorded,
        );
      }
    }
    for (final r in targets) {
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'updateItem',
        payload: {
          'listId': listId,
          'itemId': r.id,
          'patch': UpdateListItemRequest(checked: checked).toJson(),
        },
        idempotencyKey: 'updateItem:${r.id}:${now.toIso8601String()}',
        entityType: 'listItem',
        entityId: r.id,
      );
    }

    if (_autoSync) unawaited(drainOutboxOnce());
  }

  /// Offline-first clear. Deletes the matching rows locally in one write (one
  /// stream emit, so the list empties instantly) and queues a single
  /// `clearItems` op for the server, so it works offline and syncs when online.
  Future<void> clearItemsOfflineFirst(
    String listId, {
    required bool onlyChecked,
  }) async {
    final rows = await _db.getItemsByListOnce(listId);
    final targets =
        (onlyChecked ? rows.where((r) => r.checked) : rows).toList();
    if (targets.isEmpty) return;
    final ids = targets.map((r) => r.id).toList();

    await (_db.delete(_db.listItemsTable)..where((t) => t.id.isIn(ids))).go();
    await _patchListPreviewFromLocalItems(listId);

    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'clearItems',
      payload: {'listId': listId, 'onlyChecked': onlyChecked},
      idempotencyKey: 'clearItems:$listId:${DateTime.now().toIso8601String()}',
      entityType: 'list',
      entityId: listId,
    );

    if (_autoSync) unawaited(drainOutboxOnce());
  }

  Future<void> drainOutboxOnce() async {
    if (_isDraining) {
      _drainRequested = true;
      return;
    }
    _isDraining = true;
    try {
      do {
        _drainRequested = false;
        await _drainPass();
      } while (_drainRequested);
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _drainPass() async {
    // List CRUD drains in its own pass, BEFORE the advisory purchase
    // telemetry. The drainer stops a pass on the first transient failure
    // (to preserve per-entity ordering), so a recordPurchase op stuck on a
    // failing grocery endpoint used to sit at the head of the shared queue
    // and block every item add/update behind it for its whole retry cycle.
    await OutboxDrainer(_db).drain(
      types: const [
        'createItem',
        'updateItem',
        'deleteItem',
        'reorderItems',
        'addItemAmount',
        'clearItems',
      ],
      handlers: {
        'createItem': (op, payload) =>
            _syncCreateItem(op.id, payload, op.idempotencyKey),
        'updateItem': (op, payload) =>
            _syncUpdateItem(op.id, payload, op.idempotencyKey),
        'deleteItem': (op, payload) =>
            _syncDeleteItem(op.id, payload, op.idempotencyKey),
        'reorderItems': (op, payload) =>
            _syncReorderItems(op.id, payload, op.idempotencyKey),
        'addItemAmount': (op, payload) =>
            _syncAddItemAmount(op.id, payload, op.idempotencyKey),
        'clearItems': (op, payload) =>
            _syncClearItems(op.id, payload, op.idempotencyKey),
      },
    );
    await OutboxDrainer(_db).drain(
      types: const ['recordPurchase'],
      handlers: {
        'recordPurchase': (op, payload) =>
            _syncRecordPurchase(op.id, payload, op.idempotencyKey),
      },
    );
  }

  Future<void> _syncCreateItem(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
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
        priceCents: payload['priceCents'] as int?,
        canonicalItemId: payload['canonicalItemId'] as String?,
      ),
      idempotencyKey: idempotencyKey,
    );

    // Atomically replace the temp row and rewrite all queued payloads that
    // still reference the temp ID, so subsequent ops in the same drain pass
    // see the server ID when they re-read their payload from the DB.
    await _db.transaction(() async {
      await _db.replaceTempItemId(tempId: tempId, server: created);
      await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
    });
    await _db.deleteOutboxOp(opId);
    await _patchListPreviewFromLocalItems(listId);
  }

  Future<void> _syncAddItemAmount(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    final name = payload['name'] as String?;
    final amount = (payload['amount'] as num?)?.toDouble();
    if (listId == null || name == null || amount == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final result = await _remote.addItemAmount(
      listId,
      AddListItemAmountRequest(
        name: name,
        amount: amount,
        unit: payload['unit'] as String? ?? '',
        note: payload['note'] as String? ?? '',
      ),
      idempotencyKey: idempotencyKey,
    );

    final tempId = payload['tempId'] as String?;
    if (tempId != null) {
      // New-row case: swap the optimistic temp id for the server's, the same
      // way createItem reconciles, so later ops in this drain see the real id.
      await _db.transaction(() async {
        await _db.replaceTempItemId(tempId: tempId, server: result);
        await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: result.id);
      });
    }
    // Merge case (tempId == null): the local quantity was already bumped
    // optimistically against a real row, and the server applied the same
    // additive delta, so there is nothing to reconcile here. We deliberately
    // do NOT overwrite the local quantity with the server's value — a second
    // pending "+amount" for the same row would otherwise be clobbered until it
    // drains. SSE/refresh reconciles any cross-device divergence.
    await _db.deleteOutboxOp(opId);
    await _patchListPreviewFromLocalItems(listId);
  }

  Future<void> _syncUpdateItem(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
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
        priceCents: patch['price_cents'] as int? ?? patch['priceCents'] as int?,
        checked: patch['checked'] as bool?,
        position: patch['position'] as int?,
        expectedUpdatedAt: payload['expectedUpdatedAt'] as String?,
      ),
      idempotencyKey: idempotencyKey,
    );

    await _db.upsertListItemsRows([_toListItemsRow(updated)]);
    await _db.deleteOutboxOp(opId);
    await _patchListPreviewFromLocalItems(listId);
  }

  Future<void> _syncDeleteItem(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    final itemId = payload['itemId'] as String?;
    if (listId == null || itemId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    await _remote.deleteItem(listId, itemId, idempotencyKey: idempotencyKey);
    await _db.deleteOutboxOp(opId);
    await _patchListPreviewFromLocalItems(listId);
  }

  Future<void> _syncReorderItems(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    final rawIds = payload['itemIds'];
    if (listId == null || rawIds is! List) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    final itemIds = rawIds.map((e) => e.toString()).toList();
    await _remote.reorderItems(listId, ReorderItemsRequest(itemIds: itemIds),
        idempotencyKey: idempotencyKey);
    await _db.deleteOutboxOp(opId);
    await _patchListPreviewFromLocalItems(listId);
  }

  Future<void> _syncClearItems(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    if (listId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    final onlyChecked = payload['onlyChecked'] as bool? ?? false;
    await _remote.clearItems(listId,
        onlyChecked: onlyChecked, idempotencyKey: idempotencyKey);
    await _db.deleteOutboxOp(opId);
    await _patchListPreviewFromLocalItems(listId);
  }

  Future<void> _syncRecordPurchase(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final groupId = payload['groupId'] as String?;
    final rawEvents = payload['events'];
    if (groupId == null || rawEvents is! List) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    final events = rawEvents
        .whereType<Map>()
        .map((event) => event.cast<String, dynamic>())
        .toList(growable: false);
    await _remote.recordGroceryPurchases(groupId, events,
        idempotencyKey: idempotencyKey);
    await _db.deleteOutboxOp(opId);
  }

  // ---------------------------------------------------------------------------
  // Conflict resolution (edit conflicts: 409-with-server-state)
  // ---------------------------------------------------------------------------

  /// "Use theirs": overwrite the local row with the server's current state and
  /// mark the conflict resolved.
  Future<void> resolveConflictAcceptServer(Conflict conflict) async {
    try {
      final server = (jsonDecode(conflict.serverPayloadJson) as Map)
          .cast<String, dynamic>();
      final item = ListItem.fromJson(server);
      await _db.upsertListItemsRows([_toListItemsRow(item)]);
      await _patchListPreviewFromLocalItems(item.listId);
    } catch (_) {
      // If the server payload can't be parsed, still clear the conflict.
    }
    await _db.resolveConflict(conflict.id);
  }

  /// "Keep mine": re-apply the local edit on top of the server's version by
  /// re-enqueueing the op with the server's current updated_at as the base, so
  /// it no longer conflicts. Falls back gracefully for unknown op types.
  Future<void> resolveConflictKeepLocal(Conflict conflict) async {
    try {
      if (conflict.entityType == 'updateItem') {
        final local = (jsonDecode(conflict.localPayloadJson) as Map)
            .cast<String, dynamic>();
        final server = (jsonDecode(conflict.serverPayloadJson) as Map)
            .cast<String, dynamic>();
        local['expectedUpdatedAt'] = server['updated_at'];
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: 'updateItem',
          payload: local,
          entityType: 'listItem',
          entityId: local['itemId'] as String?,
        );
      }
    } catch (_) {
      // Best-effort; the conflict is cleared regardless so it doesn't linger.
    }
    await _db.resolveConflict(conflict.id);
    if (_autoSync) unawaited(drainOutboxOnce());
  }

  // ---------------------------------------------------------------------------
  // SSE real-time sync
  // ---------------------------------------------------------------------------

  /// Start receiving real-time updates for [groupId] via SSE.
  ///
  /// Events that mutate list items are applied directly to local SQLite,
  /// which causes the existing [watchItemsByList] Drift streams to fire.
  void attachSse(SseService sseService, String groupId) {
    if (_sseService == sseService && _sseGroupId == groupId) return;
    _sseService = sseService;
    sseService.connect(groupId);
    _listenSse(sseService.events, groupId);
  }

  /// Subscribes to [events] for [groupId] without touching a network-backed
  /// [SseService], so tests can drive the handler from a plain stream.
  @visibleForTesting
  void listenSseForTest(Stream<SseEvent> events, String groupId) =>
      _listenSse(events, groupId);

  void _listenSse(Stream<SseEvent> events, String groupId) {
    _sseSub?.cancel();
    _cancelSseRefreshTimers();
    _sseGroupId = groupId;
    _sseSub = events.listen(_handleSseEvent);
  }

  /// Stop the active SSE subscription without closing the service itself.
  void detachSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseService = null;
    _sseGroupId = null;
    _cancelSseRefreshTimers();
  }

  /// Events name the list and item by id only (the server publishes thin
  /// domain events; see `publishDomainEvent` in the backend), so the handler
  /// never trusts the body for content and refetches the list instead.
  Future<void> _handleSseEvent(SseEvent event) async {
    if (_sseGroupId == null || event.groupId != _sseGroupId) return;
    if (!event.type.startsWith('list:')) return;
    final itemId =
        event.payload['item_id'] as String? ?? event.payload['id'] as String?;
    final listId = event.payload['list_id'] as String? ??
        (itemId != null ? await _listIdForItem(itemId) : null);
    if (listId == null) return;
    switch (event.type) {
      case 'list:item_created':
      case 'list:item_updated':
      case 'list:item_claimed':
      case 'list:item_unclaimed':
      case 'list:items_cleared':
      case 'list:items_reordered':
        _scheduleItemsRefresh(listId);
      case 'list:item_deleted':
        // The delete itself is unambiguous, so apply it right away; the
        // refresh reconciles positions and anything else that moved.
        if (itemId != null) {
          await (_db.delete(_db.listItemsTable)
                ..where((t) => t.id.equals(itemId)))
              .go();
          await _patchListPreviewFromLocalItems(listId);
        }
        _scheduleItemsRefresh(listId);
    }
  }

  void _scheduleItemsRefresh(String listId) {
    _sseRefreshTimers[listId]?.cancel();
    _sseRefreshTimers[listId] =
        Timer(_sseRefreshCoalesce, () => _runItemsRefresh(listId));
  }

  Future<void> _runItemsRefresh(String listId) async {
    _sseRefreshTimers.remove(listId);
    if (_sseRefreshInFlight.contains(listId)) {
      _sseRefreshDirty.add(listId);
      return;
    }
    _sseRefreshInFlight.add(listId);
    try {
      await refreshItems(listId);
    } catch (_) {
      // Best effort: the next event or screen open reconciles.
    } finally {
      _sseRefreshInFlight.remove(listId);
    }
    if (_sseRefreshDirty.remove(listId)) {
      _scheduleItemsRefresh(listId);
    }
  }

  void _cancelSseRefreshTimers() {
    for (final timer in _sseRefreshTimers.values) {
      timer.cancel();
    }
    _sseRefreshTimers.clear();
    _sseRefreshDirty.clear();
  }

  /// Runs every coalesced SSE refresh now (including any queued behind an
  /// in-flight one) and returns once they have all completed.
  @visibleForTesting
  Future<void> flushPendingSseRefreshes() async {
    while (_sseRefreshTimers.isNotEmpty ||
        _sseRefreshInFlight.isNotEmpty ||
        _sseRefreshDirty.isNotEmpty) {
      final due = _sseRefreshTimers.keys.toList();
      for (final listId in due) {
        _sseRefreshTimers.remove(listId)?.cancel();
        _sseRefreshDirty.remove(listId);
        await _runItemsRefresh(listId);
      }
      if (due.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
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
      canonicalItemId: Value(item.canonicalItemId),
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
      canonicalItemId: row.canonicalItemId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ListItem _withCanonicalItemId(ListItem item, String? canonicalItemId) {
    return ListItem(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      note: item.note,
      priceCents: item.priceCents,
      canonicalItemId: canonicalItemId,
      checked: item.checked,
      position: item.position,
      claimedBy: item.claimedBy,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 6: purchase signal on item check-off
  // ---------------------------------------------------------------------------

  /// Records a purchase event and its durable sync intent when an item becomes
  /// checked. Errors remain non-critical to the list toggle, but callers await
  /// completion so a process exit cannot race the local transaction.
  Future<void> _recordPurchaseSignal(
    String listId,
    String itemId,
    ListItemsTableData row, {
    Set<String> excludedPeerItemIds = const {},
  }) =>
      _doPurchaseSignal(
        listId,
        itemId,
        row,
        excludedPeerItemIds: excludedPeerItemIds,
      );

  Future<void> _doPurchaseSignal(
    String listId,
    String itemId,
    ListItemsTableData row, {
    Set<String> excludedPeerItemIds = const {},
  }) async {
    try {
      final rawCanonicalId = row.canonicalItemId;

      final groupId = await _db.getListGroupId(listId);
      if (groupId == null) return;

      // Kept final (not a reassigned var) so it promotes to non-null inside the
      // nested transaction closure below.
      final String canonicalId;
      if (rawCanonicalId != null) {
        canonicalId = rawCanonicalId;
      } else {
        // The resolver couldn't map this word to a canonical item. Instead of
        // learning nothing, tally it; once the household has checked it off
        // enough times it's promoted to a household-local canonical so it can
        // finally surface in suggestions and feed the loop below.
        final promoted = await _promotionService.recordUnresolvedCheckoff(
          groupId: groupId,
          rawName: row.name,
        );
        if (promoted == null) return; // still below the promotion threshold
        canonicalId = promoted.canonicalItemId;
        // Bind the list item to the minted canonical so future check-offs take
        // the normal path and the purchase-history/co-occurrence rows below
        // record against it.
        await setCanonicalItemIdLocal(listId, itemId, canonicalId);
        final groceryRepo = _groceryRepo;
        if (promoted.justPromoted && groceryRepo != null) {
          // One-time cross-device push of the alias (the canonical itself syncs
          // via the recordPurchase op below). Best-effort; offline is swallowed.
          unawaited(groceryRepo.uploadCorrection(
            groupId: groupId,
            rawText: promoted.normalizedName,
            canonicalItemId: canonicalId,
          ));
        }
      }
      final peers = await _db.getCheckedItemsWithCanonical(listId);
      final peerCanonicalIds = peers
          .where((p) =>
              p.id != itemId &&
              !excludedPeerItemIds.contains(p.id) &&
              p.canonicalItemId != null)
          .map((p) => p.canonicalItemId!)
          .toSet()
          .toList();
      final canonicalItems = await _db.getCanonicalItemsByIds(
        {canonicalId, ...peerCanonicalIds}.toList(),
      );
      final byId = {for (final item in canonicalItems) item.id: item};
      final canonical = byId[canonicalId];
      if (canonical == null) return;
      Map<String, dynamic> stub(CanonicalItemsTableData item) => {
            'id': apiCanonicalId(item.id),
            'name_de': item.nameDe,
            'name_en': item.nameEn,
            'category': item.category,
            'default_unit': item.defaultUnit,
          };
      final eventId = _uuid.v4();
      final purchasedAt = DateTime.now();
      final event = <String, dynamic>{
        'id': eventId,
        'canonical_item': stub(canonical),
        'quantity': row.quantity,
        'unit': row.unit,
        'purchased_at': purchasedAt.toUtc().toIso8601String(),
        'peers': [
          for (final peerId in peerCanonicalIds)
            if (byId[peerId] case final peer?) stub(peer),
        ],
      };

      await _db.transaction(() async {
        await _db.insertPurchaseHistory(PurchaseHistoryTableCompanion.insert(
          id: eventId,
          groupId: groupId,
          canonicalItemId: Value(canonicalId),
          listItemId: Value(itemId),
          quantity: Value(row.quantity),
          unit: Value(row.unit),
          version: const Value(0),
          purchasedAt: purchasedAt,
        ));
        for (final peerId in peerCanonicalIds) {
          await _db.incrementCooccurrence(
            groupId: groupId,
            itemAId: canonicalId,
            itemBId: peerId,
          );
        }
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: 'recordPurchase',
          payload: {
            'groupId': groupId,
            'events': [event]
          },
          idempotencyKey: 'recordPurchase:$eventId',
          entityType: 'groceryPurchase',
          entityId: eventId,
        );
      });
      if (_autoSync) unawaited(drainOutboxOnce());
    } catch (error, stackTrace) {
      ErrorReporter().captureException(error, stackTrace: stackTrace);
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

  static const int _listCardPreviewLines = 4;

  Future<void> _hydrateMissingListPreviews(List<ItemList> lists) async {
    for (final list in lists) {
      if (list.itemPreview.isNotEmpty) continue;
      if (list.itemCount == 0) continue;

      try {
        final localRows = await _db.getItemsByListOnce(list.id);
        if (localRows.isNotEmpty) {
          await _patchListPreviewFromRows(list.id, localRows);
          continue;
        }

        final remoteItems = await _remote.listItems(
          list.id,
          limit: _listCardPreviewLines,
          offset: 0,
        );
        if (remoteItems.isEmpty) continue;

        await _db.upsertListItemsRows(remoteItems.map(_toListItemsRow));
        await _patchListPreviewFromItems(
          list.id,
          remoteItems,
          itemCount: list.itemCount,
        );
      } catch (_) {
        // Preview hydration is best-effort. The list itself has already loaded.
      }
    }
  }

  Future<void> _patchListPreviewFromLocalItems(String listId) async {
    final rows = await _db.getItemsByListOnce(listId);
    await _patchListPreviewFromRows(listId, rows);
  }

  Future<void> _patchListPreviewFromRows(
    String listId,
    List<ListItemsTableData> rows,
  ) async {
    final items = rows.map(_toListItem).toList();
    await _patchListPreviewFromItems(listId, items, itemCount: rows.length);
  }

  Future<void> _patchListPreviewFromItems(
    String listId,
    List<ListItem> items, {
    int? itemCount,
  }) async {
    final groupId = await _db.getListGroupId(listId);
    if (groupId == null) return;

    final lists = await _db.getListsByGroupOnce(groupId);
    ListsTableData? existing;
    for (final row in lists) {
      if (row.id == listId) {
        existing = row;
        break;
      }
    }
    if (existing == null) return;

    items.sort((a, b) {
      final byPos = a.position.compareTo(b.position);
      return byPos != 0 ? byPos : a.id.compareTo(b.id);
    });

    final preview = items
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .take(_listCardPreviewLines)
        .toList();

    await _db.upsertListsRows([
      ListsTableCompanion(
        id: Value(existing.id),
        groupId: Value(existing.groupId),
        name: Value(existing.name),
        type: Value(existing.type),
        itemCount: Value(itemCount ?? existing.itemCount),
        itemPreviewJson: Value(jsonEncode(preview)),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(existing.updatedAt),
      ),
    ]);
  }

  Future<String?> _listIdForItem(String itemId) async {
    final row = await (_db.select(_db.listItemsTable)
          ..where((t) => t.id.equals(itemId)))
        .getSingleOrNull();
    return row?.listId;
  }
}
