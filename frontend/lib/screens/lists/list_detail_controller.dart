import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/list_item_photo_models.dart';
import '../../models/list_models.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart';
import '../../services/list_service.dart';
import '../../services/restock_service.dart';
import '../../services/scan/grocery_suggestion_service.dart';
import '../../utils/haptics.dart';
import '../../utils/list_composer_parser.dart';

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
    required this.listId,
    String? initialListName,
  }) : _listName =
            (initialListName != null && initialListName.isNotEmpty)
                ? initialListName
                : '';

  final WidgetRef ref;
  final String listId;

  bool _disposed = false;

  bool _isLoading = true;
  bool _hasError = false;
  String _listName;
  final List<ListItem> _items = [];
  StreamSubscription<List<ListItem>>? _itemsSub;
  String _searchQuery = '';
  ListService? _service;
  bool _dirty = false;
  bool _doneSectionExpanded = true;
  String? _groupId;
  List<Product> _productSuggestions = [];
  List<GrocerySuggestion> _grocerySuggestions = [];
  Timer? _suggestDebounce;
  final Map<String, List<ListItemPhoto>> _photosByItemId = {};
  final Set<String> _photoLoadAttempted = {};
  String _groupCurrency = 'USD';
  String? _userId;
  int _suggestGeneration = 0;

  // Cached sorted sections — recomputed only when items or settle-state change.
  List<ListItem> _openItems = const [];
  List<ListItem> _doneItems = const [];
  bool _sectionsDirty = true;

  /// Checked items briefly held in the open section so the strike animation
  /// plays in place before the row collapses away into "Checked off".
  final Set<String> _settling = {};
  final Set<String> _collapsing = {};
  final Map<String, Timer> _settleTimers = {};

  /// How long a freshly checked row rests in place before collapsing.
  static const Duration _settleHold = Duration(milliseconds: 650);

  // ---- Reactive getters -----------------------------------------------------

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get listName => _listName;
  List<ListItem> get items => List.unmodifiable(_items);
  String get searchQuery => _searchQuery;
  bool get dirty => _dirty;
  bool get doneSectionExpanded => _doneSectionExpanded;
  String? get groupId => _groupId;
  String? get userId => _userId;
  String get groupCurrency => _groupCurrency;
  List<Product> get productSuggestions => _productSuggestions;
  List<GrocerySuggestion> get grocerySuggestions => _grocerySuggestions;

  List<ListItemPhoto>? photosFor(String itemId) => _photosByItemId[itemId];
  bool isCollapsing(String itemId) => _collapsing.contains(itemId);

  /// True once the initial load has resolved the list service — guards actions
  /// (cost summary) that should no-op silently before the list is ready.
  bool get isReady => _service != null;

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _settleTimers.values) {
      timer.cancel();
    }
    _suggestDebounce?.cancel();
    _itemsSub?.cancel();
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  // ---- Load & live data -----------------------------------------------------

  Future<void> load() async {
    _isLoading = true;
    _hasError = false;
    _notify();

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      _service = service;
      final repo = await ref.read(listRepositoryProvider.future);

      await _itemsSub?.cancel();
      _itemsSub = repo.watchItemsByList(listId).listen((items) {
        if (_disposed) return;
        _sectionsDirty = true;
        _items
          ..clear()
          ..addAll(items);
        _notify();
        unawaited(_loadPhotosForItems(items));
      });

      final cached = await repo.getItemsByListOnce(listId);
      if (_disposed) return;
      final cachedGroupId = await repo.getGroupId(listId);
      if (_disposed) return;
      _sectionsDirty = true;
      _items
        ..clear()
        ..addAll(cached);
      _isLoading = cached.isEmpty;
      if (cachedGroupId != null) _groupId = cachedGroupId;
      _notify();

      // Refresh list + items in background; stream will update.
      await repo.refreshListDetail(listId);
      final list = await service.getList(listId);

      if (_disposed) return;
      _isLoading = false;
      _listName = list.name;
      _groupId = list.groupId;
      _notify();

      // Attach SSE so edits from other household members appear in real time.
      final sseService = ref.read(sseServiceProvider);
      repo.attachSse(sseService, list.groupId);
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
        final group = await groupService.getGroup(list.groupId);
        if (!_disposed) {
          _groupCurrency = group.currency;
          _notify();
        }
      } catch (_) {}
      unawaited(_loadPhotosForItems(_items));
    } catch (e) {
      if (_disposed) return;
      _isLoading = false;
      _hasError = true;
      _notify();
    }
  }

  Future<void> _loadPhotosForItems(List<ListItem> items) async {
    final groupId = _groupId;
    final service = _service;
    if (groupId == null || service == null) return;

    final toLoad =
        items.where((item) => !_photoLoadAttempted.contains(item.id)).toList();
    if (toLoad.isEmpty) return;
    for (final item in toLoad) {
      _photoLoadAttempted.add(item.id);
    }

    final batch = <String, List<ListItemPhoto>>{};
    await Future.wait(
      toLoad.map((item) async {
        try {
          final photos = await service.listItemPhotos(
            groupId: groupId,
            itemId: item.id,
          );
          if (photos.isNotEmpty) batch[item.id] = photos;
        } catch (_) {}
      }),
    );
    if (_disposed || batch.isEmpty) return;
    _photosByItemId.addAll(batch);
    _notify();
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

  void dismissError() {
    _hasError = false;
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
      if (_disposed) return;
      _dirty = true;
    } catch (e) {
      if (_disposed) return;
      _cancelSettle(item.id);
      rethrow;
    }
  }

  Future<void> completeAll() async {
    final service = _service;
    if (service == null) return;
    for (final item in _items.where((i) => !i.checked)) {
      try {
        final repo = await ref.read(listRepositoryProvider.future);
        await repo.updateItemOfflineFirst(
          listId,
          item.id,
          UpdateListItemRequest(checked: true),
        );
        if (_disposed) return;
        _dirty = true;
      } catch (_) {
        break;
      }
    }
  }

  Future<void> uncheckAll() async {
    final service = _service;
    if (service == null) return;
    for (final item in _items.where((i) => i.checked)) {
      try {
        final repo = await ref.read(listRepositoryProvider.future);
        await repo.updateItemOfflineFirst(
          listId,
          item.id,
          UpdateListItemRequest(checked: false),
        );
        if (_disposed) return;
        _dirty = true;
      } catch (_) {
        break;
      }
    }
  }

  /// Adds an item parsed from the composer text. A bare name takes the plain
  /// offline-first create path; a quantity/unit ("2 milk", "1.5 kg flour")
  /// takes the additive offline-first amount path.
  Future<void> addItem(String text) async {
    final service = _service;
    if (service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    final parsed = parseComposerItem(text);
    if (parsed.quantity == 1 && parsed.unit.isEmpty) {
      await repo.createItemOfflineFirst(
        listId,
        CreateListItemRequest(name: parsed.name),
      );
    } else {
      await repo.addItemAmountOfflineFirst(
        listId,
        name: parsed.name,
        amount: parsed.quantity,
        unit: parsed.unit,
      );
    }
    if (_disposed) return;
    _dirty = true;
  }

  /// Adds a restock suggestion via the same offline-first create path as
  /// [addItem]. Not a new write path — only the entry point differs.
  Future<void> addRestockSuggestion(RestockSuggestion suggestion) async {
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.createItemOfflineFirst(
      listId,
      CreateListItemRequest(
        name: suggestion.name,
        canonicalItemId: suggestion.canonicalItemId,
      ),
    );
    if (_disposed) return;
    _dirty = true;
  }

  Future<void> clearItems({required bool onlyChecked}) async {
    final service = _service;
    if (service == null) return;
    await service.clearItems(listId, onlyChecked: onlyChecked);
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.refreshItems(listId);
    if (_disposed) return;
    _dirty = true;
  }

  Future<void> deleteItem(ListItem item) async {
    _cancelSettle(item.id);
    final service = _service;
    if (service == null) return;
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.deleteItemOfflineFirst(listId, item.id);
    if (_disposed) return;
    _sectionsDirty = true;
    _items.remove(item);
    _dirty = true;
    _notify();
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

  Future<void> renameList(String newName) async {
    final service = _service;
    if (service == null) return;
    await service.updateList(listId, UpdateListRequest(name: newName));
    if (_disposed) return;
    _listName = newName;
    _notify();
  }

  /// Returns true if the archive was performed (false if the list isn't loaded
  /// yet), so the screen only navigates away on a real archive.
  Future<bool> archiveList() async {
    final service = _service;
    if (service == null) return false;
    await service.archiveList(listId);
    return true;
  }

  /// Returns true if the delete was performed (false if the list isn't loaded
  /// yet), so the screen only navigates away on a real delete.
  Future<bool> deleteList() async {
    final service = _service;
    if (service == null) return false;
    await service.deleteList(listId);
    final repo = await ref.read(listRepositoryProvider.future);
    await repo.deleteListLocal(listId);
    return true;
  }

  Future<Map<String, dynamic>> getCostSummary() {
    final service = _service;
    if (service == null) {
      return Future<Map<String, dynamic>>.error(StateError('list not loaded'));
    }
    return service.getCostSummary(listId);
  }

  Future<void> generateExpense() async {
    final service = _service;
    if (service == null) return;
    await service.generateExpense(listId);
  }

  // ---- Photos ---------------------------------------------------------------

  Future<void> addItemPhoto(ListItem item) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final attachmentRepo = await ref.read(attachmentRepositoryProvider.future);
    final attachment = await attachmentRepo.uploadAttachment(
      groupId: groupId,
      purpose: 'list_item_photo',
      filename: file.name,
      contentType: 'image/*',
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

    final updated =
        await svc.listItemPhotos(groupId: groupId, itemId: item.id);
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
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
    }
    _dirty = true;
    _notify();

    final repo = await ref.read(listRepositoryProvider.future);
    await repo.reorderItemsOfflineFirst(listId, itemIdsInOrder);
  }

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
    _suggestDebounce =
        Timer(const Duration(milliseconds: 180), () => refreshSuggestions(query));
  }

  /// Refreshes both suggestion sources for the given composer text: the offline
  /// canonical grocery seed (alias-powered) and the backend product history. A
  /// generation counter ensures stale results from a prior keystroke are
  /// silently discarded if a newer query has already started.
  Future<void> refreshSuggestions([String? query]) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final q = (query ?? '').trim();
    final gen = ++_suggestGeneration;

    // Local grocery seed first — alias-powered, on-device.
    final grocery =
        await ref.read(grocerySuggestionServiceProvider).suggest(q, groupId);
    if (_disposed || _suggestGeneration != gen) return;

    // When the composer is empty, prepend restock predictions.
    List<GrocerySuggestion> blended = grocery;
    if (q.isEmpty) {
      try {
        final currentNames = _items
            .where((it) => !it.checked)
            .map((it) => it.name.toLowerCase())
            .toSet();
        final restock = await ref.read(restockServiceProvider).due(
              groupId: groupId,
              currentItemNames: currentNames,
              limit: 5,
            );
        if (_disposed || _suggestGeneration != gen) return;
        if (restock.isNotEmpty) {
          final restockChips = restock.map((r) => GrocerySuggestion(
                canonicalItemId: r.canonicalItemId,
                name: r.name,
                category: '',
                unit: '',
              ));
          blended = [...restockChips, ...grocery];
        }
      } catch (_) {}
    }

    if (_disposed || _suggestGeneration != gen) return;
    _grocerySuggestions = blended;
    _notify();

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      if (_disposed || _suggestGeneration != gen) return;
      final products =
          await service.listProducts(groupId, search: q.isEmpty ? null : q);
      if (_disposed || _suggestGeneration != gen) return;
      _productSuggestions = products.take(8).toList();
      _notify();
    } catch (_) {
      if (!_disposed && _suggestGeneration == gen) {
        _productSuggestions = [];
        _notify();
      }
    }
  }

  // ---- Currency -------------------------------------------------------------

  /// Note: this map intentionally diverges from `utils/format_currency.dart`'s
  /// `currencySymbol` (wider coverage, different CAD/CHF glyphs). Reconciling
  /// the two would change money-screen output and is tracked separately.
  String get currencySymbol {
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CAD': 'CA\$',
      'AUD': 'A\$',
      'NZD': 'NZ\$',
      'CHF': 'CHF',
      'CNY': '¥',
      'HKD': 'HK\$',
      'SGD': 'S\$',
      'SEK': 'kr',
      'NOK': 'kr',
      'DKK': 'kr',
      'INR': '₹',
      'BRL': 'R\$',
      'MXN': 'MX\$',
      'ZAR': 'R',
      'KRW': '₩',
      'TRY': '₺',
    };
    return symbols[_groupCurrency] ?? _groupCurrency;
  }
}
