import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/home_widgets_provider.dart';
import '../../services/widgets/widget_bridge.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/store_provider.dart';
import '../../repositories/list_repository.dart';
import '../../repositories/outbox_error_classifier.dart';
import '../../storage/app_database.dart' show AppDatabase, kGlobalGroupId;
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/animations.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/active_group_context.dart';
import '../../utils/format_currency.dart';
import '../../utils/friendly_error.dart';
import '../../utils/latest_request_guard.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/hub/hub_create_actions.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/odometer.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/store_picker_sheet.dart';
import '../../widgets/list/list_item_line.dart';

/// An item's aisle for the selected store: a display name plus its shopping-path
/// sort order (lower = earlier in the store).
class _ItemAisle {
  final String aisle;
  final int sortOrder;
  const _ItemAisle(this.aisle, this.sortOrder);
}

/// A run of items that live in the same aisle, used when shopping mode is
/// sorted by store layout instead of by list.
class _AisleGroup {
  final String aisle;
  final int sortOrder;
  final List<ListItem> items;
  _AisleGroup(this.aisle, this.sortOrder, this.items);
}

class ShoppingTripScreen extends ConsumerStatefulWidget {
  const ShoppingTripScreen({super.key});

  @override
  ConsumerState<ShoppingTripScreen> createState() => _ShoppingTripScreenState();
}

class _ShoppingTripScreenState extends ConsumerState<ShoppingTripScreen> {
  bool _isLoading = true;
  bool _hasHousehold = true;
  String? _error;
  final List<ItemList> _lists = [];
  final Map<String, List<ListItem>> _itemsByList = {};

  /// Items ticked during this trip. Each tick is saved the moment it is made
  /// (the list, housemates and a killed app all see it); this set only keeps
  /// those lines on screen, struck through, so a mis-tap can be undone.
  final Set<String> _checkedItemIds = {};
  final LatestRequestGuard _loadGuard = LatestRequestGuard();
  final LatestRequestGuard _aisleGuard = LatestRequestGuard();

  /// The Lock Screen / Dynamic Island companion of this trip (iOS 16.2+,
  /// plans/047 stage 7). A no-op elsewhere.
  late final WidgetBridge _liveActivity = ref.read(widgetBridgeProvider);
  bool _liveActivityRunning = false;
  bool _liveActivityEnded = false;
  String _householdName = '';
  String _currency = 'EUR';

