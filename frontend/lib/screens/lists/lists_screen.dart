import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show BottomNavScaffold, currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../sheets/create_list_sheet.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../utils/shell_tab_load.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';
import 'list_detail_screen.dart';

import '../../widgets/app_toast.dart';
enum _SortOption { newest, oldest, az, mostItems }

enum _FilterOption { all, shopping, todo, custom }

enum _ListMenuAction {
  shoppingTrip,
  toggleView,
  scanReceipt,
  sortNewest,
  sortOldest,
  sortAz,
  sortMostItems,
}

class ListsScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const ListsScreen({super.key, this.groupId});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  static const int _pageLimit = 50;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  /// Server-side pagination cursor. Tracked separately from [_lists], which is
  /// fed by the local DB stream and can contain rows the server pages don't
  /// (archived lists, locally cached later pages) — using its length as the
  /// offset skipped or duplicated server pages.
  int _serverOffset = 0;
  String? _error;
  String? _loadMoreError;
  final List<ItemList> _lists = [];
  StreamSubscription<List<ItemList>>? _listsSub;
  final ScrollController _scrollController = ScrollController();
  bool _isGrid = true;
  _FilterOption _filter = _FilterOption.all;
  String _searchQuery = '';
  bool _showSearch = false;
  _SortOption _sort = _SortOption.newest;
  Timer? _searchTimer;
  bool _hasHousehold = false;
  final TextEditingController _searchController = TextEditingController();

  bool _tabLoadStarted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    SharedPreferences.getInstance().then((prefs) {
      final savedGrid = prefs.getBool('lists_is_grid');
      final savedFilter = prefs.getInt('lists_filter');
      final savedSort = prefs.getInt('lists_sort');
      if (mounted) {
        setState(() {
          if (savedGrid != null) _isGrid = savedGrid;
          if (savedFilter != null &&
              savedFilter < _FilterOption.values.length) {
            _filter = _FilterOption.values[savedFilter];
          }
          if (savedSort != null && savedSort < _SortOption.values.length) {
            _sort = _SortOption.values[savedSort];
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateTabIfNeeded());
  }

  void _activateTabIfNeeded() {
    if (_tabLoadStarted || !mounted) return;
    final insideShell =
        context.findAncestorWidgetOfExactType<BottomNavScaffold>() != null;
    if (insideShell && !shouldActivateShellTab(ref, listsShellTabIndex)) {
      return;
    }
    _tabLoadStarted = true;
    ref.read(grocerySeedProvider);
    _loadLists();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _listsSub?.cancel();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ListsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Before the tab has activated nothing is loaded yet; _activateTabIfNeeded
    // will do the (correctly scoped) first load.
    if (oldWidget.groupId != widget.groupId && _tabLoadStarted) {
      _loadLists();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    if (_scrollController.position.extentAfter < 400) {
      _loadMoreLists();
    }
  }

  Future<String?> _resolveGroupId() async {
    final explicitGroupId = widget.groupId;
    if (isValidGroupId(explicitGroupId)) {
      return explicitGroupId;
    }

    await ref.read(currentGroupIdProvider.notifier).ensureLoaded();
    final groups = await ref.read(cachedGroupsProvider.future);
    final groupId = resolveActiveGroupId(
      groups,
      ref.read(currentGroupIdProvider),
    );
    return isValidGroupId(groupId) ? groupId : null;
  }

  Future<void> _loadLists() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _error = null;
      _loadMoreError = null;
      _hasMore = true;
    });

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      final effectiveGroupId = await _resolveGroupId();
      if (effectiveGroupId == null) {
        if (!mounted) return;
        setState(() {
          _lists.clear();
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }

      // Subscribe to cached DB stream for instant paint.
      await _listsSub?.cancel();
      _listsSub = repo
          .watchListsByGroup(effectiveGroupId)
          .listen((List<ItemList> data) {
        if (!mounted) return;
        setState(() {
          _lists
            ..clear()
            ..addAll(data);
        });
      });

      final List<ItemList> cached =
          await repo.getListsByGroupOnce(effectiveGroupId);
      if (!mounted) return;
      final hadCache = cached.isNotEmpty;
      setState(() {
        _lists
          ..clear()
          ..addAll(cached);
        _hasHousehold = true;
        // Only show skeleton on true first-load (no cache).
        _isLoading = !hadCache;
        _error = null;
      });

      int fetchedCount = 0;
      try {
        fetchedCount = await repo.refreshLists(
          effectiveGroupId,
          limit: _pageLimit,
          offset: 0,
        );
      } catch (e) {
        // If we have cached content, don't replace it with an error state.
        if (!hadCache && mounted) {
          setState(() {
            _error = l10n.commonFailedToLoad;
          });
        }
      }

      if (mounted) {
        setState(() {
          _serverOffset = fetchedCount;
          _hasMore = fetchedCount == _pageLimit;
          _isLoading = false;
          _error = _lists.isEmpty ? _error : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreLists() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      final effectiveGroupId = await _resolveGroupId();
      if (effectiveGroupId == null) return;
      final fetchedCount = await repo.refreshLists(
        effectiveGroupId,
        limit: _pageLimit,
        offset: _serverOffset,
      );

      if (mounted) {
        setState(() {
          _serverOffset += fetchedCount;
          _hasHousehold = true;
          _hasMore = fetchedCount == _pageLimit;
          _isLoadingMore = false;
          _loadMoreError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadMoreError = l10n.commonFailedToLoad;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value;
        });
      }
    });
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<ItemList> get _filteredLists {
    var result = List<ItemList>.from(_lists.where((l) => !l.isArchived));

    if (_filter != _FilterOption.all) {
      final wanted = switch (_filter) {
        _FilterOption.shopping => 'shopping',
        _FilterOption.todo => 'todo',
        _FilterOption.custom => 'custom',
        _FilterOption.all => '',
      };
      result = result.where((l) => l.type.toLowerCase() == wanted).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((l) {
        if (l.name.toLowerCase().contains(query)) return true;
        return l.itemPreview.any((p) => p.toLowerCase().contains(query));
      }).toList();
    }

    switch (_sort) {
      case _SortOption.newest:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortOption.oldest:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case _SortOption.az:
        result.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.mostItems:
        result.sort(_compareByItemCount);
        break;
    }

    return result;
  }

  int _compareByItemCount(ItemList a, ItemList b) {
    final aCount = a.itemCount;
    final bCount = b.itemCount;
    if (aCount == null && bCount == null) return 0;
    if (aCount == null) return 1;
    if (bCount == null) return -1;
    return bCount.compareTo(aCount);
  }

  String? _filterToListType() => switch (_filter) {
        _FilterOption.shopping => 'shopping',
        _FilterOption.todo => 'todo',
        _FilterOption.custom => 'custom',
        _FilterOption.all => null,
      };

  Future<void> _showCreateSheet() async {
    unawaited(Haptics.light());
    final created = await CreateListSheet.show(
      context,
      initialGroupId: widget.groupId,
      initialType: _filterToListType(),
    );
    if (created == true) {
      await _loadLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen(shellVisitedTabsProvider, (previous, next) {
      _activateTabIfNeeded();
    });
    ref.listen<String?>(currentGroupIdProvider, (previous, next) {
      if (previous != next && _tabLoadStarted) {
        _loadLists();
      }
    });

    return PopScope(
      // System back while searching closes the search instead of leaving the
      // screen, matching the in-app back arrow.
      canPop: !_showSearch,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSearch();
      },
      child: _buildScaffold(l10n),
    );
  }

  Widget _buildScaffold(AppLocalizations l10n) {
    return Scaffold(
      appBar: MitlistAppBar(
        centerTitle: false,
        leading: _showSearch
            ? IconButton(
                icon: const AppIcon(name: 'arrowLeft'),
                tooltip: l10n.commonBack,
                onPressed: _clearSearch,
              )
            : null,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.listSearchLabel,
                  hintText: l10n.listSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(
                l10n.listAppBarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const AppIcon(name: 'magnifyingGlass'),
              tooltip: l10n.commonSearch,
              onPressed: () => setState(() => _showSearch = true),
            ),
            PopupMenuButton<_ListMenuAction>(
              icon: const AppIcon(name: 'ellipsisVertical'),
              tooltip: l10n.commonOptions,
              onSelected: (action) {
                setState(() {
                  switch (action) {
                    case _ListMenuAction.shoppingTrip:
                    case _ListMenuAction.scanReceipt:
                      break;
                    case _ListMenuAction.toggleView:
                      unawaited(Haptics.light());
                      _isGrid = !_isGrid;
                      SharedPreferences.getInstance()
                          .then((p) => p.setBool('lists_is_grid', _isGrid));
                      break;
                    case _ListMenuAction.sortNewest:
                      _sort = _SortOption.newest;
                      SharedPreferences.getInstance()
                          .then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                    case _ListMenuAction.sortOldest:
                      _sort = _SortOption.oldest;
                      SharedPreferences.getInstance()
                          .then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                    case _ListMenuAction.sortAz:
                      _sort = _SortOption.az;
                      SharedPreferences.getInstance()
                          .then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                    case _ListMenuAction.sortMostItems:
                      _sort = _SortOption.mostItems;
                      SharedPreferences.getInstance()
                          .then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                  }
                });
                if (action == _ListMenuAction.scanReceipt) {
                  context.pushNamed('scanner');
                } else if (action == _ListMenuAction.shoppingTrip) {
                  context.pushNamed('shoppingTrip');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ListMenuAction.shoppingTrip,
                  child: Row(
                    children: [
                      AppIcon(
                          name: 'shoppingCart',
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: MitlistSpacing.sm),
                      Text(l10n.listShoppingTripTooltip),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _ListMenuAction.toggleView,
                  child: Row(
                    children: [
                      AppIcon(
                          name: _isGrid ? 'listBullet' : 'squares2x2',
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: MitlistSpacing.sm),
                      Text(_isGrid
                          ? l10n.listSortListView
                          : l10n.listSortGridView),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _ListMenuAction.scanReceipt,
                  child: Row(
                    children: [
                      AppIcon(
                          name: 'camera',
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: MitlistSpacing.sm),
                      Text(l10n.listScanTooltip),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    l10n.listSortLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortNewest,
                  checked: _sort == _SortOption.newest,
                  child: Text(l10n.listSortNewest),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortOldest,
                  checked: _sort == _SortOption.oldest,
                  child: Text(l10n.listSortOldest),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortAz,
                  checked: _sort == _SortOption.az,
                  child: Text(l10n.listSortAZ),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortMostItems,
                  checked: _sort == _SortOption.mostItems,
                  child: Text(l10n.listSortMostItems),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
      floatingActionButton: AppButton(
        size: AppButtonSize.lg,
        onPressed: _hasHousehold
            ? _showCreateSheet
            : () => context.goNamed('groupsList'),
        icon: const AppIcon(name: 'plus'),
        text: l10n.listNewList,
        tooltip: l10n.listNewList,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _lists.isEmpty) {
      return _buildSkeleton();
    }

    if (_error != null && _lists.isEmpty) {
      return RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _loadLists,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final l10n = AppLocalizations.of(context)!;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppAlert(type: AppAlertType.error, message: _error!),
                        const SizedBox(height: MitlistSpacing.md),
                        AppButton(
                          text: l10n.commonRetry,
                          icon: const AppIcon(name: 'arrowPath'),
                          onPressed: _loadLists,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    if (!_hasHousehold) {
      return _buildNoHouseholdState();
    }

    final lists = _filteredLists;
    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              MitlistSpacing.md,
              MitlistSpacing.md,
              0,
            ),
            child: AppAlert(type: AppAlertType.error, message: _error!),
          ),
        _buildChipBar(),
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: _loadLists,
            child: lists.isEmpty
                ? _buildEmptyState()
                : (_isGrid ? _buildGrid(lists) : _buildList(lists)),
          ),
        ),
      ],
    );
  }

  String _chipLabel(_FilterOption option, String base) {
    if (_isLoading) return base;
    final active = _lists.where((l) => !l.isArchived);
    final count = switch (option) {
      _FilterOption.all => active.length,
      _FilterOption.shopping =>
        active.where((l) => l.type.toLowerCase() == 'shopping').length,
      _FilterOption.todo =>
        active.where((l) => l.type.toLowerCase() == 'todo').length,
      _FilterOption.custom =>
        active.where((l) => l.type.toLowerCase() == 'custom').length,
    };
    return count > 0 ? '$base ($count)' : base;
  }

  Widget _buildChipBar() {
    if (!_hasHousehold) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final labelMap = <_FilterOption, String>{
      _FilterOption.all: l10n.listFilterAll,
      _FilterOption.shopping: l10n.listFilterShopping,
      _FilterOption.todo: l10n.listFilterTodo,
      _FilterOption.custom: l10n.listFilterCustom,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.sm,
      ),
      child: Row(
        children: labelMap.entries.map((entry) {
          final option = entry.key;
          final label = _chipLabel(option, entry.value);
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: AppChip(
              label: label,
              selected: _filter == option,
              onSelected: (_) {
                setState(() => _filter = option);
                SharedPreferences.getInstance()
                    .then((p) => p.setInt('lists_filter', _filter.index));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Shared grid geometry so the skeleton and the loaded grid agree on column
  // count and tile shape — prevents a layout shift when content replaces the
  // loading state.
  static const double _minTileWidth = 190.0;

  /// Extra bottom inset so the floating "New list" button never covers the
  /// last row's actions.
  static const double _fabClearance = 72.0;

  static const EdgeInsets _contentPadding = EdgeInsets.fromLTRB(
    MitlistSpacing.md,
    MitlistSpacing.md,
    MitlistSpacing.md,
    MitlistSpacing.md + _fabClearance,
  );

  static int _gridColumns(double maxWidth) =>
      (maxWidth / _minTileWidth).floor().clamp(2, 5);

  // Slightly taller tiles than before: the bottom action row grew to honor
  // the 44px touch-target floor.
  double _gridAspectRatio(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0) > 1.2 ? 0.68 : 0.74;

  Widget _buildGrid(List<ItemList> lists) {
    final itemCount =
        lists.length + (_isLoadingMore || _loadMoreError != null ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumns(constraints.maxWidth);
        final aspectRatio = _gridAspectRatio(context);

        return GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _contentPadding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: MitlistSpacing.md,
            crossAxisSpacing: MitlistSpacing.md,
            childAspectRatio: aspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= lists.length) return _buildPaginationFooter();
            return ListEntrance(
              index: index,
              child: _ListCard(
                list: lists[index],
                onChanged: () => unawaited(_loadLists()),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildList(List<ItemList> lists) {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _contentPadding,
      itemCount:
          lists.length + (_isLoadingMore || _loadMoreError != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: MitlistSpacing.md),
      itemBuilder: (_, index) {
        if (index >= lists.length) return _buildPaginationFooter();
        return ListEntrance(
          index: index,
          child: _ListCard(
            list: lists[index],
            onChanged: () => unawaited(_loadLists()),
          ),
        );
      },
    );
  }

  Widget _buildPaginationFooter() {
    final l10n = AppLocalizations.of(context)!;
    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAlert(type: AppAlertType.error, message: _loadMoreError!),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.commonRetry,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              onPressed: _loadMoreLists,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    final emptyTitle = switch (_filter) {
      _FilterOption.shopping => l10n.listEmptyShopping,
      _FilterOption.todo => l10n.listEmptyTodo,
      _FilterOption.custom => l10n.listEmptyCustom,
      _FilterOption.all => l10n.listEmptyAll,
    };
    final emptyDesc = switch (_filter) {
      _FilterOption.shopping => l10n.listEmptyShoppingDesc,
      _FilterOption.todo => l10n.listEmptyTodoDesc,
      _FilterOption.custom => l10n.listEmptyCustomDesc,
      _FilterOption.all => l10n.listEmptyAllDesc,
    };
    final actionLabel = switch (_filter) {
      _FilterOption.shopping => l10n.listCreateShopping,
      _FilterOption.todo => l10n.listCreateTodo,
      _FilterOption.custom => l10n.listCreateCustom,
      _FilterOption.all => l10n.listCreateFirst,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: _searchQuery.isNotEmpty
                    ? _buildSearchEmptyState()
                    : AppEmptyState(
                        lottieAsset:
                            'assets/animations/lottie/checklist.lottie',
                        icon: const AppIcon(name: 'queueList'),
                        title: emptyTitle,
                        description: emptyDesc,
                        actions: [
                          AppButton(
                            text: actionLabel,
                            icon: const AppIcon(name: 'plus'),
                            onPressed: _showCreateSheet,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          name: 'magnifyingGlass',
          size: 40,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          l10n.listNoMatch(_searchQuery),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          l10n.listSearchDesc,
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppButton(
          text: l10n.commonClearSearch,
          variant: AppButtonVariant.outline,
          onPressed: _clearSearch,
        ),
      ],
    );
  }

  Widget _buildNoHouseholdState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: const AppIcon(name: 'userGroup'),
          title: l10n.commonNoHousehold,
          description: l10n.commonCreateJoinHousehold,
          actions: [
            AppButton(
              text: l10n.commonGoToHouseholds,
              onPressed: () => context.goNamed('groupsList'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumns(constraints.maxWidth);
        return GridView.count(
          crossAxisCount: columns,
          padding: const EdgeInsets.all(MitlistSpacing.md),
          mainAxisSpacing: MitlistSpacing.md,
          crossAxisSpacing: MitlistSpacing.md,
          childAspectRatio: _gridAspectRatio(context),
          children: List.generate(columns * 2, (_) => const _SkeletonCard()),
        );
      },
    );
  }
}

class _ListCard extends ConsumerWidget {
  final ItemList list;
  final VoidCallback onChanged;

  const _ListCard({required this.list, required this.onChanged});

  String _semanticLabel() {
    final parts = <String>[list.name];
    final lines = list.itemPreview
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(4);
    if (lines.isNotEmpty) {
      parts.add(lines.join(', '));
    }
    return parts.join('. ');
  }

  /// Card actions in a bottom sheet — the same grammar as item long-press on
  /// the detail screen, and reachable from both the visible menu button and
  /// long-pressing the card.
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    unawaited(Haptics.medium());
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final action = await showAppBottomSheet<String>(
      context: context,
      title: list.name,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const AppIcon(name: 'pencil'),
            title: Text(l10n.commonRename),
            onTap: () => Navigator.of(context).pop('rename'),
          ),
          ListTile(
            leading: AppIcon(name: 'trash', color: colorScheme.error),
            title: Text(
              l10n.listDeleteTitle,
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
          const SizedBox(height: MitlistSpacing.sm),
        ],
      ),
    );
    if (action == 'rename' && context.mounted) {
      await _renameList(context, ref);
    } else if (action == 'delete' && context.mounted) {
      await _deleteList(context, ref);
    }
  }

  Future<void> _renameList(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: list.name);
    final newName = await showAppDialog<String>(
      context: context,
      title: l10n.listRenameTitle,
      body: AppInput(
        label: l10n.commonListName,
        controller: controller,
        maxLength: 100,
        textInputAction: TextInputAction.done,
      ),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        AppButton(
          text: l10n.commonSave,
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == list.name) return;
    try {
      final svc = await ref.read(listServiceProviderAsync.future);
      await svc.updateList(list.id, UpdateListRequest(name: newName));
      onChanged();
    } catch (_) {
      if (context.mounted) {
        unawaited(Haptics.failure());
        AppToast.error(context, l10n.listCouldNotRename);
      }
    }
  }

  Future<void> _deleteList(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.listDeleteTitle,
      body: Text(l10n.listDeleteBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;
    try {
      final svc = await ref.read(listServiceProviderAsync.future);
      await svc.deleteList(list.id);
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.deleteListLocal(list.id);
      onChanged();
    } catch (_) {
      if (context.mounted) {
        unawaited(Haptics.failure());
        AppToast.error(context, l10n.listCouldNotDelete);
      }
    }
  }

  /// Opens the list detail; with [composer] set it lands with the item
  /// composer focused. This replaced a cramped one-shot quick-add dialog that
  /// duplicated (a worse, online-only version of) the detail composer.
  Future<void> _openList(BuildContext context,
      {bool composer = false}) async {
    final changed = await context.pushNamed<bool>(
      'listDetail',
      pathParameters: {'listId': list.id},
      extra: ListDetailRouteArgs(
        listName: list.name,
        autoFocusComposer: composer,
      ),
    );
    if (changed == true) onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accent = ListTileAccent.fromSeed(
      list.id,
      Theme.of(context).brightness,
    );
    // Three single-line previews: with the 44px action row, four lines can
    // overflow the grid tile when the title also wraps to three lines.
    final previewLines = list.itemPreview
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    final snippetColor = accent.snippetOnTile;
    final isTodo = list.type.toLowerCase() == 'todo';

    final groups = ref.watch(cachedGroupsProvider).valueOrNull ?? const [];
    // Only worth a line when the user actually belongs to several households;
    // for the common single-household case it repeated the same name on every
    // card.
    final groupName = groups.length > 1
        ? groups.where((g) => g.id == list.groupId).firstOrNull?.name
        : null;

    // "N left" from live local counts; lists never opened on this device have
    // no local items yet, so fall back to the server's total item count.
    final counts =
        ref.watch(listItemCountsProvider(list.groupId)).valueOrNull?[list.id];
    final String? countLabel;
    if (counts != null && counts.total > 0) {
      countLabel = l10n.listOpenCount(counts.open);
    } else if (list.itemCount != null && list.itemCount! > 0) {
      countLabel = l10n.commonItemCount(list.itemCount!);
    } else {
      countLabel = null;
    }

    return AppCard(
      backgroundColor: accent.tileBackground,
      interactive: true,
      semanticLabel: _semanticLabel(),
      onTap: () => _openList(context),
      onLongPress: () => _showActions(context, ref),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reserve top-right space for the type badge
                Padding(
                  padding: const EdgeInsets.only(right: MitlistSpacing.space5),
                  child: Text(
                    list.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: accent.titleColor,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (previewLines.isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.sm),
                  for (var i = 0; i < previewLines.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        top: i == 0 ? 0 : MitlistSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isTodo) ...[
                            AppIcon(
                              name: 'checkCircleOutline',
                              size: 14,
                              color: snippetColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: MitlistSpacing.xs),
                          ],
                          Expanded(
                            child: Text(
                              previewLines[i],
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: snippetColor,
                                    height: 1.35,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: MitlistSpacing.sm),
                if (groupName != null) ...[
                  Row(
                    children: [
                      AppIcon(
                        name: 'userGroup',
                        size: 11,
                        color: snippetColor,
                      ),
                      const SizedBox(width: MitlistSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.listSharedWith(groupName),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: snippetColor,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MitlistSpacing.xs),
                ],
                Row(
                  children: [
                    if (countLabel != null)
                      Expanded(
                        child: Text(
                          countLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: snippetColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      )
                    else
                      const Spacer(),
                    _CardActionButton(
                      iconName: 'addCircleOutline',
                      color: accent.iconColor,
                      tooltip: l10n.listQuickAddItemTooltip,
                      semanticLabel: l10n.listQuickAddItemSemantics(list.name),
                      onTap: () => _openList(context, composer: true),
                    ),
                    _CardActionButton(
                      iconName: 'ellipsisVertical',
                      color: snippetColor,
                      tooltip: l10n.listOptionsTooltip,
                      semanticLabel: l10n.listOptionsTooltip,
                      onTap: () => _showActions(context, ref),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _TypeBadge(type: list.type, color: accent.titleColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 44×44 icon target for the card's bottom action row — full-strength icon
/// color so the affordance is visible, unlike the old 20px 70%-alpha icon.
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.iconName,
    required this.color,
    required this.tooltip,
    required this.semanticLabel,
    required this.onTap,
  });

  final String iconName;
  final Color color;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            unawaited(Haptics.light());
            onTap();
          },
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AppIcon(name: iconName, size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final Color color;

  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    final iconName = switch (type.toLowerCase()) {
      'shopping' => 'shoppingCart',
      'todo' => 'checkCircle',
      // Lowercase x — 'squares2X2' isn't a registered icon name and rendered
      // as an empty box for custom lists.
      _ => 'squares2x2',
    };
    return AppIcon(
      name: iconName,
      size: 16,
      color: color.withValues(alpha: 0.45),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 2,
        ),
        // Matches AppCard's resting shadow so loaded cards don't pop in with
        // a different silhouette.
        boxShadow: MitlistShadows.shadowSoft,
      ),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space5,
          ),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space3,
          ),
          SizedBox(height: MitlistSpacing.xs),
          AppSkeleton(
            width: MitlistSpacing.space10,
            height: MitlistSpacing.space3,
          ),
        ],
      ),
    );
  }
}
