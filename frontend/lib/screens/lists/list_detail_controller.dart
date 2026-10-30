import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../models/list_item_photo_models.dart';
import '../../models/list_models.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../repositories/grocery_repository.dart';
import '../../repositories/list_repository.dart';
import '../../repositories/outbox_error_classifier.dart';
import '../../services/list_service.dart';
import '../../services/restock_service.dart';
import '../../services/scan/correction_memory_service.dart';
import '../../services/scan/grocery_suggestion_service.dart';
import '../../services/scan/household_suggestion_engine.dart';
import '../../theme/animations.dart';
import '../../utils/haptics.dart';
import '../../utils/list_composer_parser.dart';
import '../../services/scan/resolution/string_sim.dart';

/// What an [ListDetailController.addItem] call actually did, so the screen can
/// tell the user when the add landed on a row that was already there instead of
/// creating a new one.
enum AddItemOutcome {
  /// A new row was created.
  created,

  /// A checked-off row came back to the open section.
  restored,

  /// The name was already on the list, unchecked; nothing changed.
  alreadyOnList,

  /// An explicit amount was added on top of an existing open row.
  increased,
}

/// Thrown by actions that need the server to have the list (generating an
/// expense from it) while the list was created offline and has not synced.
class ListNotSyncedException implements Exception {
  const ListNotSyncedException();
}

/// Owns all data + side-effect state for [ListDetailScreen]: the items stream,
/// photos, suggestions, the settle/collapse animation bookkeeping, and every
/// offline-first mutation. The screen keeps only BuildContext-bound concerns
/// (dialogs, snackbars, image picking, navigation, text fields) and listens to
/// this controller for rebuilds.
///
/// Mutation methods are intentionally UI-agnostic: they perform the write and
/// **throw** on failure so the screen can show the operation-specific message.
/// They do not own the re-entrancy guard — the screen wraps each user gesture
/// with its own `_isSaving` lock exactly as before, so the guard still spans
/// the full gesture (dialog input included).
class ListDetailController extends ChangeNotifier {
  ListDetailController({
    required this.ref,
    required String listId,
    String? initialListName,
  })  : _listId = listId,
        _listName = (initialListName != null && initialListName.isNotEmpty)
            ? initialListName
            : '';

  final WidgetRef ref;

  /// The list's id. A list created offline starts under a temporary id and
  /// moves to the server's once its create syncs; the controller follows that
  /// switch (see [ListRepository.listIdChanges]) so a screen opened on the
  /// temporary id keeps working across it.
  String get listId => _listId;
  String _listId;
  StreamSubscription<ListIdChange>? _listIdSub;

  /// True while a reminder change made here is still queued, so a refresh
  /// does not show the server's older value over it.
  bool _reminderQueued = false;

  bool _disposed = false;
  Future<void>? _loadFuture;

  bool _isLoading = true;
  bool _hasError = false;
  bool _hasLocalSnapshot = false;
  bool _refreshFailed = false;
  String _listName;
  final List<ListItem> _items = [];
  final Map<String, ListItem> _pendingCreates = {};
  StreamSubscription<List<ListItem>>? _itemsSub;
  GroceryRepository? _groceryRepo;
  String _searchQuery = '';
  ListService? _service;
  bool _dirty = false;

  /// True once this session added at least one item. Consumed on dispose to
  /// flush the server-side item-added digest, so housemates get their single
  /// summary notification right after the person leaves the list instead of
  /// after the server's idle-window fallback.
  bool _itemsAddedThisSession = false;
  bool _doneSectionExpanded = true;
  String? _groupId;
  String? _listType;
  DateTime? _remindAt;
  DateTime? _reminderSentAt;
  final HouseholdSuggestionEngine _suggestionEngine =
      HouseholdSuggestionEngine();
  Future<List<Product>>? _productCatalogFuture;
  Timer? _suggestDebounce;
  final Map<String, List<ListItemPhoto>> _photosByItemId = {};
  final Set<String> _photoLoadAttempted = {};
  bool _batchPhotosSupported = true;
  bool _canonicalBackfillStarted = false;
  final Map<String, String> _categoryByCanonicalId = {};
  final Set<String> _resolvedCategoryIds = {};
  final Set<String> _categoryIdsInFlight = {};

  /// Max in-flight photo-metadata requests while hydrating a list's
  /// thumbnails (see [_loadPhotosForItems]).
  static const int _photoLoadConcurrency = 4;
  static const int _canonicalBackfillLimit = 20;

  /// Cap on already-on-the-list cards so they never crowd out the catalog and
  /// restock suggestions sharing the composer's single row.
  static const int _listItemSuggestionLimit = 3;
  String _groupCurrency = 'USD';
  String? _userId;

  /// Display names of the household roster, keyed by user id, so item rows can
  /// say who added them. Former members stay in the server roster, so an item
  /// from someone who since left still carries their name.
  Map<String, String> _memberNames = const {};
  int _suggestGeneration = 0;

  /// Bumped instead of [notifyListeners] when only the composer suggestions
  /// change, so a keystroke rebuilds the suggestion cards without rebuilding
  /// the item list. The screen wraps the composer in a [ValueListenableBuilder]
  /// on this; the body keeps listening to the controller itself.
  final ValueNotifier<int> suggestionsRevision = ValueNotifier<int>(0);

  // Cached sorted sections — recomputed only when items or settle-state change.
  List<ListItem> _openItems = const [];
  List<ListItem> _doneItems = const [];
  bool _sectionsDirty = true;

  /// Checked items briefly held in the open section so the strike animation
  /// plays in place before the row collapses away into "Checked off".
  final Set<String> _settling = {};
  final Set<String> _collapsing = {};
  final Map<String, Timer> _settleTimers = {};

  /// How long a freshly checked row rests in place before collapsing — just
  /// long enough to see the strike finish drawing, not an arbitrary pause.
  static const Duration _settleHold = MitlistAnimations.checkToggle;

  // ---- Reactive getters -----------------------------------------------------

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get refreshFailed => _refreshFailed;
  String get listName => _listName;
  List<ListItem> get items => List.unmodifiable(_items);
  String get searchQuery => _searchQuery;
  bool get dirty => _dirty;
  bool get doneSectionExpanded => _doneSectionExpanded;
  String? get groupId => _groupId;
  String? get listType => _listType;

  /// Scheduled household reminder for this list, if any (server truth; not
  /// cached locally, so it appears once the detail fetch lands).
  DateTime? get remindAt => _remindAt;

