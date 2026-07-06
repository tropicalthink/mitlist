import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';
import '../../models/group_models.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../l10n/app_localizations.dart';
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
        _errorMessage = AppLocalizations.of(context)!.groupsFailedLoad;
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
        _errorMessage = AppLocalizations.of(context)!.groupsFailedMore;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleRefresh() {
    return _loadInitialGroups();
  }

  void _navigateToHub(String groupId) {
    ref.read(currentGroupIdProvider.notifier).set(groupId);
    context.goNamed('home');
  }

  Future<void> _openJoinSheet() async {
    final group = await JoinHouseholdSheet.show(context);
    if (group != null && mounted) {
      _navigateToHub(group.id);
    }
  }

  Future<void> _openCreateSheet() async {
    final group = await CreateHouseholdSheet.show(context);
    if (group != null && mounted) {
      _navigateToHub(group.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.myHouseholdsTitle,
        actions: [
          IconButton(
            tooltip: l10n.commonSettings,
            onPressed: () => context.goNamed('you'),
            icon: AppIcon(name: 'cog6Tooth'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
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
            tooltip: l10n.groupsJoinWithCode,
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            size: _isExtended ? AppButtonSize.lg : AppButtonSize.md,
            onPressed: _openCreateSheet,
            icon: const AppIcon(name: 'plus'),
            text: _isExtended ? l10n.commonCreate : null,
            tooltip: l10n.groupsCreateHousehold,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _groups.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 160, height: 16),
                SizedBox(height: MitlistSpacing.sm),
                AppSkeleton(width: double.infinity, height: 40),
              ],
            ),
          ),
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
        final l10n = AppLocalizations.of(context)!;
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
                  AppAlert(
                    type: AppAlertType.error,
                    message: _errorMessage!,
                  ),
                  const SizedBox(height: MitlistSpacing.md),
                  AppButton(
                    text: l10n.commonRetry,
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
        final l10n = AppLocalizations.of(context)!;
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
                  icon: AppIcon(
                    name: 'userGroup',
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: l10n.groupsEmptyTitle,
                  description: l10n.groupsEmptyDesc,
                  actions: [
                    AppButton(
                      text: l10n.groupsCreateHousehold,
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

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
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

class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback? onTap;

  const _GroupCard({
    required this.group,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPersonal = group.isPersonal == true;
    final memberCount = group.memberCount;
    final content = Row(
      children: [
        AppIcon(
          name: isPersonal ? 'userCircle' : 'home',
          size: MitlistSpacing.space6,
          color: isPersonal
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
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
                  l10n.commonMember(memberCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        AppIcon(
          name: 'chevronRight',
          size: MitlistSpacing.space5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: Theme.of(context).colorScheme.primaryContainer,
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
