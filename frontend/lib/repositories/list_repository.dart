import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';

import '../models/list_models.dart';
import '../utils/uuid_validation.dart';
import '../services/api_error_mapper.dart';
import '../services/list_service.dart';
import '../services/error_reporter.dart';
import '../services/scan/local_item_promotion_service.dart';
import '../services/product_events.dart';
import '../services/response_cache_interceptor.dart';
import '../services/sse_service.dart';
import '../storage/app_database.dart';
import 'grocery_repository.dart';
import 'outbox_drainer.dart';

/// A list created on this device that the server has now accepted: [from] is
/// the temporary id it carried while it only existed locally, [to] the
/// server's. Screens still holding [from] (an open list detail, a route) move
/// over to [to].
typedef ListIdChange = ({String from, String to});

/// A row checked again within this window of its last purchase was unchecked
/// by mistake, not bought twice.
const Duration kPurchaseRecheckWindow = Duration(hours: 12);

/// Purchases this close together count as one shopping trip for "bought
/// together".
const Duration kSameTripWindow = Duration(hours: 3);

class ListRepository {
  final AppDatabase _db;
  final ListService _remote;
  final Uuid _uuid;
  final bool _autoSync;

  /// Production hook for the sync session: told when a write queued an op,
  /// instead of draining right away. See [_afterLocalWrite].
  final void Function()? _onLocalWrite;

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

  /// Lists whose whole item set has been fetched since this repository was
  /// created (opened, or refreshed by a live event). Others may only hold the
  /// preview lines `_hydrateMissingListPreviews` cached.
  final Set<String> _itemsFetched = {};
  final Set<String> _sseRefreshInFlight = {};
  final Set<String> _sseRefreshDirty = {};

  /// Prefix of the id a list created on this device carries until its
  /// `createList` op has synced. Never a valid server id, so nothing that
  /// holds one can be mistaken for a list the server knows.
  static const String localListIdPrefix = 'local-';

  /// True for a list created offline that the server does not have yet.
  static bool isLocalListId(String listId) =>
      listId.startsWith(localListIdPrefix);

  /// Server id of every list this repository saw sync, keyed by the temporary
  /// id it was created under. In memory on purpose: only live screens and
  /// in-flight calls can still hold a temp id, and none survive a restart.
  final Map<String, String> _syncedListIds = {};
  final StreamController<ListIdChange> _listIdChanges =
      StreamController<ListIdChange>.broadcast();

  /// Emits when a list created offline reaches the server and its rows move
  /// from the temporary id to the server's.
  Stream<ListIdChange> get listIdChanges => _listIdChanges.stream;

  /// The id [listId] is stored under now: the server id when it was a
  /// temporary id that has since synced, otherwise [listId] itself.
  String resolveListId(String listId) => _syncedListIds[listId] ?? listId;

  /// Op types whose payload targets one list through its `listId`. A list's
  /// own create orders ahead of all of them, and deleting the list drops them.
  static const List<String> _listScopedOpTypes = [
    'createItem',
    'updateItem',
    'deleteItem',
    'reorderItems',
    'addItemAmount',
    'clearItems',
    'updateList',
    'archiveList',
    'deleteList',
    'setListReminder',
  ];