  /// True while a reminder is scheduled and has not been delivered yet.
  bool get hasPendingReminder => _remindAt != null && _reminderSentAt == null;
  String? get userId => _userId;
  String get groupCurrency => _groupCurrency;

  /// Display name for [userId], or null when the roster has not loaded or
  /// does not know them.
  String? memberName(String? userId) =>
      userId == null ? null : _memberNames[userId];
  List<HouseholdSuggestion> get suggestions => _suggestionEngine.suggestions;

  List<ListItemPhoto>? photosFor(String itemId) => _photosByItemId[itemId];
  String? categoryFor(ListItem item) {
    final canonicalId = item.canonicalItemId;
    return canonicalId == null ? null : _categoryByCanonicalId[canonicalId];
  }

  bool isCollapsing(String itemId) => _collapsing.contains(itemId);

  /// True once the initial load has resolved the list service — guards actions
  /// (cost summary) that should no-op silently before the list is ready.
  bool get isReady => _service != null;

  @override
  void dispose() {
    _disposed = true;
    if (_itemsAddedThisSession && !ListRepository.isLocalListId(listId)) {
      // Leaving the list ends the adding session: release the notification
      // digest now. Best-effort — the service logs and swallows failures, and
      // the server's idle window still delivers if this never arrives (also
      // the path for a list that has not reached the server yet).
      unawaited(_service?.flushListNotifications(listId));
    }
    unawaited(_listIdSub?.cancel());
    for (final timer in _settleTimers.values) {
      timer.cancel();
    }
    _suggestDebounce?.cancel();
    _itemsSub?.cancel();
    _groceryRepo?.detachSse();
    suggestionsRevision.dispose();
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _bumpSuggestions() {
    if (_disposed) return;
    suggestionsRevision.value++;
  }

  // ---- Load & live data -----------------------------------------------------

  Future<void> load() {
    final active = _loadFuture;
    if (active != null) return active;

    late final Future<void> operation;
    operation = _performLoad().whenComplete(() {
      if (identical(_loadFuture, operation)) _loadFuture = null;
    });
    _loadFuture = operation;
    return operation;
  }

  Future<void> _performLoad() async {
    // A refresh must never blank a usable local snapshot. The refresh
    // indicator already communicates activity when content is on screen.
    _isLoading = !_hasLocalSnapshot && _items.isEmpty;
    _hasError = false;
    _refreshFailed = false;
    _notify();

    // Composer suggestions match against the on-device canonical grocery/alias
    // tables, which only get populated by this seed load. `lists_screen` and
    // `scanner_screen` trigger it too, but a list opened without visiting
    // those first (deep link, hub shortcut) would otherwise never seed it and
    // suggestions would silently stay empty forever. Idempotent + no-op once
    // seeded, so firing it unconditionally here is cheap.
    unawaited(ref.read(grocerySeedProvider.future));

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      _service = service;
      final repo = await ref.read(listRepositoryProvider.future);

      _followListId(repo);
      await _watchItems(repo);

      final cached = await repo.getItemsByListOnce(listId);
      if (_disposed) return;
      final cachedGroupId = await repo.getGroupId(listId);
      if (_disposed) return;
      final cachedListType = await repo.getListType(listId);
      if (_disposed) return;
      _hasLocalSnapshot = _hasLocalSnapshot || cachedGroupId != null;
      _sectionsDirty = true;
      _items
        ..clear()
        ..addAll(cached);
      _isLoading = cached.isEmpty && !_hasLocalSnapshot;
      if (cachedGroupId != null) _groupId = cachedGroupId;
      _listType = cachedListType;
      await _applyCachedListState(repo);
      if (_disposed) return;
      _notify();
      if (_listType == 'shopping') {
        unawaited(_ensureGroceryCategories());
      }

      if (ListRepository.isLocalListId(listId)) {
        // Created on this device and not on the server yet: the cache is the
        // whole list, and there is nothing to fetch until its create syncs.
        _isLoading = false;
        _hasLocalSnapshot = true;
        _notify();
        final groupId = _groupId;
        if (groupId != null) await _loadHouseholdContext(repo, groupId);
        return;
      }

      // Refresh list + items in background; stream will update.
      ItemList? list;
      try {
        await repo.refreshListDetail(listId);
        list = await service.getList(listId);
      } catch (e) {
        // Offline with the list cached: keep showing the cache, quietly.
        // Anything else (or offline with nothing to show) is a real failure.
        final offline =
            classifyOutboxError(e) == OutboxErrorDisposition.unreachable;
        if (!offline || !(_hasLocalSnapshot || _items.isNotEmpty)) rethrow;
      }

      if (_disposed) return;
      _isLoading = false;
      _hasLocalSnapshot = true;
      if (list != null) {
        _groupId = list.groupId;
        _listName = list.name;
        _listType = list.type;
        if (!_reminderQueued) {
          _remindAt = list.remindAt;
          _reminderSentAt = list.reminderSentAt;
        }
        // The cached row carries any rename or type change still queued here,
        // which the server copy does not have yet.
        await _applyCachedListState(repo);
        if (_disposed) return;
      }
      _notify();
      final groupId = _groupId;
      if (groupId == null) return;
      unawaited(_backfillCanonicalLinks(repo, groupId));
      await _loadHouseholdContext(repo, groupId);
    } catch (e) {
      if (_disposed) return;
      _isLoading = false;
      final hasUsableContent = _hasLocalSnapshot || _items.isNotEmpty;
      _hasError = !hasUsableContent;
      _refreshFailed = hasUsableContent;
      _notify();
    }
  }

  /// Keeps [listId] pointing at the stored list when a list created offline
  /// syncs and moves to its server id. Best-effort: a repository without the
  /// hook (a test double) just keeps the id it was given.
  void _followListId(ListRepository repo) {
    if (_listIdSub != null) return;
    try {
      _listId = repo.resolveListId(_listId);
      _listIdSub = repo.listIdChanges.listen((change) {
        if (_disposed || change.from != _listId) return;
        _listId = change.to;
        unawaited(_watchItems(repo));
        _notify();
      });
    } catch (_) {}
  }