  /// Resolved aisle per item id for the selected store. Empty when no store is
  /// chosen (the trip then groups by list). Recomputed when items or store
  /// change.
  Map<String, _ItemAisle> _aisleByItemId = {};
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadGuard.dispose();
    _aisleGuard.dispose();
    // Leaving without finishing takes the Live Activity down with the trip.
    if (_liveActivityRunning && !_liveActivityEnded) {
      unawaited(_liveActivity.endShoppingTrip(
          totalCents: 0, currency: _currency, addExpenseUrl: ''));
    }
    super.dispose();
  }

  /// Starts the Live Activity once the trip has items, then keeps it on the
  /// basket: items left and the running total of priced items.
  void _syncLiveActivity() {
    if (_liveActivityEnded) return;
    final total = _totalItems;
    final left = total - _checkedCount;
    if (!_liveActivityRunning) {
      if (total == 0) return;
      _liveActivityRunning = true;
      unawaited(_liveActivity.startShoppingTrip(
        householdName: _householdName,
        itemsLeft: left,
        itemsTotal: total,
        totalCents: _checkedTotalCents,
        currency: _currency,
      ));
      return;
    }
    unawaited(_liveActivity.updateShoppingTrip(
      itemsLeft: left,
      itemsTotal: total,
      totalCents: _checkedTotalCents,
    ));
  }

  /// The trip is done: the activity ends on "Add expense" when there is a
  /// priced total to log, and goes away otherwise.
  void _endLiveActivity(int totalCents) {
    if (!_liveActivityRunning || _liveActivityEnded) return;
    _liveActivityEnded = true;
    final group = _groupId;
    final url = totalCents > 0 && group != null
        ? 'mitlist:///money?group=$group&add=1&amount_cents=$totalCents'
        : '';
    unawaited(_liveActivity.endShoppingTrip(
      totalCents: url.isEmpty ? 0 : totalCents,
      currency: _currency,
      addExpenseUrl: url,
    ));
  }

  Future<void> _load() async {
    final request = _loadGuard.begin();
    final hadContent = _lists.isNotEmpty || _itemsByList.isNotEmpty;
    setState(() {
      _isLoading = !hadContent;
      _error = null;
    });
    try {
      final groupId = await _resolveGroupId();
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      if (groupId == null) {
        setState(() {
          _lists.clear();
          _itemsByList.clear();
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      _groupId = groupId;
      final groups = await ref.read(cachedGroupsProvider.future);
      for (final g in groups) {
        if (g.id == groupId) {
          _householdName = g.name;
          _currency = g.currency;
        }
      }

      // The trip reads from the local cache, the same rows the lists screens
      // show: painted at once, and offline it is the whole trip. A refresh
      // then updates the cache and the trip is read back from it.
      final repo = await ref.read(listRepositoryProvider.future);
      final hadCache = await _showCachedTrip(
        repo,
        groupId,
        request,
        // Nothing cached yet: keep the skeleton up for the first fetch.
        keepLoadingIfEmpty: !hadContent,
      );
      if (!mounted || !_loadGuard.isCurrent(request)) return;

      try {
        await repo.refreshLists(groupId);
        final listIds = (await repo.getListsByGroupOnce(groupId))
            .where(_isTripList)
            .map((l) => l.id)
            .toList();
        await repo.refreshShoppingTrip(groupId, listIds);
      } catch (e) {
        // Offline the cached trip stands, empty or not (a list can still be
        // made from the empty state). Other failures only matter when there
        // is nothing on screen.
        final offline =
            classifyOutboxError(e) == OutboxErrorDisposition.unreachable;
        if (!offline && !hadCache && !hadContent) rethrow;
      }
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      await _showCachedTrip(repo, groupId, request);
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      final message = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      if (hadContent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Future<String?> _resolveGroupId() async {
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      return resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    } catch (_) {
      return null;
    }
  }

  static bool _isTripList(ItemList list) =>
      list.type == 'shopping' || list.type == 'general';

  /// Shows the trip as the local cache has it: the household's shopping lists
  /// (newest first, like the server orders them) and their open items. Returns
  /// whether the cache had any shopping list at all.
  Future<bool> _showCachedTrip(
    ListRepository repo,
    String groupId,
    int request, {
    bool keepLoadingIfEmpty = false,
  }) async {
    final lists = (await repo.getListsByGroupOnce(groupId))
        .where(_isTripList)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (lists.isEmpty && keepLoadingIfEmpty) return false;
    final itemsByList = <String, List<ListItem>>{};
    for (final list in lists) {
      final open = (await repo.getItemsByListOnce(list.id))
          .where((i) => !i.checked || _checkedItemIds.contains(i.id))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      if (open.isNotEmpty) itemsByList[list.id] = open;
    }
    if (!mounted || !_loadGuard.isCurrent(request)) return lists.isNotEmpty;

    final shownIds = {
      for (final items in itemsByList.values)
        for (final item in items) item.id,
    };
    setState(() {
      _lists
        ..clear()
        ..addAll(lists);
      _itemsByList
        ..clear()
        ..addAll(itemsByList);
      // Items that left the trip (deleted, or synced under their server id)
      // drop out of the basket, and so does one a housemate un-ticked.
      final uncheckedIds = {
        for (final items in itemsByList.values)
          for (final item in items)
            if (!item.checked) item.id,
      };
      _checkedItemIds.removeWhere(
        (id) => !shownIds.contains(id) || uncheckedIds.contains(id),
      );
      _hasHousehold = true;
      _isLoading = false;
      _error = null;
    });
    unawaited(_recomputeAisles());
    _syncLiveActivity();
    return lists.isNotEmpty;
  }

  /// Resolves each open item to an aisle for the selected store so the trip can
  /// be walked in shopping-path order. Runs off the canonical graph + global
  /// store layout; items that don't resolve fall into an "Other" bucket.
  Future<void> _recomputeAisles() async {
    final request = _aisleGuard.begin();
    final storeId = ref.read(selectedStoreIdProvider);
    final groupId = _groupId;
    if (storeId == null || groupId == null) {
      if (mounted &&
          _aisleGuard.isCurrent(request) &&
          _aisleByItemId.isNotEmpty) {
        setState(() => _aisleByItemId = {});
      }
      return;
    }

    await ref.read(grocerySeedProvider.future);
    if (!mounted || !_aisleGuard.isCurrent(request)) return;
    final db = ref.read(appDatabaseProvider);
    final resolver = ref.read(canonicalResolverServiceProvider);
    final linkedIds = [
      for (final items in _itemsByList.values)
        for (final item in items)
          if (item.canonicalItemId != null) item.canonicalItemId!,
    ];
    final ctx = await resolver.prepareContext(groupId, listContext: linkedIds);
    final result = <String, _ItemAisle>{};
    final categoryAisles = await _categoryAislesFor(db, storeId);
    final pending = <String, String>{};

    for (final items in _itemsByList.values) {
      for (final item in items) {
        // Prefer the canonical link stored on the item (set when added from a
        // suggestion — e.g. "Pringles" → potato_chips) so a preserved brand
        // name still sorts into the right aisle. Fall back to resolving the
        // typed text for free-entered items with no link.
        final canonicalId = item.canonicalItemId ??
            (await resolver.resolve(item.name, groupId, context: ctx))
                .canonicalItemId;
        if (canonicalId == null) continue;
        final row = await db.getStoreAisle(
          groupId: groupId,
          storeId: storeId,
          canonicalItemId: canonicalId,
        );
        if (row != null && row.aisle.isNotEmpty) {
          result[item.id] = _ItemAisle(row.aisle, row.sortOrder);
        } else {
          pending[item.id] = canonicalId;
        }
      }
    }

    // Shipped layouts list only a few hundred items per store. Anything not
    // listed walks with its category: it joins the aisle where most of that
    // category's listed items are, instead of piling up under "Other".
    if (pending.isNotEmpty && categoryAisles.isNotEmpty) {
      final items = await db.getCanonicalItemsByIds(pending.values.toSet());
      final categoryById = {for (final item in items) item.id: item.category};
      for (final entry in pending.entries) {
        final aisle = categoryAisles[categoryById[entry.value]];
        if (aisle != null) result[entry.key] = aisle;
      }
    }

    if (!mounted || !_aisleGuard.isCurrent(request)) return;
    setState(() => _aisleByItemId = result);
  }

  /// For each category, the aisle holding most of its items in this store's
  /// layout (household overrides included), at that aisle's first position.
  Future<Map<String, _ItemAisle>> _categoryAislesFor(
    AppDatabase db,
    String storeId,
  ) async {
    final groupId = _groupId;
    final rows = [
      if (groupId != null)
        ...await db.getStoreAisles(groupId: groupId, storeId: storeId),
      ...await db.getStoreAisles(groupId: kGlobalGroupId, storeId: storeId),
    ];
    if (rows.isEmpty) return const {};
    final items =
        await db.getCanonicalItemsByIds(rows.map((r) => r.canonicalItemId));
    final categoryById = {for (final item in items) item.id: item.category};
    final votes = <String, Map<String, int>>{};
    final firstSort = <String, int>{};
    for (final row in rows) {
      final category = categoryById[row.canonicalItemId];
      if (category == null || category.isEmpty || row.aisle.isEmpty) continue;
      final counts = votes.putIfAbsent(category, () => {});
      counts[row.aisle] = (counts[row.aisle] ?? 0) + 1;
      final sort = firstSort[row.aisle];
      if (sort == null || row.sortOrder < sort) {
        firstSort[row.aisle] = row.sortOrder;
      }
    }
    return {
      for (final entry in votes.entries)
        entry.key: () {
          final aisle = entry.value.entries
              .reduce((a, b) => b.value > a.value ? b : a)
              .key;
          return _ItemAisle(aisle, firstSort[aisle] ?? 100000);
        }(),
    };
  }

  /// Groups all open items by aisle, ordered by shopping path. Items without a
  /// known aisle for this store collect under "Other" at the end.
  List<_AisleGroup> _buildAisleGroups(String otherAisle) {
    final byAisle = <String, _AisleGroup>{};
    for (final items in _itemsByList.values) {
      for (final item in items) {
        final info = _aisleByItemId[item.id];
        final name = info?.aisle ?? otherAisle;
        final sort = info?.sortOrder ?? 100000;
        final group = byAisle.putIfAbsent(
          name,
          () => _AisleGroup(name, sort, []),
        );
        group.items.add(item);
        // A group sorts by its earliest item on the shopping path.
        if (sort < group.sortOrder) {
          byAisle[name] = _AisleGroup(name, sort, group.items);
        }
      }
    }
    final groups = byAisle.values.toList()
      ..sort((a, b) {
        if (a.aisle == otherAisle) return 1;
        if (b.aisle == otherAisle) return -1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    for (final g in groups) {
      g.items.sort((x, y) {
        final sx = _aisleByItemId[x.id]?.sortOrder ?? 100000;
        final sy = _aisleByItemId[y.id]?.sortOrder ?? 100000;
        return sx.compareTo(sy);
      });
    }
    return groups;
  }

  /// Ticks or un-ticks an item and saves it at once, offline-first like a
  /// tick on the list itself. The line stays on the trip either way.
  Future<void> _toggleItem(String itemId) async {
    String? listId;
    for (final entry in _itemsByList.entries) {
      if (entry.value.any((i) => i.id == itemId)) listId = entry.key;
    }
    if (listId == null) return;
    final checked = !_checkedItemIds.contains(itemId);
    // A light tap of feedback every time something lands in the basket.
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      checked ? _checkedItemIds.add(itemId) : _checkedItemIds.remove(itemId);
    });
    _syncLiveActivity();
    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.updateItemOfflineFirst(
        listId,
        itemId,
        UpdateListItemRequest(checked: checked),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        checked ? _checkedItemIds.remove(itemId) : _checkedItemIds.add(itemId);
      });
      _syncLiveActivity();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!)),
        ),
      );
    }
  }

  /// Wraps the trip up. Every tick is already saved, so this only closes it:
  /// the stamp, the Live Activity, an offer to log what it cost, and the
  /// ticked lines leave the trip.
  Future<void> _finishTrip() async {
    if (_checkedItemIds.isEmpty) return;
    var count = 0;
    var totalCents = 0;
    for (final items in _itemsByList.values) {
      for (final item in items) {
        if (_checkedItemIds.contains(item.id)) {
          count++;
          totalCents += item.priceCents ?? 0;
        }
      }
    }
    unawaited(HapticFeedback.heavyImpact());
    _showDoneStamp(count, totalCents);
    _endLiveActivity(totalCents);
    setState(() => _checkedItemIds.clear());
    await _load();
    if (!mounted || totalCents <= 0) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n
            .shoppingTripItemsWorthDone(formatCurrency(totalCents, _currency))),
        action: SnackBarAction(
          label: l10n.shoppingTripAddExpense,
          onPressed: () => context.pushNamed('money'),
        ),
      ),
    );
  }

  /// The trip's empty state: make a shopping list, put something on it, and
  /// come back to a trip that has items to shop for.
  Future<void> _createList() async {
    unawaited(HapticFeedback.lightImpact());
    await createListAndOpen(context, initialType: 'shopping');
    if (mounted) await _load();
  }

  void _showDoneStamp(int count, int totalCents) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _DoneStamp(
        count: count,
        totalCents: totalCents,
        currency: _currency,
        onComplete: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  String _listName(String listId) {
    final l10n = AppLocalizations.of(context)!;
    final list = _lists.cast<ItemList?>().firstWhere(
          (l) => l?.id == listId,
          orElse: () => null,
        );
    return list?.name ?? l10n.shoppingTripFallbackList;
  }

  int get _totalItems {
    return _itemsByList.values.fold(0, (sum, items) => sum + items.length);
  }

  int get _checkedCount => _checkedItemIds.length;

  int get _checkedTotalCents {
    var cents = 0;
    for (final items in _itemsByList.values) {
      for (final item in items) {
        if (_checkedItemIds.contains(item.id)) {
          cents += item.priceCents ?? 0;
        }
      }
    }
    return cents;
  }

  bool get _showBasketBar =>
      !_isLoading &&
      _hasHousehold &&
      _error == null &&
      _lists.isNotEmpty &&
      _totalItems > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    // Re-plan the aisle order whenever the chosen store changes.
    ref.listen<String?>(selectedStoreIdProvider, (_, __) => _recomputeAisles());

    return Scaffold(
      appBar: MitlistAppBar(
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.shoppingTripAppBarTitle),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'storeOutline'),
            tooltip: l10n.shoppingTripChooseStore,
            onPressed: () => showStorePicker(context),
          ),
        ],
      ),
      body: _buildBody(textTheme),
      bottomNavigationBar: _showBasketBar
          ? _BasketBar(
              checkedCount: _checkedCount,
              totalCount: _totalItems,
              totalCents: _checkedTotalCents,
              currency: _currency,
              onDone: _checkedCount > 0 ? _finishTrip : null,
            )
          : null,
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return _buildSkeleton();
    }
    if (!_hasHousehold) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: const AppIcon(name: 'homeOutline'),
          title: l10n.commonNoHousehold,
          description: l10n.commonCreateJoinHousehold,
          actions: [
            AppButton(
              text: l10n.commonGoToHouseholds,
              onPressed: () => context.goNamed('groupsList'),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/404.lottie',
          icon: const AppIcon(name: 'alertCircleOutline'),
          title: l10n.commonSomethingWentWrong,
          description: _error,
          actions: [
            AppButton(
              variant: AppButtonVariant.outline,
              text: l10n.commonRetry,
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    if (_lists.isEmpty) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/checklist.lottie',
          icon: const AppIcon(name: 'shoppingBagOutline'),
          title: l10n.shoppingTripNoLists,
          description: l10n.shoppingTripNoListsDesc,
          actions: [
            AppButton(
              text: l10n.shoppingTripCreateList,
              icon: const AppIcon(name: 'plus'),
              onPressed: _createList,
            ),
          ],
        ),
      );
    }
    if (_totalItems == 0) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/Checkmark.lottie',
          icon: const AppIcon(name: 'checkCircleOutline'),
          title: l10n.shoppingTripAllCaughtUp,
          description: l10n.shoppingTripAllCaughtUpDesc,
        ),
      );
    }

    final storeId = ref.watch(selectedStoreIdProvider);
    if (storeId != null) {
      return RefreshIndicator(onRefresh: _load, child: _buildAisleView());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
        itemCount: _itemsByList.length,
        itemBuilder: (context, index) {
          final listId = _itemsByList.keys.elementAt(index);
          final items = _itemsByList[listId]!;
          final listName = _listName(listId);
          return _ListSection(
            listName: listName,
            items: items,
            checkedIds: _checkedItemIds,
            currencySymbol: currencySymbol(_currency),
            onToggle: _toggleItem,
            onTapList: () => context
                .pushNamed('listDetail', pathParameters: {'listId': listId}),
          );
        },
      ),
    );
  }

  /// Trip grouped by store aisle in shopping-path order. A header banner names
  /// the store and offers a tap target to change it.
  Widget _buildAisleView() {
    final l10n = AppLocalizations.of(context)!;
    final groups = _buildAisleGroups(l10n.aisleOther);
    final colorScheme = Theme.of(context).colorScheme;
    final storeName = ref.watch(storeCatalogProvider).maybeWhen(
          data: (stores) {
            final id = ref.read(selectedStoreIdProvider);
            for (final s in stores) {
              if (s.id == id) return s.name;
            }
            return null;
          },
          orElse: () => null,
        );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              0,
              MitlistSpacing.md,
              MitlistSpacing.sm,
            ),
            child: Semantics(
              button: true,
              label: l10n.shoppingTripChooseStore,
              child: InkWell(
                onTap: () => showStorePicker(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      AppIcon(
                        name: 'storeOutline',
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: Text(
                          storeName == null
                              ? l10n.shoppingTripSortedByAisles
                              : l10n.shoppingTripSortedByStoreAisles(storeName),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ),
                      Text(
                        l10n.commonChange,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final group = groups[index - 1];
        return _AisleSection(
          aisle: group.aisle,
          items: group.items,
          checkedIds: _checkedItemIds,
          currencySymbol: currencySymbol(_currency),
          onToggle: _toggleItem,
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      children: [
        const AppSkeleton(width: 140, height: 16),
        const SizedBox(height: MitlistSpacing.md),
        for (var i = 0; i < 8; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: MitlistSpacing.md),
            child: Row(
              children: [
                AppSkeleton(width: 22, height: 22),
                SizedBox(width: MitlistSpacing.md),
                Expanded(
                  child: AppSkeleton(width: double.infinity, height: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The bar under the trip: a thin progress line, how much is in the basket
/// (and what it cost, when items carry prices), and "Finish trip" within
/// thumb reach. Ticks are saved as they happen, so finishing is optional.
class _BasketBar extends StatelessWidget {
  const _BasketBar({
    required this.checkedCount,
    required this.totalCount,
    required this.totalCents,
    required this.currency,
    required this.onDone,
  });

  final int checkedCount;
  final int totalCount;
  final int totalCents;
  final String currency;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final fraction =
        totalCount == 0 ? 0.0 : (checkedCount / totalCount).clamp(0.0, 1.0);
    final countStyle = TextStyle(
      fontFamily: MitlistTypography.monoFamily,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.0,
      color:
          checkedCount > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
    );
    final priceSuffix =
        totalCents > 0 ? '  ·  ${formatCurrency(totalCents, currency)}' : '';

    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surface),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: l10n.listDetailProgress(checkedCount, totalCount),
              child: SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: colorScheme.outlineVariant),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: disableAnimations
                          ? Duration.zero
                          : MitlistAnimations.medium,
                      curve: MitlistAnimations.easeEnter,
                      widthFactor: fraction,
                      heightFactor: 1,
                      alignment: Alignment.centerLeft,
                      child: ColoredBox(color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.md,
                MitlistSpacing.sm,
                MitlistSpacing.md,
                MitlistSpacing.sm,
              ),
              child: Row(
                children: [
                  MitlistOdometer(value: checkedCount, textStyle: countStyle),
                  const SizedBox(width: MitlistSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.shoppingTripBasketBar(totalCount, priceSuffix),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  AppButton(
                    key: const ValueKey('trip-finish'),
                    text: l10n.shoppingTripFinish,
                    onPressed: onDone,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A heading over a run of trip lines: a list's name (tap to open it) or a
/// store aisle.
class _TripHeading extends StatelessWidget {
  const _TripHeading({required this.title, this.icon, this.onTap});

  final String title;
  final String? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            if (icon != null) ...[
              AppIcon(name: icon!, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: MitlistSpacing.sm),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null)
              AppIcon(
                name: 'chevronRight',
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Trip lines read like the list itself; on a trip the whole line is the
/// target, since a hand holding a basket aims badly.
List<Widget> _tripLines(
  List<ListItem> items,
  Set<String> checkedIds,
  ValueChanged<String> onToggle,
  String currencySymbol,
) =>
    [
      for (final item in items)
        ListItemLine(
          key: ValueKey(item.id),
          item: item,
          checked: checkedIds.contains(item.id),
          currencySymbol: currencySymbol,
          onToggle: (_) => onToggle(item.id),
          onEdit: () => onToggle(item.id),
        ),
    ];

class _ListSection extends StatelessWidget {
  final String listName;
  final List<ListItem> items;
  final Set<String> checkedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onTapList;
  final String currencySymbol;

  const _ListSection({
    required this.listName,
    required this.items,
    required this.checkedIds,
    required this.onToggle,
    required this.onTapList,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TripHeading(title: listName, onTap: onTapList),
          ..._tripLines(items, checkedIds, onToggle, currencySymbol),
        ],
      ),
    );
  }
}

/// A store-aisle section, in shopping-path order. Items may span several
/// source lists.
class _AisleSection extends StatelessWidget {
  final String aisle;
  final List<ListItem> items;
  final Set<String> checkedIds;
  final ValueChanged<String> onToggle;
  final String currencySymbol;

  const _AisleSection({
    required this.aisle,
    required this.items,
    required this.checkedIds,
    required this.onToggle,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TripHeading(title: aisle, icon: 'tagOutline'),
          ..._tripLines(items, checkedIds, onToggle, currencySymbol),
        ],
      ),
    );
  }
}

/// The completion "stamp" — a rotated, hard-bordered DONE mark that thwacks
/// onto the screen, holds, then lifts away. With reduced motion it simply
/// appears and fades, no scale or rotation.
class _DoneStamp extends StatefulWidget {
  const _DoneStamp({
    required this.count,
    required this.totalCents,
    required this.currency,
    required this.onComplete,
  });

  final int count;
  final int totalCents;
  final String currency;
  final VoidCallback onComplete;

  @override
  State<_DoneStamp> createState() => _DoneStampState();
}

class _DoneStampState extends State<_DoneStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
    // Read reduced-motion next frame, once we have a MediaQuery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduceMotion = MediaQuery.of(context).disableAnimations;
      _controller.duration = _reduceMotion
          ? const Duration(milliseconds: 900)
          : const Duration(milliseconds: 1250);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final priceStr = widget.totalCents > 0
        ? formatCurrency(widget.totalCents, widget.currency)
        : null;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          double opacity;
          double scale;
          double rotation;

          if (_reduceMotion) {
            // Appear, hold, fade. No movement.
            opacity = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25);
            scale = 1.0;
            rotation = -0.08;
          } else {
            const enter = 0.22;
            const exitStart = 0.72;
            if (t < enter) {
              final p = Curves.easeOutBack.transform(t / enter);
              opacity = (t / enter).clamp(0.0, 1.0);
              scale = 1.5 - 0.5 * p;
              rotation = -0.20 + 0.12 * p;
            } else if (t < exitStart) {
              opacity = 1.0;
              scale = 1.0;
              rotation = -0.08;
            } else {
              final p = (t - exitStart) / (1.0 - exitStart);
              opacity = (1.0 - p).clamp(0.0, 1.0);
              scale = 1.0 + 0.08 * p;
              rotation = -0.08;
            }
          }

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              color: colorScheme.scrim
                  .withValues(alpha: 0.18 * opacity.clamp(0.0, 1.0)),
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.xl,
            vertical: MitlistSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.primary, width: 4),
            boxShadow: MitlistShadows.shadowStrong,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.shoppingTripStampDone,
                style: textTheme.displaySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: MitlistSpacing.xs),
              Text(
                l10n.shoppingTripStampItems(widget.count),
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (priceStr != null) ...[
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  priceStr,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