  ListRepository({
    required AppDatabase db,
    required ListService remote,
    Uuid? uuid,
    bool autoSync = true,
    void Function()? onLocalWrite,
    LocalItemPromotionService? promotionService,
    GroceryRepository? groceryRepo,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _autoSync = autoSync,
        _onLocalWrite = onLocalWrite,
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
        .watchItemsByList(resolveListId(listId))
        .map((rows) => rows.map(_toListItem).toList());
  }

  Future<List<ListItem>> getItemsByListOnce(String listId) async {
    final rows = await _db.getItemsByListOnce(resolveListId(listId));
    return rows.map(_toListItem).toList();
  }

  /// The cached row of [listId], or null when it is not in the local cache.
  Future<ItemList?> getListOnce(String listId) async {
    final row = await (_db.select(_db.listsTable)
          ..where((t) => t.id.equals(resolveListId(listId))))
        .getSingleOrNull();
    return row == null ? null : _toItemList(row);
  }

  /// Same as [createListOfflineFirst]; kept for callers written against the
  /// old online-only name. The returned list may carry a temporary id.
  Future<ItemList> createList(CreateListRequest req) =>
      createListOfflineFirst(req);

  /// Creates a list locally under a temporary id (see [isLocalListId]) and
  /// queues its `createList` op in the same transaction, so it works offline:
  /// the caller can open it and add items right away. Item ops queued against
  /// the temporary id drain after the create (same drain pass, ordered by
  /// creation time) and are pointed at the server id once it exists; screens
  /// follow the switch through [listIdChanges].
  Future<ItemList> createListOfflineFirst(CreateListRequest req) async {
    final tempId = '$localListIdPrefix${_uuid.v4()}';
    final now = DateTime.now();
    final local = ItemList(
      id: tempId,
      groupId: req.groupId,
      name: req.name,
      type: req.type,
      itemCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _db.transaction(() async {
      await _db.upsertListsRows([_toListsRow(local)]);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'createList',
        payload: {
          'tempId': tempId,
          'groupId': req.groupId,
          'name': req.name,
          'type': req.type,
        },
        idempotencyKey: 'createList:$tempId',
        entityType: 'list',
        entityId: tempId,
      );
    });
    _afterLocalWrite();
    return local;
  }

  Future<int> refreshLists(String groupId,
      {int limit = 200, int offset = 0}) async {
    // Taken before the fetch: a create that syncs while it is in flight leaves
    // the outbox, and the server answer may predate it — its new server id
    // must not be pruned as "deleted elsewhere".
    final pendingCreates = (await _db.getOutboxOpsByType('createList'))
        .map((op) => op.entityId)
        .whereType<String>()
        .toList();
    // Live only: a cached (stale) answer must never be written over the
    // cache and pruned against; offline the refresh fails and the cache
    // stands.
    final remote = await ResponseCacheInterceptor.liveOnly(
        () => _remote.listLists(groupId, limit: limit, offset: offset));
    // Upsert first, never wipe-then-repopulate: a clear before the upsert made
    // the Drift watch stream emit an empty frame, flashing the whole lists
    // grid away on every refresh. Stale local rows (deleted on another device)
    // are pruned only when this page is the complete server set — with a full
    // page we can't tell "missing" from "on a later page".
    //
    // Queued list changes may not have drained yet (the sync session defers
    // them, and offline they wait for the network), so the server copy can
    // predate them: rows still carrying one are merged rather than
    // overwritten. A list deleted or archived here must not come back, and a
    // rename must not flip back to the server's old name.
    await _db.upsertListsRows(await _mergePendingListChanges(remote));
    if (offset == 0 && remote.length < limit) {
      // Lists created here and not yet on the server (or only just) are no
      // stale rows.
      await _db.deleteListsForGroupExcluding(
        groupId,
        {
          ...remote.map((l) => l.id),
          ...pendingCreates,
          ...pendingCreates.map(resolveListId),
        },
      );
    }
    unawaited(_hydrateMissingListPreviews(remote));
    return remote.length;
  }

  /// Server [lists] as cache rows, minus the ones with a queued delete or
  /// archive, and with a queued rename / type change kept as it is locally.
  Future<List<ListsTableCompanion>> _mergePendingListChanges(
    List<ItemList> lists,
  ) async {
    final pending = await (_db.select(_db.outboxOps)
          ..where((t) =>
              t.type.isIn(const ['updateList', 'archiveList', 'deleteList'])))
        .get();
    if (pending.isEmpty) return lists.map(_toListsRow).toList();
    final removed = <String>{};
    final edited = <String>{};
    for (final op in pending) {
      final listId = _decodePayload(op.payloadJson)?['listId'];
      if (listId is! String) continue;
      (op.type == 'updateList' ? edited : removed).add(listId);
    }
    final rows = <ListsTableCompanion>[];
    for (final list in lists) {
      if (removed.contains(list.id)) continue;
      var row = _toListsRow(list);
      if (edited.contains(list.id)) {
        final local = await (_db.select(_db.listsTable)
              ..where((t) => t.id.equals(list.id)))
            .getSingleOrNull();
        if (local != null) {
          row = row.copyWith(name: Value(local.name), type: Value(local.type));
        }
      }
      rows.add(row);
    }
    return rows;
  }

  /// Persists a rename into the local cache so screens watching the lists
  /// stream (the lists grid) reflect it immediately, whatever route the user
  /// takes back.
  Future<void> renameListLocal(String listId, String name) =>
      _db.updateListName(resolveListId(listId), name);

  Future<int> refreshItems(String listId,
      {int limit = 500, int offset = 0}) async {
    listId = resolveListId(listId);
    // Not on the server yet: the local rows are the whole list.
    if (isLocalListId(listId)) {
      return (await _db.getItemsByListOnce(listId)).length;
    }
    final remote = await ResponseCacheInterceptor.liveOnly(
        () => _remote.listItems(listId, limit: limit, offset: offset));
    if (offset == 0) {
      await _reconcileListItems(listId, remote);
      if (remote.length < limit) _itemsFetched.add(listId);
    } else {
      await _db.upsertListItemsRows(remote.map(_toListItemsRow));
    }
    await _patchListPreviewFromLocalItems(listId);
    return remote.length;
  }

  /// Fetches the items of every active list in [groupId] whose whole item set
  /// has not been fetched this session, so counts summed across lists (Home's
  /// "items left") are not limited to the preview lines a list nobody opened
  /// on this device has cached. Once per list per session; a failure is left
  /// for the next call.
  Future<void> fetchUnsyncedItems(String groupId) async {
    final lists = await getListsByGroupOnce(groupId);
    for (final list in lists) {
      if (list.isArchived ||
          isLocalListId(list.id) ||
          _itemsFetched.contains(list.id)) {
        continue;
      }
      try {
        await refreshItems(list.id);
      } catch (_) {
        // Offline or a transient failure: the cached preview stands.
      }
    }
  }

  Future<void> refreshListDetail(String listId) async {
    listId = resolveListId(listId);
    // Created offline and not synced yet: there is nothing to fetch.
    if (isLocalListId(listId)) return;
    final results = await ResponseCacheInterceptor.liveOnly(
      () => Future.wait<Object>([
        _remote.getList(listId),
        _remote.listItems(listId, limit: 500, offset: 0),
      ]),
    );
    final list = results[0] as ItemList;
    final items = results[1] as List<ListItem>;
    await _db.upsertListsRows(await _mergePendingListChanges([list]));
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
    // A queued clear or reorder of the whole list is not tied to any one item,
    // so the server copy (or, offline, the cached copy of it) still shows the
    // rows the clear removed and the order before the reorder. Hold both back
    // until the op has synced, or a refresh would undo them on screen.
    final listOps = await (_db.select(_db.outboxOps)
          ..where((t) =>
              t.entityType.equals('list') &
              t.entityId.equals(listId) &
              t.type.isIn(const ['clearItems', 'reorderItems'])))
        .get();
    var clearsAll = false;
    var clearsChecked = false;
    var reorders = false;
    for (final op in listOps) {
      if (op.type == 'reorderItems') {
        reorders = true;
      } else if (_decodePayload(op.payloadJson)?['onlyChecked'] == true) {
        clearsChecked = true;
      } else {
        clearsAll = true;
      }
    }
    final localPositions = {
      if (reorders)
        for (final row in beforeRefresh) row.id: row.position,
    };
    // A row with an unsynced local edit (or delete) keeps its optimistic state:
    // the server still holds the pre-edit value, and the op's own sync writes
    // the server's answer back. Overwriting it here would flash the old value
    // (or resurrect a deleted row) every time an SSE event lands mid-sync.
    await _db.upsertListItemsRows(enrichedServerItems
        .where((item) => !pendingIds.contains(item.id))
        .where((item) => !(clearsAll || (clearsChecked && item.checked)))
        .map((item) => switch (localPositions[item.id]) {
              final position? when position != item.position =>
                _withPosition(item, position),
              _ => item,
            })
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
              claimedBy: item.claimedBy,
              addedBy: item.addedBy,
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

  Future<String?> getGroupId(String listId) =>
      _db.getListGroupId(resolveListId(listId));

  Future<String?> getListType(String listId) =>
      _db.getListType(resolveListId(listId));

  // ---------------------------------------------------------------------------
  // Offline-first writes (optimistic local + outbox)
  // ---------------------------------------------------------------------------

  Future<ListItem> createItemOfflineFirst(
    String listId,
    CreateListItemRequest req, {
    bool deferImmediateSync = false,
    String? addedBy,
  }) async {
    listId = resolveListId(listId);
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
      addedBy: addedBy,
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
    if (!deferImmediateSync) _afterLocalWrite();
    unawaited(_noteFirstItem(listId));
    return local;
  }

  /// Product events (plans/048 stage 8): the first item added in a household
  /// created or joined on this install. Runs after the write's transaction.
  Future<void> _noteFirstItem(String listId) async {
    final events = ProductEvents.instance;
    if (!events.isEnabled) return;
    try {
      await events.noteItemAdded(await _db.getListGroupId(listId), 'list_item');
    } catch (_) {}
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
    String? addedBy,
  }) async {
    listId = resolveListId(listId);
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
        addedBy: existing.addedBy,
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
        addedBy: addedBy,
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

    if (!deferImmediateSync) _afterLocalWrite();
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
    listId = resolveListId(listId);
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
    _afterLocalWrite();
  }

  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    listId = resolveListId(listId);
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
      claimedBy: existing.claimedBy,
      addedBy: existing.addedBy,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await _db.transaction(() async {
      await _db.upsertListItemsRows([_toListItemsRow(patched)]);
      await _patchListPreviewFromLocalItems(listId);

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

    // Purchase telemetry for a check-off runs after the edit has committed.
    // It writes in a transaction of its own and fires best-effort network
    // work; inside the edit's transaction that work outlived the transaction
    // and every later local write failed as "used after being closed".
    if ((req.checked ?? false) && !existing.checked) {
      await _recordPurchaseSignal(listId, itemId, existingRow);
    }

    _afterLocalWrite();
    return patched;
  }

  // ---------------------------------------------------------------------------
  // Changes made outside the app: home screen widgets, Siri, quick add
  // (plans/047). The native side already queued the request, and the app
  // replays it as a `widgetRequest` outbox op, so these only touch the cache.
  // ---------------------------------------------------------------------------

  /// Shows [itemId] as checked in the local cache. No-op when it is not
  /// cached (a household the app has not opened yet).
  Future<void> applyExternalCheck(String listId, String itemId) async {
    final rows = await _db.getItemsByListOnce(listId);
    final row = rows.firstWhereOrNull((r) => r.id == itemId);
    if (row == null || row.checked) return;
    final item = _toListItem(row);
    await _db.upsertListItemsRows([
      _toListItemsRow(ListItem(
        id: item.id,
        listId: item.listId,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        note: item.note,
        checked: true,
        position: item.position,
        priceCents: item.priceCents,
        canonicalItemId: item.canonicalItemId,
        claimedBy: item.claimedBy,
        addedBy: item.addedBy,
        createdAt: item.createdAt,
        updatedAt: DateTime.now(),
      )),
    ]);
    await _patchListPreviewFromLocalItems(listId);
    // A check-off from the widget is a purchase like one in the app.
    await _recordPurchaseSignal(listId, itemId, row);
  }

  /// Records the purchase for a check-off the widget already delivered to the
  /// server itself. A no-op when the row is not cached, and a repeat within
  /// [kPurchaseRecheckWindow] counts once.
  Future<void> recordExternalPurchase(String listId, String itemId) async {
    final rows = await _db.getItemsByListOnce(listId);
    final row = rows.firstWhereOrNull((r) => r.id == itemId);
    if (row == null) return;
    await _recordPurchaseSignal(listId, itemId, row);
  }

  /// Shows an item added outside the app under [tempId] (the native op id)
  /// until its request syncs and [applyServerItem] swaps in the server row.
  /// No-op when the list is not cached.
  Future<void> applyExternalAdd(
    String listId, {
    required String tempId,
    required String name,
  }) async {
    if (await _db.getListGroupId(listId) == null) return;
    final rows = await _db.getItemsByListOnce(listId);
    if (rows.any((r) => r.id == tempId)) return;
    var maxPos = -1;
    for (final r in rows) {
      if (r.position > maxPos) maxPos = r.position;
    }
    final now = DateTime.now();
    await _db.upsertListItemsRows([
      _toListItemsRow(ListItem(
        id: tempId,
        listId: listId,
        name: name,
        quantity: 1,
        unit: '',
        note: '',
        checked: false,
        position: maxPos + 1,
        createdAt: now,
        updatedAt: now,
      )),
    ]);
    await _patchListPreviewFromLocalItems(listId);
  }

  /// Stores an item as the server returned it. With [tempId], replaces that
  /// optimistic row and points queued ops at the server id.
  Future<void> applyServerItem(ListItem server, {String? tempId}) async {
    if (tempId != null && tempId != server.id) {
      await _db.transaction(() async {
        await _db.replaceTempItemId(tempId: tempId, server: server);
        await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: server.id);
      });
    } else {
      await _db.upsertListItemsRows([_toListItemsRow(server)]);
    }
    await _patchListPreviewFromLocalItems(server.listId);
  }

  /// Drops the optimistic row of an outside add the server refused.
  Future<void> discardExternalAdd(String listId, String tempId) async {
    await _db.deleteListItemsByIds([tempId]);
    await _patchListPreviewFromLocalItems(listId);
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
    listId = resolveListId(listId);
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
            addedBy: existing.addedBy,
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

    _afterLocalWrite();
  }

  Future<void> deleteItemOfflineFirst(String listId, String itemId) async {
    listId = resolveListId(listId);
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

    _afterLocalWrite();
  }

  /// Offline-first bulk check / uncheck. Flips every row whose `checked`
  /// differs from [checked] in a single local write — one stream emit, so the
  /// whole list updates at once — records a purchase signal for each item that
  /// becomes checked, then queues one `updateItem` per row for the server.
  Future<void> setAllCheckedOfflineFirst(
    String listId, {
    required bool checked,
  }) async {
    listId = resolveListId(listId);
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
        addedBy: existing.addedBy,
        createdAt: existing.createdAt,
        updatedAt: now,
      )));
    }
    // The rows and their sync intents are one atomic change, as for a single
    // edit: a process death between them must not leave checks the server
    // never hears about.
    await _db.transaction(() async {
      await _db.upsertListItemsRows(patched);
      await _patchListPreviewFromLocalItems(listId);
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
    });

    // Purchase telemetry runs after the commit, for the reason given in
    // [updateItemOfflineFirst].
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

    _afterLocalWrite();
  }

  /// Offline-first clear. Deletes the matching rows locally in one write (one
  /// stream emit, so the list empties instantly) and queues a single
  /// `clearItems` op for the server, so it works offline and syncs when online.
  Future<void> clearItemsOfflineFirst(
    String listId, {
    required bool onlyChecked,
  }) async {
    listId = resolveListId(listId);
    final rows = await _db.getItemsByListOnce(listId);
    final targets =
        (onlyChecked ? rows.where((r) => r.checked) : rows).toList();
    if (targets.isEmpty) return;
    final ids = targets.map((r) => r.id).toList();

    await _db.transaction(() async {
      await (_db.delete(_db.listItemsTable)..where((t) => t.id.isIn(ids))).go();
      await _patchListPreviewFromLocalItems(listId);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'clearItems',
        payload: {'listId': listId, 'onlyChecked': onlyChecked},
        idempotencyKey:
            'clearItems:$listId:${DateTime.now().toIso8601String()}',
        entityType: 'list',
        entityId: listId,
      );
    });

    _afterLocalWrite();
  }

  // ---------------------------------------------------------------------------
  // Offline-first list writes
  // ---------------------------------------------------------------------------

  /// Renames and/or retypes a list. The cache changes at once and the change
  /// is queued as an `updateList` op. A list that has not reached the server
  /// yet has its queued create rewritten instead, so it is created under the
  /// new name rather than created and then renamed.
  Future<void> updateListOfflineFirst(
    String listId,
    UpdateListRequest req,
  ) async {
    listId = resolveListId(listId);
    final patch = req.toJson();
    if (patch.isEmpty) return;
    var queued = false;
    await _db.transaction(() async {
      await (_db.update(_db.listsTable)..where((t) => t.id.equals(listId)))
          .write(ListsTableCompanion(
        name: req.name == null ? const Value.absent() : Value(req.name!),
        type: req.type == null ? const Value.absent() : Value(req.type!),
      ));

      final create = await _queuedCreateList(listId);
      if (create != null) {
        final payload = _decodePayload(create.payloadJson) ?? {};
        payload.addAll(patch);
        await _writeOutboxPayload(create.id, payload);
        return;
      }

      // Fold an edit that has not been sent yet into this one, so a burst of
      // renames syncs as the last name instead of every intermediate one.
      final earlier = (await _db.getOutboxOpsByType('updateList'))
          .where((op) => op.entityId == listId)
          .toList();
      final merged = <String, dynamic>{};
      for (final op in earlier) {
        final previous = _decodePayload(op.payloadJson)?['patch'];
        if (previous is Map) merged.addAll(previous.cast<String, dynamic>());
        await _db.deleteOutboxOp(op.id);
      }
      merged.addAll(patch);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'updateList',
        payload: {'listId': listId, 'name': req.name, 'patch': merged},
        idempotencyKey:
            'updateList:$listId:${DateTime.now().toIso8601String()}',
        entityType: 'list',
        entityId: listId,
      );
      queued = true;
    });
    if (queued) _afterLocalWrite();
  }

  /// Archives a list: it leaves the cache at once (the server stops listing
  /// archived lists) and an `archiveList` op is queued. Its items stay cached
  /// so their own queued ops still sync. Archiving a list that has not reached
  /// the server yet queues behind its create.
  Future<void> archiveListOfflineFirst(String listId) async {
    listId = resolveListId(listId);
    await _db.transaction(() async {
      await (_db.delete(_db.listsTable)..where((t) => t.id.equals(listId)))
          .go();
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'archiveList',
        payload: {'listId': listId},
        idempotencyKey:
            'archiveList:$listId:${DateTime.now().toIso8601String()}',
        entityType: 'list',
        entityId: listId,
      );
    });
    _afterLocalWrite();
  }

  /// Deletes a list and its items locally and queues a `deleteList` op. Every
  /// op still queued for the list is dropped with it: the server would only
  /// answer them with a 404. A list that never reached the server needs no
  /// request at all — dropping its queued create is the whole delete.
  Future<void> deleteListOfflineFirst(String listId) async {
    listId = resolveListId(listId);
    final local = isLocalListId(listId);
    await _db.transaction(() async {
      await (_db.delete(_db.listsTable)..where((t) => t.id.equals(listId)))
          .go();
      await _db.deleteItemsForList(listId);
      for (final op in await _queuedOpsForList(listId)) {
        await _db.deleteOutboxOp(op.id);
      }
      if (local) return;
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'deleteList',
        payload: {'listId': listId},
        idempotencyKey: 'deleteList:$listId',
        entityType: 'list',
        entityId: listId,
      );
    });
    _itemsFetched.remove(listId);
    if (!local) _afterLocalWrite();
  }

  /// Schedules (or clears, with null) the list's household reminder through
  /// the outbox. Only the newest queued value is kept. The reminder is not a
  /// cached column, so screens read a queued value back with
  /// [queuedListReminder] until the server has it.
  Future<void> setListReminderOfflineFirst(
    String listId,
    DateTime? remindAt,
  ) async {
    listId = resolveListId(listId);
    await _db.transaction(() async {
      for (final op in await _db.getOutboxOpsByType('setListReminder')) {
        if (_decodePayload(op.payloadJson)?['listId'] == listId) {
          await _db.deleteOutboxOp(op.id);
        }
      }
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: 'setListReminder',
        payload: {
          'listId': listId,
          'remindAt': remindAt?.toUtc().toIso8601String(),
        },
        idempotencyKey:
            'setListReminder:$listId:${DateTime.now().toIso8601String()}',
        entityType: 'list',
        entityId: listId,
      );
    });
    _afterLocalWrite();
  }

  /// The reminder value queued for [listId] and not yet synced, or null when
  /// none is queued. A queued clear comes back as `(remindAt: null)`.
  Future<({DateTime? remindAt})?> queuedListReminder(String listId) async {
    listId = resolveListId(listId);
    final ops = await _db.getOutboxOpsByType('setListReminder');
    for (final op in ops.reversed) {
      final payload = _decodePayload(op.payloadJson);
      if (payload?['listId'] != listId) continue;
      final raw = payload?['remindAt'];
      return (
        remindAt: raw is String ? DateTime.tryParse(raw)?.toLocal() : null,
      );
    }
    return null;
  }

  /// Checks off items from several lists at once (the shopping trip's "done"),
  /// through the same offline-first edit as a single check-off.
  Future<void> completeItemsOfflineFirst(
    Map<String, List<String>> itemIdsByList,
  ) async {
    for (final entry in itemIdsByList.entries) {
      final listId = resolveListId(entry.key);
      final cached = {
        for (final row in await _db.getItemsByListOnce(listId)) row.id: row,
      };
      for (final itemId in entry.value) {
        final row = cached[itemId];
        if (row == null || row.checked) continue;
        await updateItemOfflineFirst(
          listId,
          itemId,
          const UpdateListItemRequest(checked: true),
        );
      }
    }
  }

  /// Refreshes the items of [listIds] with one request (the shopping trip's
  /// aggregate endpoint) and reconciles each list into the cache, so the trip
  /// can be read back from the cache offline. Lists not on the server yet are
  /// skipped; their cached rows are already complete.
  Future<void> refreshShoppingTrip(String groupId, List<String> listIds) async {
    final serverIds = listIds
        .map(resolveListId)
        .where((id) => !isLocalListId(id))
        .toList(growable: false);
    if (serverIds.isEmpty) return;
    final result = await ResponseCacheInterceptor.liveOnly(
        () => _remote.getShoppingTrip(serverIds, groupId: groupId));
    final rawLists = result['lists'];
    if (rawLists is! List) return;
    for (final raw in rawLists.whereType<Map>()) {
      final listId = raw['list_id'];
      final rawItems = raw['items'];
      if (listId is! String || !serverIds.contains(listId)) continue;
      final items = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => ListItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : <ListItem>[];
      await _reconcileListItems(listId, items);
      _itemsFetched.add(listId);
      await _patchListPreviewFromLocalItems(listId);
    }
  }

  // ---------------------------------------------------------------------------
  // Products and shopping locations (household catalog)
  // ---------------------------------------------------------------------------

  /// Queues a product for the household catalog and returns it under a
  /// temporary id. The catalog is not a cached table; screens merge
  /// [queuedProducts] into what the server (or its cached response) lists.
  Future<Product> createProductOfflineFirst(CreateProductRequest req) async {
    final tempId = '$localListIdPrefix${_uuid.v4()}';
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createProduct',
      payload: {'tempId': tempId, 'name': req.name, 'request': req.toJson()},
      idempotencyKey: 'createProduct:$tempId',
      entityType: 'product',
      entityId: tempId,
    );
    _afterLocalWrite();
    return Product(
      id: tempId,
      groupId: req.groupId,
      name: req.name,
      barcode: req.barcode,
      unit: req.unit,
      storeId: req.storeId,
      minStock: req.minStock,
      inStock: req.inStock,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Products of [groupId] still waiting in the outbox, oldest first.
  Future<List<Product>> queuedProducts(String groupId) async {
    final products = <Product>[];
    for (final op in await _db.getOutboxOpsByType('createProduct')) {
      final payload = _decodePayload(op.payloadJson);
      final request = payload?['request'];
      if (request is! Map || request['group_id'] != groupId) continue;
      products.add(Product(
        id: payload?['tempId'] as String? ?? op.id,
        groupId: groupId,
        name: request['name'] as String? ?? '',
        barcode: request['barcode'] as String? ?? '',
        unit: request['unit'] as String? ?? '',
        createdAt: op.createdAt,
        updatedAt: op.createdAt,
      ));
    }
    return products;
  }

  /// Queues a shopping location; see [createProductOfflineFirst].
  Future<ShoppingLocation> createShoppingLocationOfflineFirst(
    CreateShoppingLocationRequest req,
  ) async {
    final tempId = '$localListIdPrefix${_uuid.v4()}';
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: 'createShoppingLocation',
      payload: {'tempId': tempId, 'name': req.name, 'request': req.toJson()},
      idempotencyKey: 'createShoppingLocation:$tempId',
      entityType: 'shoppingLocation',
      entityId: tempId,
    );
    _afterLocalWrite();
    return ShoppingLocation(
      id: tempId,
      groupId: req.groupId,
      name: req.name,
      sortOrder: req.sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Shopping locations of [groupId] still waiting in the outbox.
  Future<List<ShoppingLocation>> queuedShoppingLocations(
    String groupId,
  ) async {
    final locations = <ShoppingLocation>[];
    for (final op in await _db.getOutboxOpsByType('createShoppingLocation')) {
      final payload = _decodePayload(op.payloadJson);
      final request = payload?['request'];
      if (request is! Map || request['group_id'] != groupId) continue;
      locations.add(ShoppingLocation(
        id: payload?['tempId'] as String? ?? op.id,
        groupId: groupId,
        name: request['name'] as String? ?? '',
        sortOrder: (request['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: op.createdAt,
        updatedAt: op.createdAt,
      ));
    }
    return locations;
  }

  // ---------------------------------------------------------------------------
  // Outbox helpers for list ops
  // ---------------------------------------------------------------------------

  /// The queued (or dead-lettered) create of [listId], if it has one.
  Future<OutboxOp?> _queuedCreateList(String listId) async {
    if (!isLocalListId(listId)) return null;
    return (_db.select(_db.outboxOps)
          ..where(
              (t) => t.type.equals('createList') & t.entityId.equals(listId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Every queued op that targets [listId]: its create and all list-scoped
  /// ops whose payload names it.
  Future<List<OutboxOp>> _queuedOpsForList(String listId) async {
    final ops = await (_db.select(_db.outboxOps)
          ..where(
              (t) => t.type.isIn(const ['createList', ..._listScopedOpTypes])))
        .get();
    return ops.where((op) {
      if (op.entityId == listId) return true;
      final payload = _decodePayload(op.payloadJson);
      return payload?['listId'] == listId || payload?['tempId'] == listId;
    }).toList();
  }

  Future<void> _writeOutboxPayload(
    String opId,
    Map<String, dynamic> payload,
  ) async {
    await (_db.update(_db.outboxOps)..where((t) => t.id.equals(opId)))
        .write(OutboxOpsCompanion(payloadJson: Value(jsonEncode(payload))));
  }

  /// Points queued ops' `entity_id` from a temporary id at the server id.
  /// [AppDatabase.rewriteOutboxPayloadIds] only rewrites payloads, and the
  /// entity id is what "is this row still pending?" lookups key on.
  Future<void> _rewriteOutboxEntityIds(String oldId, String newId) async {
    await (_db.update(_db.outboxOps)..where((t) => t.entityId.equals(oldId)))
        .write(OutboxOpsCompanion(entityId: Value(newId)));
  }

  /// Called after a write has queued an op (always after its transaction).
  /// Production passes [_onLocalWrite], which only opens the sync session;
  /// without it (tests, direct constructions) the op drains right away.
  void _afterLocalWrite() {
    if (!_autoSync) return;
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce());
    }
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
    //
    // A list created offline drains in the same pass as its items: the batch
    // is ordered by creation time, so `createList` always runs before the
    // item ops queued against its temporary id, and its sync rewrites their
    // payloads to the server id before the drainer re-reads them. Ops whose
    // list is still waiting (its create backed off or dead-lettered) are
    // parked by [_afterListSynced] instead of being sent to a list the server
    // does not have.
    await OutboxDrainer(_db).drain(
      types: const [
        'createList',
        ..._listScopedOpTypes,
        'createProduct',
        'createShoppingLocation',
      ],
      handlers: {
        'createList': (op, payload) =>
            _syncCreateList(op.id, payload, op.idempotencyKey),
        'createItem': _afterListSynced((op, payload) =>
            _syncCreateItem(op.id, payload, op.idempotencyKey)),
        'updateItem': _afterListSynced((op, payload) =>
            _syncUpdateItem(op.id, payload, op.idempotencyKey)),
        'deleteItem': _afterListSynced((op, payload) =>
            _syncDeleteItem(op.id, payload, op.idempotencyKey)),
        'reorderItems': _afterListSynced((op, payload) =>
            _syncReorderItems(op.id, payload, op.idempotencyKey)),
        'addItemAmount': _afterListSynced((op, payload) =>
            _syncAddItemAmount(op.id, payload, op.idempotencyKey)),
        'clearItems': _afterListSynced((op, payload) =>
            _syncClearItems(op.id, payload, op.idempotencyKey)),
        'updateList': _afterListSynced((op, payload) =>
            _syncUpdateList(op.id, payload, op.idempotencyKey)),
        'archiveList': _afterListSynced((op, payload) =>
            _syncArchiveList(op.id, payload, op.idempotencyKey)),
        'deleteList': _afterListSynced((op, payload) =>
            _syncDeleteList(op.id, payload, op.idempotencyKey)),
        'setListReminder': _afterListSynced((op, payload) =>
            _syncSetListReminder(op.id, payload, op.idempotencyKey)),
        'createProduct': (op, payload) =>
            _syncCreateProduct(op.id, payload, op.idempotencyKey),
        'createShoppingLocation': (op, payload) =>
            _syncCreateShoppingLocation(op.id, payload, op.idempotencyKey),
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

  /// Wraps the handler of an op that names a list in its payload so it is
  /// never sent while that list only exists on this device.
  ///
  /// * Its list synced earlier (a screen queued the op against the temporary
  ///   id after the switch): the op is pointed at the server id and sent.
  /// * Its list's create is still queued (backing off, or dead-lettered): the
  ///   op is left untouched and the pass moves on. It costs no attempt and
  ///   drains right behind the create once that goes through.
  /// * Its list's create is gone (discarded from the failed-changes sheet):
  ///   nothing can ever carry the op to the server, so it is dropped.
  OutboxOpHandler _afterListSynced(OutboxOpHandler handler) {
    return (op, payload) async {
      final listId = payload['listId'];
      if (listId is! String || !isLocalListId(listId)) {
        return handler(op, payload);
      }
      final serverId = _syncedListIds[listId];
      if (serverId != null) {
        await _db.rewriteOutboxPayloadIds(oldId: listId, newId: serverId);
        await _rewriteOutboxEntityIds(listId, serverId);
        return handler(op, {...payload, 'listId': serverId});
      }
      if (await _queuedCreateList(listId) == null) {
        await _db.deleteOutboxOp(op.id);
      }
    };
  }

  /// Sends a list created offline and moves everything local onto the server
  /// id in one transaction: the list row, its items, and every queued op that
  /// names the temporary id (payload and entity id). The ops behind it in the
  /// same drain pass then re-read their payload and target the server list.
  Future<void> _syncCreateList(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final tempId = payload['tempId'] as String?;
    final groupId = payload['groupId'] as String?;
    final name = payload['name'] as String?;
    if (tempId == null || groupId == null || name == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }

    final created = await _remote.createList(
      CreateListRequest(
        groupId: groupId,
        name: name,
        type: payload['type'] as String? ?? 'shopping',
      ),
      idempotencyKey: idempotencyKey,
    );

    await _db.transaction(() async {
      // Gone means the user deleted the list while this request was in
      // flight; deleting it took the op and every op behind it along.
      final stillQueued = await _db.getOutboxOpById(opId) != null;
      final local = await (_db.select(_db.listsTable)
            ..where((t) => t.id.equals(tempId)))
          .getSingleOrNull();
      await (_db.delete(_db.listsTable)..where((t) => t.id.equals(tempId)))
          .go();
      // No local row (but the op still queued) means the list was archived
      // before it synced: the queued archive follows, so don't show it again.
      if (local != null) {
        await _db.upsertListsRows([
          ListsTableCompanion(
            id: Value(created.id),
            groupId: Value(created.groupId),
            name: Value(local.name),
            type: Value(local.type),
            itemCount: Value(local.itemCount),
            itemPreviewJson: Value(local.itemPreviewJson),
            createdAt: Value(created.createdAt),
            updatedAt: Value(created.updatedAt),
          ),
        ]);
      }
      await (_db.update(_db.listItemsTable)
            ..where((t) => t.listId.equals(tempId)))
          .write(ListItemsTableCompanion(listId: Value(created.id)));
      await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
      await _rewriteOutboxEntityIds(tempId, created.id);
      await _db.deleteOutboxOp(opId);

      if (!stillQueued) {
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: 'deleteList',
          payload: {'listId': created.id},
          idempotencyKey: 'deleteList:${created.id}',
          entityType: 'list',
          entityId: created.id,
        );
      } else if (local != null &&
          (local.name != created.name || local.type != created.type)) {
        // Renamed while the create was in flight, too late to rewrite it.
        await _db.enqueueOutbox(
          id: _uuid.v4(),
          type: 'updateList',
          payload: {
            'listId': created.id,
            'name': local.name,
            'patch': {'name': local.name, 'type': local.type},
          },
          idempotencyKey:
              'updateList:${created.id}:${DateTime.now().toIso8601String()}',
          entityType: 'list',
          entityId: created.id,
        );
      }
    });

    _syncedListIds[tempId] = created.id;
    if (_itemsFetched.remove(tempId)) _itemsFetched.add(created.id);
    if (!_listIdChanges.isClosed) {
      _listIdChanges.add((from: tempId, to: created.id));
    }
    // The pass that ran this fetched its batch before any op enqueued above.
    _drainRequested = true;
    await _patchListPreviewFromLocalItems(created.id);
  }

  Future<void> _syncUpdateList(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    final patch = payload['patch'];
    if (listId == null || patch is! Map) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    // The cache already shows the edit; the response only confirms it.
    await _remote.updateList(
      listId,
      UpdateListRequest(
        name: patch['name'] as String?,
        type: patch['type'] as String?,
      ),
      idempotencyKey: idempotencyKey,
    );
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncArchiveList(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    if (listId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _remote.archiveList(listId, idempotencyKey: idempotencyKey);
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncDeleteList(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    if (listId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    try {
      await _remote.deleteList(listId, idempotencyKey: idempotencyKey);
    } catch (e) {
      // Already gone (deleted on another device): that is what we wanted.
      if (!_isNotFound(e)) rethrow;
    }
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncSetListReminder(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final listId = payload['listId'] as String?;
    if (listId == null) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    final raw = payload['remindAt'];
    await _remote.setListReminder(
      listId,
      raw is String ? DateTime.tryParse(raw) : null,
      idempotencyKey: idempotencyKey,
    );
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncCreateProduct(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final request = payload['request'];
    if (request is! Map ||
        request['group_id'] is! String ||
        request['name'] is! String) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _remote.createProduct(
      CreateProductRequest(
        groupId: request['group_id'] as String,
        name: request['name'] as String,
        barcode: request['barcode'] as String? ?? '',
        unit: request['unit'] as String? ?? '',
        storeId: request['store_id'] as String?,
        minStock: (request['min_stock'] as num?)?.toDouble() ?? 0,
        inStock: (request['in_stock'] as num?)?.toDouble() ?? 0,
      ),
      idempotencyKey: idempotencyKey,
    );
    await _db.deleteOutboxOp(opId);
  }

  Future<void> _syncCreateShoppingLocation(
      String opId, Map<String, dynamic> payload, String? idempotencyKey) async {
    final request = payload['request'];
    if (request is! Map ||
        request['group_id'] is! String ||
        request['name'] is! String) {
      await _db.deleteOutboxOp(opId);
      return;
    }
    await _remote.createShoppingLocation(
      CreateShoppingLocationRequest(
        groupId: request['group_id'] as String,
        name: request['name'] as String,
        sortOrder: (request['sort_order'] as num?)?.toInt() ?? 0,
      ),
      idempotencyKey: idempotencyKey,
    );
    await _db.deleteOutboxOp(opId);
  }

  static bool _isNotFound(Object error) {
    final cause = error is ApiException ? error.cause : error;
    return cause is DioException && cause.response?.statusCode == 404;
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
    await _db.transaction(() => _adoptServerItemId(tempId, created));
    await _db.deleteOutboxOp(opId);
    await _patchListPreviewFromLocalItems(created.listId);
  }

  /// Swaps the optimistic row [tempId] for [server] and points queued ops at
  /// the server id. A row the user removed while its create was queued (a
  /// delete, a clear) is not brought back: the op that removed it is queued
  /// too, now aimed at the server id, and the server copy goes with it.
  Future<void> _adoptServerItemId(String tempId, ListItem server) async {
    final stillShown = await (_db.select(_db.listItemsTable)
              ..where((t) => t.id.equals(tempId)))
            .getSingleOrNull() !=
        null;
    if (stillShown) {
      await _db.replaceTempItemId(tempId: tempId, server: server);
    }
    await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: server.id);
    await _rewriteOutboxEntityIds(tempId, server.id);
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
      await _db.transaction(() => _adoptServerItemId(tempId, result));
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
    _afterLocalWrite();
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

  /// Releases the repository's own resources (the [listIdChanges] stream).
  void dispose() {
    unawaited(_listIdChanges.close());
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
      addedBy: Value(item.addedBy),
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
      addedBy: row.addedBy,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ListItem _withPosition(ListItem item, int position) {
    return ListItem(
      id: item.id,
      listId: item.listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      note: item.note,
      priceCents: item.priceCents,
      canonicalItemId: item.canonicalItemId,
      checked: item.checked,
      position: position,
      claimedBy: item.claimedBy,
      addedBy: item.addedBy,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  static Map<String, dynamic>? _decodePayload(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // A malformed payload is the drainer's to drop; treat it as empty here.
    }
    return null;
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
      addedBy: item.addedBy,
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

      final purchasedAt = DateTime.now();
      if (await _db.hasPurchaseForListItemSince(
        listItemId: itemId,
        since: purchasedAt.subtract(kPurchaseRecheckWindow),
      )) {
        // Unchecked by mistake and checked again: the purchase already counts.
        return;
      }

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
      // "Bought together" means bought on the same trip, not "ticked on this
      // list at some point": a reused list keeps rows checked weeks ago.
      final tripPurchases = await _db.getGroupPurchasesSince(
        groupId: groupId,
        since: purchasedAt.subtract(kSameTripWindow),
      );
      final peerCanonicalIds = tripPurchases
          .where((p) =>
              p.listItemId != itemId &&
              !excludedPeerItemIds.contains(p.listItemId) &&
              p.canonicalItemId != null &&
              p.canonicalItemId != canonicalId)
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
      // No drain here. Both callers run this inside the transaction of the
      // check-off that triggered it, and a drain started from inside a Drift
      // transaction zone keeps using that transaction after it commits: the
      // request reaches the server, then every local write ("delete the op",
      // "record the attempt") fails with "transaction was used after being
      // closed". The op stays queued with the server already updated, and the
      // banner reads "Syncing" until the app restarts. The callers drain once
      // their transaction has committed.
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

        final remoteItems = await ResponseCacheInterceptor.liveOnly(
          () => _remote.listItems(
            list.id,
            limit: _listCardPreviewLines,
            offset: 0,
          ),
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