  Future<void> _watchItems(ListRepository repo) async {
    await _itemsSub?.cancel();
    _itemsSub = repo.watchItemsByList(listId).listen((items) {
      if (_disposed) return;
      _sectionsDirty = true;
      _items
        ..clear()
        ..addAll(items);
      // A pending UI row stays visible until Drift publishes its local row.
      // Match on content + creation time because the repository owns the
      // durable temp id.
      for (final pending in _pendingCreates.values) {
        final landed = items.any((item) =>
            !item.createdAt.isBefore(pending.createdAt) &&
            item.name == pending.name &&
            item.quantity == pending.quantity &&
            item.unit == pending.unit);
        if (!landed) _items.add(pending);
      }
      _notify();
      unawaited(_loadPhotosForItems(items));
      unawaited(_ensureGroceryCategories());
    });
  }

  /// Name and type from the cached list row, and a reminder change still
  /// queued in the outbox, so a list opened offline (or from a link with no
  /// name attached) shows what this device last knew. Best-effort.
  Future<void> _applyCachedListState(ListRepository repo) async {
    try {
      final cachedList = await repo.getListOnce(listId);
      if (cachedList != null) {
        if (cachedList.name.isNotEmpty) _listName = cachedList.name;
        _listType = cachedList.type;
        _groupId ??= cachedList.groupId;
      }
      final queued = await repo.queuedListReminder(listId);
      if (queued != null) {
        _reminderQueued = true;
        _remindAt = queued.remindAt;
        _reminderSentAt = null;
      }
    } catch (_) {}
  }

