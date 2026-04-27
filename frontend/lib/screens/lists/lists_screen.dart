import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../services/group_id_validator.dart';
import '../../sheets/create_list_sheet.dart';
import 'list_detail_screen.dart';
import '../../theme/colors.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icons.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';

enum _SortOption { newest, oldest, az, mostItems }

enum _FilterOption { all, shopping, todo, custom }

enum _ListMenuAction {
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
  bool _hasHousehold = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

    final groupService = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupService.listGroups(limit: 1);
    final groupId = groups.isEmpty ? null : groups.first.id;
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
            _error = e.toString().replaceFirst('Exception: ', '');
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
          _error = e.toString().replaceFirst('Exception: ', '');
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
    var result = List<ItemList>.from(_lists);

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

  Future<void> _showCreateSheet() async {
    final created = await CreateListSheet.show(
      context,
      initialGroupId: widget.groupId,
    );
    if (created == true) {
      await _loadLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar(
        centerTitle: false,
        leading: _showSearch
            ? IconButton(
                icon: const Icon(AppIcons.arrowLeft),
                tooltip: 'Back',
                onPressed: _clearSearch,
              )
            : IconButton(
                icon: const Icon(AppIcons.userGroup),
                tooltip: 'To households',
                onPressed: () => context.goNamed('groupsList'),
              ),
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
              icon: const Icon(AppIcons.magnifyingGlass),
              tooltip: 'Search',
              onPressed: () => setState(() => _showSearch = true),
            ),
            PopupMenuButton<_ListMenuAction>(
              icon: const Icon(AppIcons.ellipsisVertical),
              tooltip: 'Options',
              onSelected: (action) {
                setState(() {
                  switch (action) {
                    case _ListMenuAction.sortNewest:
                      _sort = _SortOption.newest;
                      break;
                    case _ListMenuAction.sortOldest:
                      _sort = _SortOption.oldest;
                      break;
                    case _ListMenuAction.sortAz:
                      _sort = _SortOption.az;
                      break;
                    case _ListMenuAction.sortMostItems:
                      _sort = _SortOption.mostItems;
                      break;
                    case _ListMenuAction.toggleView:
                      _isGrid = !_isGrid;
                      break;
                  }
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Sort',
                    style: MitlistTypography.labelXSmall().copyWith(
                      color: MitlistColors.textSecondary,
                    ),
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
          ] else ...[
            IconButton(
              icon: const Icon(AppIcons.xMark),
              tooltip: 'Clear search',
              onPressed: _clearSearch,
            ),
          ],
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lists_create_fab',
        onPressed:
            _hasHousehold ? _showCreateSheet : () => context.goNamed('groupsList'),
        icon: const Icon(AppIcons.plus),
        label: const Text('New list'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _lists.isEmpty) {
      return _buildSkeleton();
    }

    if (_error != null && _lists.isEmpty) {
      return RefreshIndicator(
        color: MitlistColors.primary500,
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
                          icon: const Icon(AppIcons.arrowPath),
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
            color: MitlistColors.primary500,
            onRefresh: _loadLists,
            child: lists.isEmpty
                ? _buildEmptyState()
                : (_isGrid ? _buildGrid(lists) : _buildList(lists)),
          ),
        ),
      ],
    );
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
          final label = entry.value;
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: AppChip(
              label: label,
              selected: _filter == option,
              onSelected: (_) => setState(() => _filter = option),
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
            return _ListCard(
              list: lists[index],
              onChanged: () => unawaited(_loadLists()),
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
        return _ListCard(
          list: lists[index],
          onChanged: () => unawaited(_loadLists()),
        );
      },
    );
  }

  Widget _buildPaginationFooter() {
    if (_error != null) {
      return AppAlert(type: AppAlertType.error, message: _error!);
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(MitlistSpacing.md),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(MitlistColors.primary500),
        ),
      ),
    );
  }

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
                child: AppEmptyState(
                  icon: const Icon(AppIcons.queueList),
                  title: 'No lists yet',
                  description:
                      'Add lines inside a list; the first few appear as a snippet on its card.',
                  actions: [
                    AppButton(
                      text: 'Create your first list',
                      icon: const Icon(AppIcons.plus),
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

  Widget _buildNoHouseholdState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          icon: const Icon(AppIcons.userGroup),
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

class _ListCard extends StatelessWidget {
  final ItemList list;
  final VoidCallback onChanged;

  const _ListCard({required this.list, required this.onChanged});

  String _semanticLabel() {
    final parts = <String>[list.name];
    final lines = list.itemPreview
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3);
    if (lines.isNotEmpty) {
      parts.add(lines.join(', '));
    }
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final accent = ListTileAccent.fromSeed(
      list.id,
      Theme.of(context).brightness,
    );
    final previewLines = list.itemPreview
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    final snippetColor = accent.snippetOnTile;

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
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: MitlistColors.borderPrimary,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  list.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent.titleColor,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (previewLines.isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.sm),
                  for (var i = 0; i < previewLines.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        top: i == 0 ? 0 : MitlistSpacing.xs,
                      ),
                      child: Text(
                        previewLines[i],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: snippetColor,
                              height: 1.35,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
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
          color: MitlistColors.borderPrimary,
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
