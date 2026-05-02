import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../models/group_models.dart';
import '../../providers/group_provider.dart';
import '../../sheets/create_household_sheet.dart';
import '../../sheets/join_household_sheet.dart';

class GroupsListScreen extends ConsumerStatefulWidget {
  const GroupsListScreen({super.key});

  @override
  ConsumerState<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends ConsumerState<GroupsListScreen> {
  static const int _pageLimit = 50;

  final ScrollController _scrollController = ScrollController();
  final List<Group> _groups = <Group>[];
  bool _isExtended = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialGroups();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final atTop = _scrollController.offset <= 0;
    if (atTop && !_isExtended) {
      setState(() => _isExtended = true);
    } else if (!atTop && _isExtended) {
      setState(() => _isExtended = false);
    }

    if (_scrollController.hasClients &&
        !_isLoadingMore &&
        _hasMore &&
        _scrollController.position.extentAfter < 400) {
      _loadMoreGroups();
    }
  }

  Future<List<Group>> _fetchGroups({required int offset}) async {
    final groupService = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupService.listGroups(
      limit: _pageLimit,
      offset: offset,
    );
    return groups;
  }

  Future<void> _loadInitialGroups() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasMore = true;
    });

    try {
      final groups = await _fetchGroups(offset: 0);
      if (!mounted) return;
      setState(() {
        _groups
          ..clear()
          ..addAll(groups);
        _hasMore = groups.length == _pageLimit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load households';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreGroups() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final groups = await _fetchGroups(offset: _groups.length);
      if (!mounted) return;
      setState(() {
        _groups.addAll(groups);
        _hasMore = groups.length == _pageLimit;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load more households';
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleRefresh() {
    return _loadInitialGroups();
  }

  void _navigateToHub(String groupId) {
    context.pushNamed(
      'householdHub',
      pathParameters: {'groupId': groupId},
    );
  }

  Future<void> _openJoinSheet() async {
    final joined = await JoinHouseholdSheet.show(context);
    if (joined == true && mounted) {
      await _loadInitialGroups();
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await CreateHouseholdSheet.show(context);
    if (created == true && mounted) {
      _loadInitialGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'My Households',
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.goNamed('you'),
            icon: const AppIcon(name: 'cog6Tooth'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: MitlistColors.primary500,
        onRefresh: _handleRefresh,
        child: _buildBody(),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.soft,
            color: AppButtonColor.neutral,
            onPressed: _openJoinSheet,
            icon: const AppIcon(name: 'qrCode'),
            tooltip: 'Join with code',
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            size: _isExtended ? AppButtonSize.lg : AppButtonSize.md,
            onPressed: _openCreateSheet,
            icon: const AppIcon(name: 'plus'),
            text: _isExtended ? 'Create' : null,
            tooltip: 'Create household',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _groups.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(MitlistColors.primary500),
        ),
      );
    }

    if (_errorMessage != null && _groups.isEmpty) {
      return _buildError(() => _handleRefresh());
    }

    if (_groups.isEmpty) {
      return _buildEmpty();
    }

    return _buildList(_groups);
  }

  Widget _buildError(VoidCallback onRetry) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final contentHeight = availableHeight - (MitlistSpacing.md * 2);
        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(MitlistSpacing.md),
          children: [
            SizedBox(
              height: contentHeight.clamp(100.0, double.infinity),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppAlert(
                    type: AppAlertType.error,
                    message: 'Failed to load households',
                  ),
                  const SizedBox(height: MitlistSpacing.md),
                  AppButton(
                    text: 'Retry',
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(MitlistSpacing.md),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: AppEmptyState(
                  lottieAsset: 'assets/animations/lottie/House.lottie',
                  icon: const AppIcon(
                    name: 'userGroup',
                    size: 56,
                    color: MitlistColors.textTertiary,
                  ),
                  title: 'No households yet',
                  description: 'Create one to start organizing your home.',
                  actions: [
                    AppButton(
                      text: 'Create household',
                      onPressed: _openCreateSheet,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(List<Group> groups) {
    final sorted = [...groups]..sort((a, b) {
        final aIsPersonal = a.isPersonal == true;
        final bIsPersonal = b.isPersonal == true;
        if (aIsPersonal == bIsPersonal) return 0;
        return aIsPersonal ? -1 : 1;
      });

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount:
          sorted.length + (_isLoadingMore || _errorMessage != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: MitlistSpacing.md),
      itemBuilder: (context, index) {
        if (index >= sorted.length) {
          if (_errorMessage != null) {
            return AppAlert(
              type: AppAlertType.error,
              message: _errorMessage!,
            );
          }

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(MitlistSpacing.md),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final group = sorted[index];
        return _GroupCard(
          group: group,
          onTap: () => _navigateToHub(group.id),
        );
      },
    );
  }
}

// Skeleton card removed: this screen now uses a spinner for loading.

class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback? onTap;

  const _GroupCard({
    required this.group,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPersonal = group.isPersonal == true;
    final memberCount = group.memberCount;
    final content = Row(
      children: [
        AppIcon(
          name: isPersonal ? 'userCircle' : 'home',
          size: MitlistSpacing.space6,
          color:
              isPersonal ? MitlistColors.primary500 : MitlistColors.textPrimary,
        ),
        const SizedBox(width: MitlistSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (memberCount != null) ...[
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  '$memberCount member${memberCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        AppIcon(
          name: 'chevronRight',
          size: MitlistSpacing.space5,
          color: MitlistColors.textSecondary,
        ),
      ],
    );

    if (isPersonal) {
      return AppCard(
        interactive: true,
        variant: AppCardVariant.elevated,
        padding: AppCardPadding.none,
        onTap: onTap,
        semanticLabel: group.name,
        child: Container(
          color: MitlistColors.primary100,
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: content,
        ),
      );
    }

    return AppCard(
      interactive: true,
      variant: AppCardVariant.elevated,
      padding: AppCardPadding.md,
      onTap: onTap,
      semanticLabel: group.name,
      child: content,
    );
  }
}