  /// Live updates and household context for the open list: SSE, the signed-in
  /// user, the household's currency and roster. Each read falls back to the
  /// last response the app cached, so this also works offline.
  Future<void> _loadHouseholdContext(
    ListRepository repo,
    String groupId,
  ) async {
    // Attach SSE so edits from other household members appear in real time.
    final sseService = ref.read(sseServiceProvider);
    repo.attachSse(sseService, groupId);
    // Grocery graph shares the same SSE stream: corrections/aisles from
    // other members invalidate the local graph live.
    try {
      await _ensureGroceryCategories();
      final groceryRepo = _groceryRepo;
      if (!_disposed) {
        groceryRepo?.attachSse(sseService, groupId);
      }
    } catch (_) {}
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final me = await authService.getMe();
      if (!_disposed) {
        _userId = me.id;
        _notify();
      }
    } catch (_) {}
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final group = await groupService.getGroup(groupId);
      if (!_disposed) {
        _groupCurrency = group.currency;
        _notify();
      }
    } catch (_) {}
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final members = await groupService.listMembers(groupId);
      if (!_disposed) {
        _memberNames = {for (final m in members) m.userId: m.displayName};
        _notify();
      }
    } catch (_) {}
    unawaited(_loadPhotosForItems(_items));
  }

  Future<void> _ensureGroceryCategories() async {
    if (_disposed || _listType != 'shopping') return;
    if (!_items.any((item) => item.canonicalItemId != null)) return;
    try {
      await ref.read(grocerySeedProvider.future);
      if (_disposed) return;
      _groceryRepo ??= await ref.read(groceryRepositoryProvider.future);
      if (_disposed) return;
      await _loadGroceryCategories(_items);
    } catch (_) {
      // The visual category layer must never block cached/offline list data.
    }
  }

  Future<void> _loadGroceryCategories(List<ListItem> items) async {
    final groceryRepo = _groceryRepo;
    if (groceryRepo == null || _listType != 'shopping') return;

    final ids = items
        .map((item) => item.canonicalItemId)
        .whereType<String>()
        .where((id) =>
            !_resolvedCategoryIds.contains(id) &&
            !_categoryIdsInFlight.contains(id))
        .toSet();
    if (ids.isEmpty) return;
    _categoryIdsInFlight.addAll(ids);

    try {
      final categories = await groceryRepo.getCanonicalCategories(ids);
      if (_disposed) return;
      _resolvedCategoryIds.addAll(ids);
      if (categories.isNotEmpty) {
        _categoryByCanonicalId.addAll(categories);
        _notify();
      }
    } catch (_) {
      // Category decoration is fail-soft. Leave these ids retryable after a
      // transient reference-database failure; the list itself remains usable.
    } finally {
      _categoryIdsInFlight.removeAll(ids);
    }
  }

  /// Returns and clears the fail-soft refresh signal so the screen can explain
  /// that cached content remains available without replacing it with an error.
  bool consumeRefreshFailure() {
    final failed = _refreshFailed;
    _refreshFailed = false;
    return failed;
  }

  Future<void> _loadPhotosForItems(List<ListItem> items) async {
    final groupId = _groupId;
    final service = _service;
    if (groupId == null || service == null) return;
    // Photos live on the server only; a list it does not have yet has none.
    if (ListRepository.isLocalListId(listId)) return;

    final toLoad =
        items.where((item) => !_photoLoadAttempted.contains(item.id)).toList();
    if (toLoad.isEmpty) return;
    for (final item in toLoad) {
      _photoLoadAttempted.add(item.id);
    }

    // One batch request for the whole list. The old per-item fan-out fired N
    // requests on every list open; on browsers that saturated the per-host
    // connection pool (which SSE already holds a slot of) and visibly starved
    // unrelated calls — adds appeared to hang for seconds.
    if (_batchPhotosSupported) {
      try {
        final byItem = await service.listAllItemPhotos(
          groupId: groupId,
          listId: listId,
        );
        if (_disposed) return;
        if (byItem.isNotEmpty) {
          _photosByItemId.addAll(byItem);
          _notify();
        }
        return;
      } catch (e) {
        if (_disposed) return;
        if (classifyOutboxError(e) == OutboxErrorDisposition.unreachable) {
          // Offline: no per-item fan-out of doomed requests, and these items
          // are tried again on the next load.
          for (final item in toLoad) {
            _photoLoadAttempted.remove(item.id);
          }
          return;
        }
        // Older self-hosted backends predate the batch route; fall back to
        // per-item requests for the rest of this controller's lifetime.
        _batchPhotosSupported = false;
      }
    }

    // Fallback: bounded worker pool rather than one request per item all at
    // once — a 50-item list would otherwise fire 50 concurrent requests the
    // moment the screen opens (and offline, 50 doomed ones). Workers pull
    // from a shared cursor; the UI is notified as each photo lands so early
    // rows get their thumbnails without waiting for the whole list.
    var next = 0;
    Future<void> worker() async {
      while (!_disposed) {
        final i = next++;
        if (i >= toLoad.length) return;
        final item = toLoad[i];
        try {
          final photos = await service.listItemPhotos(
            groupId: groupId,
            itemId: item.id,
          );
          if (photos.isNotEmpty && !_disposed) {
            _photosByItemId[item.id] = photos;
            _notify();
          }
        } catch (_) {}
      }
    }

    await Future.wait([
      for (var w = 0; w < _photoLoadConcurrency && w < toLoad.length; w++)
        worker(),
    ]);
  }

  // ---- Sections / search ----------------------------------------------------

  List<ListItem> get _filteredItems {
    if (_searchQuery.isEmpty) return List.unmodifiable(_items);
    final lower = _searchQuery.toLowerCase();
    return _items.where((i) => i.name.toLowerCase().contains(lower)).toList();
  }

  /// Unchecked first, then checked while searching.
  List<ListItem> get searchOrderedItems {
    final list = List<ListItem>.from(_filteredItems);
    list.sort((a, b) {
      final aOpen = _displaysAsOpen(a);
      final bOpen = _displaysAsOpen(b);
      if (aOpen != bOpen) {
        return aOpen ? -1 : 1;
      }
      return a.position.compareTo(b.position);
    });
    return list;
  }

  /// Settling rows count as open so they stay in place during the hold.
  bool _displaysAsOpen(ListItem item) =>
      !item.checked || _settling.contains(item.id);

  void _ensureSectionsUpToDate() {
    if (!_sectionsDirty) return;
    _openItems = _items.where(_displaysAsOpen).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    _doneItems = _items.where((i) => !_displaysAsOpen(i)).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    _sectionsDirty = false;
  }

  List<ListItem> get openItemsSorted {
    _ensureSectionsUpToDate();
    return _openItems;
  }

  List<ListItem> get doneItemsSorted {
    _ensureSectionsUpToDate();
    return _doneItems;
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    _notify();
  }

  void toggleDoneSection() {
    _doneSectionExpanded = !_doneSectionExpanded;
    _notify();
  }

  void setListName(String name) {
    _listName = name;
    _notify();
  }

  // ---- Settle / collapse ----------------------------------------------------

  void _cancelSettle(String id) {
    _settleTimers.remove(id)?.cancel();
    if (_settling.contains(id) || _collapsing.contains(id)) {
      _sectionsDirty = true;
      _settling.remove(id);
      _collapsing.remove(id);
      _notify();
    }
  }

  /// Called when a settled row finishes its collapse animation; the item then
  /// re-sections into "Checked off" with no visible jump.
  void finishSettle(String id) {
    _settleTimers.remove(id)?.cancel();
    if (_disposed) return;
    _sectionsDirty = true;
    _settling.remove(id);
    _collapsing.remove(id);
    _notify();
  }

  // ---- Mutations (throw on failure) -----------------------------------------

  Future<void> toggleItem(
    ListItem item,
    bool value, {
    required bool disableAnimations,
  }) async {
    unawaited(Haptics.light());
    final service = _service;
    if (service == null) return;

    if (value && !disableAnimations && _searchQuery.isEmpty) {
      // Hold the row in place while the strike draws, then collapse it away
      // into the done section instead of jump-cutting on the next rebuild.
      _settleTimers.remove(item.id)?.cancel();
      _sectionsDirty = true;
      _settling.add(item.id);
      _notify();
      _settleTimers[item.id] = Timer(_settleHold, () {
        if (_disposed) return;
        _sectionsDirty = true;
        _collapsing.add(item.id);
        _notify();
      });
    } else {
      _cancelSettle(item.id);
    }

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.updateItemOfflineFirst(
        listId,
        item.id,
        UpdateListItemRequest(checked: value),
      );
      final groupId = _groupId;
      if (value && groupId != null) _markStep(groupId, HubQuickStartStep.tick);
      if (_disposed) return;
      _dirty = true;
    } catch (e) {
      if (_disposed) return;
      _cancelSettle(item.id);
      rethrow;
    }
  }

  /// Ticks the joiner checklist's step on Home (plans/048 stage 7).
  void _markStep(String groupId, HubQuickStartStep step) {
    unawaited(markHubQuickStartStep(groupId, step).then(
      (_) => ref.invalidate(hubQuickStartPrefsProvider(groupId)),
    ));
  }

  Future<void> completeAll() async {
    if (_service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.setAllCheckedOfflineFirst(listId, checked: true);
    if (_disposed) return;
    _dirty = true;
  }

  Future<void> uncheckAll() async {
    if (_service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.setAllCheckedOfflineFirst(listId, checked: false);
    if (_disposed) return;
    _dirty = true;
  }

  /// Adds an item parsed from the composer text. A bare name takes the plain
  /// offline-first create path; a quantity/unit ("2 milk", "1.5 kg flour")
  /// takes the additive offline-first amount path.
  ///
  /// Re-adding a name the list already carries never duplicates the row: a
  /// checked-off match is restored to the open section (and moved to the
  /// bottom, where a fresh add would land), and an open match is left alone.
  /// The quantity path keeps its additive behaviour — it merges into the same
  /// row inside the repository — so only the outcome reported back differs.
  /// Adds [text] to the list. [pickedFromQuery] is what the person had typed
  /// when they picked the suggestion that supplied [canonicalItemId]; the add
  /// then also teaches the resolver that word (see [_learnFromPick]).
  Future<AddItemOutcome> addItem(
    String text, {
    String? canonicalItemId,
    String? pickedFromQuery,
  }) async {
    final service = _service;
    if (service == null) {
      throw StateError('list detail is not ready');
    }
    final parsed = parseComposerItem(text);
    final bareAdd = parsed.quantity == 1 && parsed.unit.isEmpty;
    final match = findMatchingItem(parsed.name, unit: parsed.unit);
    if (bareAdd && match != null) {
      if (!match.checked) return AddItemOutcome.alreadyOnList;
      await _restoreCheckedItem(match);
      return AddItemOutcome.restored;
    }
    final now = DateTime.now();
    final pending = ListItem(
      id: const Uuid().v4(),
      listId: listId,
      name: parsed.name,
      quantity: parsed.quantity,
      unit: parsed.unit,
      checked: false,
      position: _items.fold(
              -1, (max, item) => item.position > max ? item.position : max) +
          1,
      canonicalItemId: canonicalItemId,
      addedBy: _userId,
      createdAt: now,
      updatedAt: now,
    );
    _pendingCreates[pending.id] = pending;
    _items.add(pending);
    _sectionsDirty = true;
    _dirty = true;
    _notify();

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      final shouldResolve = canonicalItemId == null && _groupId != null;
      ListItem created;
      if (bareAdd) {
        created = await repo.createItemOfflineFirst(
          listId,
          CreateListItemRequest(
            name: parsed.name,
            canonicalItemId: canonicalItemId,
          ),
          deferImmediateSync: shouldResolve,
          addedBy: _userId,
        );
      } else {
        created = await repo.addItemAmountOfflineFirst(
          listId,
          // The repository merges on an exact name; hand it the row's own
          // spelling so "2 MILK" tops up the existing "Milk" instead of
          // opening a second row beside it.
          name: match?.name ?? parsed.name,
          amount: parsed.quantity,
          unit: parsed.unit,
          canonicalItemId: canonicalItemId,
          deferImmediateSync: shouldResolve,
          addedBy: _userId,
        );
      }
      _itemsAddedThisSession = true;
      if (shouldResolve) {
        try {
          final resolvedId = await _resolveHighConfidence(parsed.name);
          if (resolvedId != null) {
            created = await repo.setCanonicalItemIdLocal(
              listId,
              created.id,
              resolvedId,
            );
          }
        } catch (_) {
          // Enrichment is fail-soft; the durable list write still succeeds.
        } finally {
          repo.triggerAutoSync();
        }
      }
      final outcome = match == null
          ? AddItemOutcome.created
          : (match.checked
              ? AddItemOutcome.restored
              : AddItemOutcome.increased);
      if (canonicalItemId != null && pickedFromQuery != null) {
        unawaited(_learnFromPick(pickedFromQuery, canonicalItemId));
      }
      if (_disposed) return outcome;
      _pendingCreates.remove(pending.id);
      _items.removeWhere((item) => item.id == pending.id);
      final idx = _items.indexWhere((item) => item.id == created.id);
      if (idx >= 0) {
        _items[idx] = created;
      } else {
        _items.add(created);
      }
      _sectionsDirty = true;
      _notify();
      return outcome;
    } catch (_) {
      _pendingCreates.remove(pending.id);
      _items.removeWhere((item) => item.id == pending.id);
      _sectionsDirty = true;
      _notify();
      rethrow;
    }
  }

  /// Remembers that this household means [canonicalItemId] by [typedQuery]
  /// ("nutella" → chocolate hazelnut spread), so the next time it is typed and
  /// submitted without tapping the suggestion it still links.
  ///
  /// Only words the catalog could not have matched by spelling are learned. A
  /// fragment ("mi" before tapping Milk) or a near-spelling of the item's own
  /// name would teach a misleading household alias.
  Future<void> _learnFromPick(String typedQuery, String canonicalItemId) async {
    final groupId = _groupId;
    final typed = normaliseText(parseComposerItem(typedQuery).name);
    if (groupId == null || typed.isEmpty) return;
    try {
      final db = ref.read(appDatabaseProvider);
      final items = await db.getCanonicalItemsByIds([canonicalItemId]);
      if (items.isEmpty) return;
      final item = items.single;
      if (!CorrectionMemoryService.isLearnablePick(
          typed, [item.nameEn, item.nameDe, item.nameFr, item.nameEs])) {
        return;
      }
      await ref.read(correctionMemoryProvider).recordAlias(
            groupId: groupId,
            userId: _userId ?? '',
            rawText: typed,
            canonicalItemId: canonicalItemId,
            source: 'suggestion_pick',
          );
      final groceryRepo = await ref.read(groceryRepositoryProvider.future);
      unawaited(groceryRepo.uploadCorrection(
        groupId: groupId,
        rawText: typed,
        canonicalItemId: canonicalItemId,
      ));
    } catch (_) {
      // Learning is best-effort; the add itself already succeeded.
    }
  }

  /// The row this list already carries for [name], or null. An open row wins
  /// over a checked one — if the item is already waiting to be bought there is
  /// nothing to restore. A unit only has to match when the composer text
  /// actually carried one, so a bare "milk" still finds "2 l milk".
  ListItem? findMatchingItem(String name, {String unit = ''}) {
    final target = normaliseText(name);
    if (target.isEmpty) return null;
    ListItem? open;
    ListItem? checked;
    for (final item in _items) {
      if (normaliseText(item.name) != target) continue;
      if (unit.isNotEmpty && item.unit != unit) continue;
      if (item.checked) {
        if (checked == null || item.position < checked.position) checked = item;
      } else {
        if (open == null || item.position < open.position) open = item;
      }
    }
    return open ?? checked;
  }

  /// Brings a checked-off row back into the open section and parks it at the
  /// bottom, where a freshly added item would have landed — otherwise the
  /// restore happens somewhere off-screen in a long list and reads as a no-op.
  Future<void> _restoreCheckedItem(ListItem item) async {
    _cancelSettle(item.id);
    final maxPosition = _items.fold<int>(
      -1,
      (max, candidate) => candidate.position > max ? candidate.position : max,
    );
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.updateItemOfflineFirst(
      listId,
      item.id,
      UpdateListItemRequest(
        checked: false,
        position: item.position == maxPosition ? null : maxPosition + 1,
      ),
    );
    // Housemates see a restored row exactly as they see a new one, so it feeds
    // the same end-of-session item-added digest.
    _itemsAddedThisSession = true;
    if (_disposed) return;
    _dirty = true;
  }

  /// Adds a restock suggestion via the same offline-first create path as
  /// [addItem]. Not a new write path — only the entry point differs. It
  /// absorbs into an existing row on the same terms as [addItem]: restock
  /// predictions only exclude names that are currently *open*, so a checked-off
  /// row is exactly the case this has to avoid duplicating.
  Future<AddItemOutcome> addRestockSuggestion(
      RestockSuggestion suggestion) async {
    final match = findMatchingItem(suggestion.name);
    if (match != null) {
      if (!match.checked) return AddItemOutcome.alreadyOnList;
      await _restoreCheckedItem(match);
      return AddItemOutcome.restored;
    }
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.createItemOfflineFirst(
      listId,
      CreateListItemRequest(
        name: suggestion.name,
        canonicalItemId: suggestion.canonicalItemId,
      ),
      addedBy: _userId,
    );
    _itemsAddedThisSession = true;
    if (_disposed) return AddItemOutcome.created;
    _dirty = true;
    return AddItemOutcome.created;
  }

  Future<void> clearItems({required bool onlyChecked}) async {
    if (_service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.clearItemsOfflineFirst(listId, onlyChecked: onlyChecked);
    if (_disposed) return;
    _dirty = true;
  }

  Future<void> deleteItem(ListItem item) async {
    _cancelSettle(item.id);
    if (_service == null) return;
    // Optimistic removal so the row disappears instantly; the offline-first
    // delete + background sync follow. On failure the screen surfaces the error
    // and the next stream emit restores the row from the unchanged DB.
    final removedIndex =
        _items.indexWhere((candidate) => candidate.id == item.id);
    final removedItem = removedIndex < 0 ? null : _items[removedIndex];
    final wasDirty = _dirty;
    _sectionsDirty = true;
    if (removedIndex >= 0) _items.removeAt(removedIndex);
    _dirty = true;
    _notify();
    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.deleteItemOfflineFirst(listId, item.id);
    } catch (_) {
      if (!_disposed &&
          removedItem != null &&
          !_items.any((candidate) => candidate.id == item.id)) {
        _items.insert(removedIndex.clamp(0, _items.length), removedItem);
        _sectionsDirty = true;
        _dirty = wasDirty;
        _notify();
      }
      rethrow;
    }
  }

  Future<void> restoreDeletedItem(ListItem item) async {
    final service = _service;
    if (service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    final restored = await repo.createItemOfflineFirst(
      listId,
      CreateListItemRequest(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        note: item.note,
        priceCents: item.priceCents,
        canonicalItemId: item.canonicalItemId,
      ),
      addedBy: item.addedBy ?? _userId,
    );
    if (item.checked) {
      await repo.updateItemOfflineFirst(
        listId,
        restored.id,
        const UpdateListItemRequest(checked: true),
      );
    }
    if (_disposed) return;
    _dirty = true;
  }

  Future<void> setItemPrice(ListItem item, int cents) async {
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.updateItemOfflineFirst(
      listId,
      item.id,
      UpdateListItemRequest(priceCents: cents),
    );
    if (_disposed) return;
    _dirty = true;
  }

  /// Patches name/quantity/unit/note on an item through the same offline-first
  /// path as [setItemPrice]. Only non-null fields are sent.
  Future<void> updateItemFields(
    ListItem item, {
    String? name,
    double? quantity,
    String? unit,
    String? note,
  }) async {
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.updateItemOfflineFirst(
      listId,
      item.id,
      UpdateListItemRequest(
        name: name,
        quantity: quantity,
        unit: unit,
        note: note,
      ),
    );
    if (name != null &&
        name.trim().toLowerCase() != item.name.trim().toLowerCase()) {
      try {
        final canonicalId = await _resolveHighConfidence(name);
        if (canonicalId != null) {
          await repo.setCanonicalItemIdLocal(listId, item.id, canonicalId);
        }
      } catch (_) {
        // The rename is already durable; uncertain/failed enrichment remains
        // unlinked instead of restoring the stale canonical id.
      }
    }
    if (_disposed) return;
    _dirty = true;
  }

  Future<String?> _resolveHighConfidence(
    String name, {
    List<String>? listContext,
  }) async {
    final groupId = _groupId;
    if (groupId == null || name.trim().isEmpty) return null;
    // Ensure the global grocery reference DB is installed+attached before
    // resolving. This is now a fast, version-gated file copy (not the old
    // ~280k-row runtime seed), so awaiting it no longer stalls the add.
    await ref.read(grocerySeedProvider.future);
    final context = listContext ??
        _items
            .map((item) => item.canonicalItemId)
            .whereType<String>()
            .toSet()
            .toList(growable: false);
    return ref.read(canonicalLinkServiceProvider).resolveHighConfidence(
          name,
          groupId,
          listContext: context,
        );
  }

  /// Opportunistically enriches only the currently-open list and caps work so
  /// opening a large historical list never turns into an unbounded model pass.
  Future<void> _backfillCanonicalLinks(
    ListRepository repo,
    String groupId,
  ) async {
    if (_canonicalBackfillStarted) return;
    _canonicalBackfillStarted = true;
    try {
      await ref.read(grocerySeedProvider.future);
      final snapshot = await repo.getItemsByListOnce(listId);
      final context = snapshot
          .map((item) => item.canonicalItemId)
          .whereType<String>()
          .toSet()
          .toList();
      final unlinked = snapshot
          .where((item) => item.canonicalItemId == null)
          .take(_canonicalBackfillLimit);
      for (final item in unlinked) {
        if (_disposed) return;
        try {
          final canonicalId = await ref
              .read(canonicalLinkServiceProvider)
              .resolveHighConfidence(
                item.name,
                groupId,
                listContext: context,
              );
          if (canonicalId == null) continue;
          await repo.setCanonicalItemIdLocal(listId, item.id, canonicalId);
          context.add(canonicalId);
        } catch (_) {
          // One malformed/ambiguous row must not stop the bounded backfill.
        }
      }
    } catch (_) {
      // Backfill is opportunistic and never blocks opening the list.
    }
  }

  /// Renames the list offline-first: the cache (and so the lists grid,
  /// whatever route the user takes back) changes at once, the server when the
  /// queued edit syncs.
  Future<void> renameList(String newName) async {
    if (_service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.updateListOfflineFirst(listId, UpdateListRequest(name: newName));
    if (_disposed) return;
    _listName = newName;
    _notify();
  }

  /// Schedules (or clears, with null) the household reminder for this list.
  /// Queued through the outbox, so it works offline. Throws on failure so the
  /// screen can show its own message.
  Future<void> setReminder(DateTime? remindAt) async {
    if (_service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.setListReminderOfflineFirst(listId, remindAt);
    if (_disposed) return;
    _reminderQueued = true;
    _remindAt = remindAt;
    _reminderSentAt = null;
    _notify();
  }

  /// Returns true if the archive was performed (false if the list isn't loaded
  /// yet), so the screen only navigates away on a real archive.
  Future<bool> archiveList() async {
    if (_service == null) return false;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.archiveListOfflineFirst(listId);
    return true;
  }

  /// Returns true if the delete was performed (false if the list isn't loaded
  /// yet), so the screen only navigates away on a real delete.
  Future<bool> deleteList() async {
    if (_service == null) return false;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.deleteListOfflineFirst(listId);
    return true;
  }

  /// The server's cost summary, or the same sums worked out from the cached
  /// items when the server can't be reached (or doesn't have the list yet).
  Future<Map<String, dynamic>> getCostSummary() async {
    final service = _service;
    if (service == null) throw StateError('list not loaded');
    if (ListRepository.isLocalListId(listId)) return _localCostSummary();
    try {
      return await service.getCostSummary(listId);
    } catch (e) {
      if (classifyOutboxError(e) != OutboxErrorDisposition.unreachable) {
        rethrow;
      }
      return _localCostSummary();
    }
  }

  /// Mirrors the backend: the total of every priced item, split evenly over
  /// the household (rounded up). The roster may be unknown offline, in which
  /// case the share is the whole total.
  Map<String, dynamic> _localCostSummary() {
    final total =
        _items.fold<int>(0, (sum, item) => sum + (item.priceCents ?? 0));
    final members = _memberNames.isEmpty ? 1 : _memberNames.length;
    return {
      'total_cents': total,
      'equal_share_cents': (total + members - 1) ~/ members,
    };
  }

  /// Turns the priced items into an expense. Server-side only (it creates the
  /// expense and its splits there), so it needs a connection and a list the
  /// server already has.
  Future<void> generateExpense() async {
    final service = _service;
    if (service == null) return;
    if (ListRepository.isLocalListId(listId)) {
      throw const ListNotSyncedException();
    }
    // The server sums the prices it has: send any price edits still waiting
    // in the sync session first, or the expense would miss them.
    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.drainOutboxOnce();
    } catch (_) {}
    await service.generateExpense(listId);
    // The expense was made on the server; pull it into the Money cache so it
    // shows there without waiting for the next refresh. Best-effort.
    final groupId = _groupId;
    if (groupId == null) return;
    try {
      final finance = await ref.read(financeRepositoryProvider.future);
      await finance.refreshGroup(groupId);
    } catch (_) {}
  }

  // ---- Photos ---------------------------------------------------------------

  Future<void> addItemPhoto(ListItem item) async {
    final groupId = _groupId;
    if (groupId == null) return;
    // Photos attach to the server's copy of the item.
    if (ListRepository.isLocalListId(listId)) {
      throw const ListNotSyncedException();
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final attachmentRepo = await ref.read(attachmentRepositoryProvider.future);
    final attachment = await attachmentRepo.uploadAttachment(
      groupId: groupId,
      purpose: 'list_item_photo',
      filename: file.name,
      contentType: file.mimeType ?? '',
      bytes: Uint8List.fromList(bytes),
    );
    final svc = await ref.read(listServiceProviderAsync.future);
    await svc.attachItemPhoto(
      groupId: groupId,
      itemId: item.id,
      attachmentId: attachment.id,
    );

    final photos = await svc.listItemPhotos(groupId: groupId, itemId: item.id);
    if (_disposed) return;
    _photosByItemId[item.id] = photos;
    _notify();
  }

  Future<void> removeItemPhoto(ListItem item) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final photos = _photosByItemId[item.id];
    if (photos == null || photos.isEmpty) return;
    final attachmentId = photos.first.attachmentId;

    final svc = await ref.read(listServiceProviderAsync.future);
    await svc.detachItemPhoto(
      groupId: groupId,
      itemId: item.id,
      attachmentId: attachmentId,
    );

    // Best-effort cleanup: avoid orphaned attachments.
    try {
      final attachSvc = await ref.read(attachmentServiceProviderAsync.future);
      await attachSvc.deleteAttachment(
        groupId: groupId,
        attachmentId: attachmentId,
      );
    } catch (_) {}

    final updated = await svc.listItemPhotos(groupId: groupId, itemId: item.id);
    if (_disposed) return;
    _photosByItemId[item.id] = updated;
    _notify();
  }

  // ---- Reorder --------------------------------------------------------------

  Future<void> reorderOpen(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    unawaited(Haptics.light());

    final open = openItemsSorted;
    final done = doneItemsSorted;
    final originalPositions = {
      for (final item in _items) item.id: item.position,
    };
    final wasDirty = _dirty;
    final reorderedOpen = List<ListItem>.from(open);
    final moved = reorderedOpen.removeAt(oldIndex);
    reorderedOpen.insert(newIndex, moved);

    final itemIdsInOrder = [
      ...reorderedOpen.map((i) => i.id),
      ...done.map((i) => i.id),
    ];

    _sectionsDirty = true;
    var pos = 0;
    for (final id in itemIdsInOrder) {
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx < 0) continue;
      final item = _items[idx];
      _items[idx] = ListItem(
        id: item.id,
        listId: item.listId,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        note: item.note,
        checked: item.checked,
        position: pos++,
        priceCents: item.priceCents,
        canonicalItemId: item.canonicalItemId,
        claimedBy: item.claimedBy,
        addedBy: item.addedBy,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
    }
    _dirty = true;
    _notify();

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.reorderItemsOfflineFirst(listId, itemIdsInOrder);
    } catch (_) {
      if (!_disposed) {
        for (var index = 0; index < _items.length; index++) {
          final item = _items[index];
          final originalPosition = originalPositions[item.id];
          if (originalPosition != null) {
            _items[index] = _withPosition(item, originalPosition);
          }
        }
        _sectionsDirty = true;
        _dirty = wasDirty;
        _notify();
      }
      rethrow;
    }
  }

  ListItem _withPosition(ListItem item, int position) => ListItem(
        id: item.id,
        listId: item.listId,
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        note: item.note,
        checked: item.checked,
        position: position,
        priceCents: item.priceCents,
        canonicalItemId: item.canonicalItemId,
        claimedBy: item.claimedBy,
        addedBy: item.addedBy,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );

  // ---- Scan helper ----------------------------------------------------------

  /// Resolves the current user id, fetching it once if the initial load hasn't
  /// populated it yet (needed before launching a scan).
  Future<String?> ensureUserId() async {
    if (_userId != null) return _userId;
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final me = await authService.getMe();
      if (!_disposed) {
        _userId = me.id;
        _notify();
      }
      return me.id;
    } catch (_) {
      return null;
    }
  }

  // ---- Suggestions ----------------------------------------------------------

  void refreshSuggestionsDebounced(String query) {
    _suggestDebounce?.cancel();
    // Invalidate already-running work immediately. Waiting until the debounce
    // fires leaves a window where results for the previous text can repaint.
    final generation = ++_suggestGeneration;
    _suggestDebounce = Timer(const Duration(milliseconds: 180),
        () => _refreshSuggestions(query, generation));
  }

  /// Refreshes both suggestion sources for the given composer text: the offline
  /// canonical grocery seed (alias-powered) and the backend product history. A
  /// generation counter ensures stale results from a prior keystroke are
  /// silently discarded if a newer query has already started.
  Future<void> refreshSuggestions([String? query]) async {
    _suggestDebounce?.cancel();
    return _refreshSuggestions(query, ++_suggestGeneration);
  }

  Future<void> _refreshSuggestions(String? query, int generation) async {
    if (_disposed || _suggestGeneration != generation) return;
    final q = (query ?? '').trim();
    final gen = generation;

    _suggestionEngine.beginQuery(q);
    _setListItemSuggestions(q);
    _bumpSuggestions();

    // These sources are independent. In particular, product history and
    // restock predictions must not wait for the large one-time grocery seed to
    // finish before they can appear in the composer.
    final bundled = _refreshBundledGrocerySuggestions(q, gen);
    final groupId = _groupId;
    if (groupId == null) {
      await bundled;
      return;
    }
    await Future.wait([
      bundled,
      _refreshGrocerySuggestions(q, groupId, gen),
      _refreshProductSuggestions(q, groupId, gen),
      if (q.isEmpty && _isShoppingList)
        _refreshRestockSuggestions(groupId, gen)
      else if (q.isEmpty)
        _clearRestockSuggestions(gen),
    ]);
  }

  Future<void> _refreshBundledGrocerySuggestions(
    String query,
    int generation,
  ) async {
    try {
      final suggestions = await ref
          .read(bundledGrocerySuggestionServiceProvider)
          .suggest(query);
      if (_disposed || _suggestGeneration != generation) return;
      _suggestionEngine.setGrocerySuggestions(
        HouseholdSuggestionSource.bundled,
        suggestions,
      );
      _bumpSuggestions();
    } catch (_) {}
  }

  Future<void> _refreshGrocerySuggestions(
    String query,
    String groupId,
    int generation,
  ) async {
    // Query the currently available aliases first so autocomplete can appear
    // while the one-time seed is still loading, then query once more after the
    // seed completes for the full result set.
    await _queryGrocerySuggestions(query, groupId, generation);
    if (_disposed || _suggestGeneration != generation) return;
    try {
      await ref.read(grocerySeedProvider.future);
    } catch (_) {}
    if (_disposed || _suggestGeneration != generation) return;
    await _queryGrocerySuggestions(query, groupId, generation);
  }

  Future<void> _queryGrocerySuggestions(
    String query,
    String groupId,
    int generation,
  ) async {
    try {
      final grocery = await ref.read(grocerySuggestionServiceProvider).suggest(
            query,
            groupId,
            suggestionContext: _isShoppingList
                ? GrocerySuggestionContext.shoppingList
                : GrocerySuggestionContext.nonShoppingList,
            listContextIds: _openCanonicalContextIds,
          );
      if (_disposed || _suggestGeneration != generation) return;
      _suggestionEngine.setGrocerySuggestions(
        HouseholdSuggestionSource.catalog,
        grocery,
      );
      _bumpSuggestions();
    } catch (_) {}
  }

  Future<void> _refreshProductSuggestions(
    String query,
    String groupId,
    int generation,
  ) async {
    try {
      final products = await _loadProductCatalog(groupId);
      if (_disposed || _suggestGeneration != generation) return;
      final normalizedQuery = normaliseText(query);
      final matches = normalizedQuery.isEmpty
          ? products
          : products
              .where((product) =>
                  normaliseText(product.name).contains(normalizedQuery))
              .toList();
      _suggestionEngine.setProducts(matches.take(8).toList());
      _bumpSuggestions();
    } catch (_) {
      if (!_disposed && _suggestGeneration == generation) {
        _suggestionEngine.setProducts(const []);
        _bumpSuggestions();
      }
    }
  }

  Future<List<Product>> _loadProductCatalog(String groupId) {
    return _productCatalogFuture ??= () async {
      try {
        final service = await ref.read(listServiceProviderAsync.future);
        return await service.listProducts(groupId);
      } catch (_) {
        _productCatalogFuture = null;
        rethrow;
      }
    }();
  }

  Future<void> _refreshRestockSuggestions(
    String groupId,
    int generation,
  ) async {
    try {
      final currentNames = _items
          .where((it) => !it.checked)
          .map((it) => it.name.toLowerCase())
          .toSet();
      final restock = await ref.read(restockServiceProvider).due(
            groupId: groupId,
            currentItemNames: currentNames,
            listContextIds: _openCanonicalContextIds,
            limit: 5,
          );
      if (_disposed || _suggestGeneration != generation) return;
      _suggestionEngine.setRestockSuggestions(restock);
      _bumpSuggestions();
    } catch (_) {
      if (!_disposed && _suggestGeneration == generation) {
        _suggestionEngine.setRestockSuggestions(const []);
        _bumpSuggestions();
      }
    }
  }

  /// Offers rows already on this list back to the composer, so a checked-off
  /// item can be re-added by name instead of being retyped into a duplicate.
  /// Checked rows come first — an open row is already visible above the
  /// composer, so its card only exists to head off the duplicate.
  void _setListItemSuggestions(String query) {
    final q = normaliseText(query);
    if (q.isEmpty) {
      _suggestionEngine.setListItemSuggestions(const []);
      return;
    }
    final matches = <ListItem>[];
    for (final item in _items) {
      if (normaliseText(item.name).contains(q)) matches.add(item);
    }
    matches.sort((a, b) {
      if (a.checked != b.checked) return a.checked ? -1 : 1;
      final aPrefix = normaliseText(a.name).startsWith(q);
      final bPrefix = normaliseText(b.name).startsWith(q);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      return a.position.compareTo(b.position);
    });
    _suggestionEngine.setListItemSuggestions(
      matches.take(_listItemSuggestionLimit).toList(growable: false),
    );
  }

  bool get _isShoppingList => _listType == 'shopping';

  List<String> get _openCanonicalContextIds => _items
      .where((item) => !item.checked && item.canonicalItemId != null)
      .map((item) => item.canonicalItemId!)
      .toSet()
      .toList(growable: false);

  Future<void> _clearRestockSuggestions(int generation) async {
    if (_disposed || _suggestGeneration != generation) return;
    _suggestionEngine.setRestockSuggestions(const []);
    _bumpSuggestions();
  }
}
