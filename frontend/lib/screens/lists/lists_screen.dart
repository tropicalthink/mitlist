import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../services/group_id_validator.dart';
import '../../sheets/create_list_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icons.dart';
import '../../widgets/skeleton.dart';

enum _SortOption { newest, oldest, az, mostItems }

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
  String? _error;
  final List<ItemList> _lists = [];
  final ScrollController _scrollController = ScrollController();
  bool _isGrid = true;
  String _filter = 'All';
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
      final listService = await ref.read(listServiceProviderAsync.future);
      final effectiveGroupId = await _resolveGroupId();
      final data = effectiveGroupId == null
          ? <ItemList>[]
          : await listService.listLists(
              effectiveGroupId,
              limit: _pageLimit,
              offset: 0,
            );

      if (mounted) {
        setState(() {
          _lists
            ..clear()
            ..addAll(data);
          _hasHousehold = effectiveGroupId != null;
          _hasMore = data.length == _pageLimit;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load lists';
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
      final listService = await ref.read(listServiceProviderAsync.future);
      final effectiveGroupId = await _resolveGroupId();
      final data = effectiveGroupId == null
          ? <ItemList>[]
          : await listService.listLists(
              effectiveGroupId,
              limit: _pageLimit,
              offset: _lists.length,
            );

      if (mounted) {
        setState(() {
          _lists.addAll(data);
          _hasHousehold = effectiveGroupId != null;
          _hasMore = data.length == _pageLimit;
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  List<ItemList> get _filteredLists {
    var result = List<ItemList>.from(_lists);

    if (_filter != 'All') {
      result = result.where((l) => _capitalize(l.type) == _filter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result =
          result.where((l) => l.name.toLowerCase().contains(query)).toList();
    }

    switch (_sort) {
      case _SortOption.newest:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _SortOption.oldest:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case _SortOption.az:
        result.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SortOption.mostItems:
        result.sort(_compareByItemCount);
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

  void _showCreateSheet() {
    CreateListSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: _showSearch
            ? IconButton(
                icon: const Icon(AppIcons.arrowLeft),
                onPressed: _clearSearch,
              )
            : null,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search lists...',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('Lists'),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const Icon(AppIcons.magnifyingGlass),
              tooltip: 'Search',
              onPressed: () => setState(() => _showSearch = true),
            ),
            PopupMenuButton<_SortOption>(
              icon: const Icon(AppIcons.funnel),
              tooltip: 'Sort',
              onSelected: (sort) => setState(() => _sort = sort),
              itemBuilder: (context) => const [
                PopupMenuItem(value: _SortOption.newest, child: Text('Newest')),
                PopupMenuItem(value: _SortOption.oldest, child: Text('Oldest')),
                PopupMenuItem(value: _SortOption.az, child: Text('A-Z')),
                PopupMenuItem(
                    value: _SortOption.mostItems, child: Text('Most items')),
              ],
            ),
            IconButton(
              icon: Icon(_isGrid ? AppIcons.listBullet : AppIcons.squares2x2),
              tooltip: _isGrid ? 'List view' : 'Grid view',
              onPressed: () => setState(() => _isGrid = !_isGrid),
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
        onPressed:
            _hasHousehold ? _showCreateSheet : () => context.goNamed('home'),
        icon: const Icon(AppIcons.plus),
        label: Text(_hasHousehold ? 'New list' : 'Households'),
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
            child: _filteredLists.isEmpty
                ? _buildEmptyState()
                : (_isGrid ? _buildGrid() : _buildList()),
          ),
        ),
      ],
    );
  }

  Widget _buildChipBar() {
    const filters = ['All', 'Shopping', 'To-do', 'Custom'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.sm,
      ),
      child: Row(
        children: filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: AppChip(
              label: filter,
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid() {
    final lists = _filteredLists;
    final itemCount = lists.length + (_isLoadingMore || _error != null ? 1 : 0);

    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: MitlistSpacing.md,
        crossAxisSpacing: MitlistSpacing.md,
        childAspectRatio: 0.95,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= lists.length) return _buildPaginationFooter();
        return _ListCard(list: lists[index]);
      },
    );
  }

  Widget _buildList() {
    final lists = _filteredLists;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: lists.length + (_isLoadingMore || _error != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: MitlistSpacing.md),
      itemBuilder: (_, index) {
        if (index >= lists.length) return _buildPaginationFooter();
        return _ListCard(list: lists[index]);
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
        child: CircularProgressIndicator(),
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
          icon: const Icon(AppIcons.home),
          title: 'No household yet',
          description: 'Create or join a household before adding lists.',
          actions: [
            AppButton(
              text: 'Go to households',
              onPressed: () => context.goNamed('home'),
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
      childAspectRatio: 0.95,
      children: List.generate(4, (_) => const _SkeletonCard()),
    );
  }
}

class _ListCard extends StatelessWidget {
  final ItemList list;

  const _ListCard({required this.list});

  @override
  Widget build(BuildContext context) {
    final itemCount = list.itemCount;
    return AppCard(
      interactive: true,
      onTap: () {
        context.pushNamed(
          'listDetail',
          pathParameters: {'listId': list.id},
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _getTypeIcon(list.type),
                size: MitlistSpacing.space5,
                color: MitlistColors.textSecondary,
              ),
              const Spacer(),
              Text(
                _formatDate(list.updatedAt),
                style: MitlistTypography.labelXSmall(),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            list.name,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (itemCount != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              '$itemCount items',
              style: MitlistTypography.monoBody(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    return switch (type) {
      'shopping' => AppIcons.shoppingCart,
      'todo' => AppIcons.check,
      _ => AppIcons.queueList,
    };
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSkeleton(
                width: MitlistSpacing.space5,
                height: MitlistSpacing.space5,
              ),
              Spacer(),
              AppSkeleton(
                width: MitlistSpacing.space8,
                height: MitlistSpacing.space3,
              ),
            ],
          ),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space5,
          ),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(
            width: MitlistSpacing.space10,
            height: MitlistSpacing.space4,
          ),
        ],
      ),
    );
  }
}
