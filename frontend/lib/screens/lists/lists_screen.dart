import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../sheets/create_list_sheet.dart';
import 'list_detail_screen.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../utils/shell_tab_load.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/chip.dart';
import '../../widgets/grocery_suggestion_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';

enum _SortOption { newest, oldest, az, mostItems }

enum _FilterOption { all, shopping, todo, custom }

enum _ListMenuAction {
  scanReceipt,
  sortNewest,
  sortOldest,
  sortAz,
  sortMostItems,
  toggleView
}

class ListsScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const ListsScreen({super.key, this.groupId});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  static const int _pageLimit = 50;

  static const _filters = <_FilterOption, String>{
    _FilterOption.all: 'All',
    _FilterOption.shopping: 'Shopping',
    _FilterOption.todo: 'To-do',
    _FilterOption.custom: 'Custom',
  };

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
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
          if (savedFilter != null && savedFilter < _FilterOption.values.length) {
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
    if (!shouldActivateShellTab(ref, listsShellTabIndex)) return;
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
    if (oldWidget.groupId != widget.groupId) {
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
    setState(() {
      _isLoading = true;
      _error = null;
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
            _error = 'Couldn\u2019t load lists. Check your connection.';
          });
        }
      }

      if (mounted) {
        setState(() {
          _hasMore = fetchedCount == _pageLimit;
          _isLoading = false;
          _error = _lists.isEmpty ? _error : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreLists() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      final effectiveGroupId = await _resolveGroupId();
      if (effectiveGroupId == null) return;
      final fetchedCount = await repo.refreshLists(
        effectiveGroupId,
        limit: _pageLimit,
        offset: _lists.length,
      );

      if (mounted) {
        setState(() {
          _hasHousehold = true;
          _hasMore = fetchedCount == _pageLimit;
          _isLoadingMore = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load more lists';
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
    var result = List<ItemList>.from(
        _lists.where((l) => !l.isArchived));

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
        return l.itemPreview
            .any((p) => p.toLowerCase().contains(query));
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

  Future<void> _quickCreateAndOpen() async {
    unawaited(Haptics.light());
    final effectiveGroupId = await _resolveGroupId();
    if (effectiveGroupId == null || !mounted) return;
    try {
      final svc = await ref.read(listServiceProviderAsync.future);
      final type = _filterToListType() ?? 'shopping';
      final list = await svc.createList(
        CreateListRequest(groupId: effectiveGroupId, name: 'New list', type: type),
      );
      if (!mounted) return;
      final changed = await context.pushNamed<bool>(
        'listDetail',
        pathParameters: {'listId': list.id},
        extra: ListDetailRouteArgs(listName: list.name, autoFocusTitle: true),
      );
      if (changed == true || mounted) unawaited(_loadLists());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t create list.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellVisitedTabsProvider, (previous, next) {
      _activateTabIfNeeded();
    });
    ref.listen<String?>(currentGroupIdProvider, (previous, next) {
      if (previous != next) {
        _loadLists();
      }
    });

    return Scaffold(
      appBar: MitlistAppBar(
        centerTitle: false,
        leading: _showSearch
            ? IconButton(
                icon: const AppIcon(name: 'arrowLeft'),
                tooltip: 'Back',
                onPressed: _clearSearch,
              )
            : null,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search lists',
                  hintText: 'Name, e.g. groceries',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text(
                'Lists',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const AppIcon(name: 'shoppingCart'),
              tooltip: 'Shopping trip',
              onPressed: () => context.pushNamed('shoppingTrip'),
            ),
            IconButton(
              icon: const AppIcon(name: 'magnifyingGlass'),
              tooltip: 'Search',
              onPressed: () => setState(() => _showSearch = true),
            ),
            PopupMenuButton<_ListMenuAction>(
              icon: const AppIcon(name: 'ellipsisVertical'),
              tooltip: 'Options',
              onSelected: (action) {
                setState(() {
                  switch (action) {
                    case _ListMenuAction.scanReceipt:
                      break;
                    case _ListMenuAction.sortNewest:
                      _sort = _SortOption.newest;
                      SharedPreferences.getInstance().then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                    case _ListMenuAction.sortOldest:
                      _sort = _SortOption.oldest;
                      SharedPreferences.getInstance().then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                    case _ListMenuAction.sortAz:
                      _sort = _SortOption.az;
                      SharedPreferences.getInstance().then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                    case _ListMenuAction.sortMostItems:
                      _sort = _SortOption.mostItems;
                      SharedPreferences.getInstance().then((p) => p.setInt('lists_sort', _sort.index));
                      break;
                    case _ListMenuAction.toggleView:
                      _isGrid = !_isGrid;
                      SharedPreferences.getInstance().then((p) => p.setBool('lists_is_grid', _isGrid));
                      break;
                  }
                });
                if (action == _ListMenuAction.scanReceipt) {
                  context.pushNamed('scanner');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ListMenuAction.scanReceipt,
                  child: Row(
                    children: [
                      AppIcon(name: 'camera', size: 18, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: MitlistSpacing.sm),
                      const Text('Scan receipt or list'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Sort',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortNewest,
                  checked: _sort == _SortOption.newest,
                  child: const Text('Newest'),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortOldest,
                  checked: _sort == _SortOption.oldest,
                  child: const Text('Oldest'),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortAz,
                  checked: _sort == _SortOption.az,
                  child: const Text('A–Z'),
                ),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.sortMostItems,
                  checked: _sort == _SortOption.mostItems,
                  child: const Text('Most items'),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: _ListMenuAction.toggleView,
                  checked: _isGrid,
                  child: const Text('Grid view'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
      floatingActionButton: AppButton(
        size: AppButtonSize.lg,
        onPressed:
            _hasHousehold ? _quickCreateAndOpen : () => context.goNamed('groupsList'),
        icon: const AppIcon(name: 'plus'),
        text: 'New list',
        tooltip: 'New list',
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
                          text: 'Retry',
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
    final count = switch (option) {
      _FilterOption.all => _lists.length,
      _FilterOption.shopping => _lists.where((l) => l.type.toLowerCase() == 'shopping').length,
      _FilterOption.todo => _lists.where((l) => l.type.toLowerCase() == 'todo').length,
      _FilterOption.custom => _lists.where((l) => l.type.toLowerCase() == 'custom').length,
    };
    return count > 0 ? '$base ($count)' : base;
  }

  Widget _buildChipBar() {
    if (!_hasHousehold) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.sm,
      ),
      child: Row(
        children: _filters.entries.map((entry) {
          final option = entry.key;
          final label = _chipLabel(option, entry.value);
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: AppChip(
              label: label,
              selected: _filter == option,
              onSelected: (_) {
                setState(() => _filter = option);
                SharedPreferences.getInstance().then((p) => p.setInt('lists_filter', _filter.index));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(List<ItemList> lists) {
    final itemCount = lists.length + (_isLoadingMore || _error != null ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        const minTileWidth = 190.0;
        final maxWidth = constraints.maxWidth;
        final columns = (maxWidth / minTileWidth).floor().clamp(2, 5);
        final aspectRatio =
            MediaQuery.textScalerOf(context).scale(1.0) > 1.2 ? 0.72 : 0.78;

        return GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(MitlistSpacing.md),
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
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: lists.length + (_isLoadingMore || _error != null ? 1 : 0),
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
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: 'Retry',
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
          valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  String get _emptyTitle => switch (_filter) {
    _FilterOption.shopping => 'No shopping lists',
    _FilterOption.todo => 'No to-do lists',
    _FilterOption.custom => 'No custom lists',
    _FilterOption.all => 'No lists yet',
  };

  String get _emptyDescription => switch (_filter) {
    _FilterOption.shopping => 'Great for groceries, meal prep, weekend errands.',
    _FilterOption.todo => 'Tasks, chores, anything with a checkbox.',
    _FilterOption.custom => 'Free-form — your list, your rules.',
    _FilterOption.all => 'Add lines inside a list; the first few appear as a snippet on its card.',
  };

  String get _emptyActionLabel => switch (_filter) {
    _FilterOption.shopping => 'Create a shopping list',
    _FilterOption.todo => 'Create a to-do list',
    _FilterOption.custom => 'Create a custom list',
    _FilterOption.all => 'Create your first list',
  };

  Widget _buildEmptyState() {
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
                  lottieAsset: 'assets/animations/lottie/checklist.lottie',
                  icon: const AppIcon(name: 'queueList'),
                  title: _emptyTitle,
                  description: _emptyDescription,
                  actions: [
                    AppButton(
                      text: _emptyActionLabel,
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

  /// Shown when a search matches nothing: name the dead end and offer the way
  /// out, instead of the create-a-list pitch.
  Widget _buildSearchEmptyState() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 40,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          'No lists match "$_searchQuery"',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          'Names and list items are searched.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppButton(
          text: 'Clear search',
          variant: AppButtonVariant.outline,
          onPressed: _clearSearch,
        ),
      ],
    );
  }

  Widget _buildNoHouseholdState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: const AppIcon(name: 'userGroup'),
          title: 'No household yet',
          description: 'Create or join a household before adding lists.',
          actions: [
            AppButton(
              text: 'Go to households',
              onPressed: () => context.goNamed('groupsList'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(MitlistSpacing.md),
      mainAxisSpacing: MitlistSpacing.md,
      crossAxisSpacing: MitlistSpacing.md,
      childAspectRatio: 0.78,
      children: List.generate(4, (_) => const _SkeletonCard()),
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

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    unawaited(Haptics.medium());
    final action = await showAppDialog<String>(
      context: context,
      title: list.name,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            text: 'Rename',
            icon: const AppIcon(name: 'pencilSquare', size: 18),
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            onPressed: () => Navigator.of(context).pop('rename'),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            text: 'Delete list',
            icon: const AppIcon(name: 'trash', size: 18),
            variant: AppButtonVariant.outline,
            color: AppButtonColor.error,
            onPressed: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
      actions: [],
    );
    if (action == 'rename' && context.mounted) {
      await _renameList(context, ref);
    } else if (action == 'delete' && context.mounted) {
      await _deleteList(context, ref);
    }
  }

  Future<void> _renameList(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: list.name);
    final newName = await showAppDialog<String>(
      context: context,
      title: 'Rename list',
      body: AppInput(
        label: 'List name',
        controller: controller,
        maxLength: 100,
        textInputAction: TextInputAction.done,
      ),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        AppButton(
          text: 'Save',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t rename list.')),
        );
      }
    }
  }

  Future<void> _deleteList(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete list',
      body: const Text('This will permanently delete this list and all its items.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          text: 'Delete',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t delete list.')),
        );
      }
    }
  }

  Future<void> _quickAddItem(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showAppDialog<String>(
      context: context,
      title: 'Add item to ${list.name}',
      body: GrocerySuggestionField(
        controller: controller,
        groupId: list.groupId,
        label: 'Item name',
        maxLength: 200,
        submitOnSelect: true,
        onSubmitted: (value) =>
            Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim()),
      ),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        AppButton(
          text: 'Add',
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final svc = await ref.read(listServiceProviderAsync.future);
      await svc.createItem(list.id, CreateListItemRequest(name: name));
      onChanged();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\u2019t add item.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ListTileAccent.fromSeed(
      list.id,
      Theme.of(context).brightness,
    );
    final previewLines = list.itemPreview
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(4)
        .toList();
    final snippetColor = accent.snippetOnTile;
    final isTodo = list.type.toLowerCase() == 'todo';

    final itemCount = list.itemCount;

    return Material(
      color: accent.tileBackground,
      child: Semantics(
        button: true,
        label: _semanticLabel(),
        child: InkWell(
          onTap: () async {
            final changed = await context.pushNamed<bool>(
              'listDetail',
              pathParameters: {'listId': list.id},
              extra: ListDetailRouteArgs(listName: list.name),
            );
            if (changed == true) onChanged();
          },
          onLongPress: () => _showActions(context, ref),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(MitlistSpacing.md),
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
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: snippetColor,
                                        height: 1.35,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: MitlistSpacing.sm),
                    Row(
                      children: [
                        if (itemCount != null && itemCount > 0)
                          Text(
                            '$itemCount item${itemCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: snippetColor,
                                ),
                          ),
                        const Spacer(),
                        Semantics(
                          label: 'Quick add item to ${list.name}',
                          child: InkWell(
                            onTap: () => _quickAddItem(context, ref),
                            borderRadius: BorderRadius.circular(MitlistSpacing.xs),
                            child: Padding(
                              padding: const EdgeInsets.all(MitlistSpacing.xs),
                              child: AppIcon(
                                name: 'addCircleOutline',
                                size: 18,
                                color: snippetColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: PopupMenuButton<String>(
                    tooltip: 'List options',
                    padding: EdgeInsets.zero,
                    onSelected: (action) async {
                      if (!context.mounted) return;
                      if (action == 'rename') {
                        await _renameList(context, ref);
                      } else if (action == 'delete') {
                        await _deleteList(context, ref);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(children: [
                          AppIcon(name: 'pencilSquare', size: 18, color: Theme.of(ctx).colorScheme.onSurface),
                          const SizedBox(width: MitlistSpacing.sm),
                          const Text('Rename'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          AppIcon(name: 'trash', size: 18, color: Theme.of(ctx).colorScheme.error),
                          const SizedBox(width: MitlistSpacing.sm),
                          Text('Delete list', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.error)),
                        ]),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(MitlistSpacing.sm),
                      child: _TypeBadge(type: list.type, color: accent.titleColor),
                    ),
                  ),
                ),
              ],
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
      _ => 'squares2X2',
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
