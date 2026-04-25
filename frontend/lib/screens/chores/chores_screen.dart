import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/chore_provider.dart';
import '../../providers/group_provider.dart';
import '../../services/group_id_validator.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/chore_detail_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';

class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  bool _isLoading = true;
  String? _error;
  final List<_Chore> _chores = [];
  bool _filterMe = true;
  bool _hasHousehold = true;

  static const double _displaySmallLineHeight = 36 * (44 / 36);
  static const double _labelMediumLineHeight = 12 * (16 / 12);

  static const double _stickyHeaderHeight = MitlistSpacing.md +
      MitlistSpacing.md +
      _displaySmallLineHeight +
      MitlistSpacing.space1 +
      _labelMediumLineHeight +
      MitlistSpacing.md +
      MitlistSpacing.sm +
      MitlistSpacing.space8 +
      MitlistSpacing.md +
      MitlistSpacing.space1;

  static const double _sectionHeaderHeight =
      MitlistSpacing.sm + _labelMediumLineHeight + MitlistSpacing.sm;

  @override
  void initState() {
    super.initState();
    _loadChores();
  }

  Future<void> _loadChores() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final choreService = await ref.read(choreServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
      final groupId = groups.isNotEmpty ? groups.first.id : null;
      if (!isValidGroupId(groupId)) {
        if (!mounted) return;
        setState(() {
          _chores.clear();
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      final apiChores = await choreService.listChores(groupId!);
      if (!mounted) return;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final chores = apiChores
          .map((api) => _Chore(
                id: api.id,
                title: api.name,
                assigneeInitials: api.name.isNotEmpty
                    ? api.name.substring(0, 1).toUpperCase()
                    : '?',
                dueDate: today,
                isMine: true,
                completed: !api.isActive,
              ))
          .toList();
      setState(() {
        _chores
          ..clear()
          ..addAll(chores);
        _hasHousehold = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load chores. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() => _loadChores();

  Future<void> _addChore() async {
    final created = await ChoreCreationSheet.show(context);
    if (created == true) {
      await _loadChores();
    }
  }

  Future<void> _openChoreDetail(String id) async {
    final chore = _chores.firstWhere((item) => item.id == id);
    await ChoreDetailSheet.show(
      context,
      title: chore.title,
      statusLabel: chore.completed ? 'Done' : 'Pending',
      assignee: chore.assigneeInitials,
      dueDate: chore.dueDate,
      onMarkDone: chore.completed
          ? null
          : () async {
              Navigator.of(context).pop();
              await _toggleComplete(id);
            },
    );
  }

  Future<void> _toggleComplete(String id) async {
    try {
      final choreService = await ref.read(choreServiceProviderAsync.future);
      final chore = _chores.firstWhere((c) => c.id == id);
      if (chore.completed) {
        // Chore is already completed, can't un-complete through API
        return;
      }
      await choreService.completeChore(id);
      setState(() {
        chore.completed = true;
      });
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to complete chore. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  List<_Chore> get _filteredChores {
    if (_filterMe) {
      return _chores.where((c) => c.isMine).toList();
    }
    return _chores.toList();
  }

  Map<String, List<_Chore>> _groupBySection(List<_Chore> chores) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekLater = today.add(const Duration(days: 7));

    final result = <String, List<_Chore>>{
      'Overdue': [],
      'Today': [],
      'This week': [],
      'Later': [],
    };

    for (final chore in chores) {
      final due = DateTime(
        chore.dueDate.year,
        chore.dueDate.month,
        chore.dueDate.day,
      );
      if (due.isBefore(today)) {
        result['Overdue']!.add(chore);
      } else if (due.isBefore(tomorrow)) {
        result['Today']!.add(chore);
      } else if (due.isBefore(weekLater)) {
        result['This week']!.add(chore);
      } else {
        result['Later']!.add(chore);
      }
    }

    return result;
  }

  ({int overdue, int today, int done}) _computeStats(List<_Chore> chores) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    var overdue = 0;
    var tod = 0;
    var done = 0;

    for (final chore in chores) {
      if (chore.completed) {
        done++;
        continue;
      }
      final due = DateTime(
        chore.dueDate.year,
        chore.dueDate.month,
        chore.dueDate.day,
      );
      if (due.isBefore(today)) {
        overdue++;
      } else if (due.isBefore(tomorrow)) {
        tod++;
      }
    }

    return (overdue: overdue, today: tod, done: done);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredChores;
    final stats = _computeStats(filtered);
    final sections = _groupBySection(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _hasHousehold ? _addChore : () => context.goNamed('home'),
        icon: AppIcon(
          name: _hasHousehold ? 'plus' : 'home',
          color: MitlistColors.textOnPrimary,
        ),
        label: Text(_hasHousehold ? 'Add chore' : 'Households'),
      ),
      body: RefreshIndicator(
        color: MitlistColors.primary500,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                height: _stickyHeaderHeight,
                child: Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: AppCardPadding.md,
                        child: _isLoading
                            ? const Row(
                                children: [
                                  Expanded(child: _StatSkeleton()),
                                  Expanded(child: _StatSkeleton()),
                                  Expanded(child: _StatSkeleton()),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _StatBlock(
                                      count: stats.overdue,
                                      label: 'Overdue',
                                      labelColor: MitlistColors.error500,
                                    ),
                                  ),
                                  Expanded(
                                    child: _StatBlock(
                                      count: stats.today,
                                      label: 'Today',
                                      labelColor: MitlistColors.warning500,
                                    ),
                                  ),
                                  Expanded(
                                    child: _StatBlock(
                                      count: stats.done,
                                      label: 'Done',
                                      labelColor: MitlistColors.success500,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: MitlistSpacing.sm),
                      _isLoading
                          ? Row(
                              children: [
                                AppSkeleton(
                                  width: MitlistSpacing.space12,
                                  height: MitlistSpacing.space8,
                                  borderRadius: AppSkeletonRadius.sm,
                                ),
                                const SizedBox(width: MitlistSpacing.sm),
                                AppSkeleton(
                                  width: MitlistSpacing.space14,
                                  height: MitlistSpacing.space8,
                                  borderRadius: AppSkeletonRadius.sm,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                AppChip(
                                  label: 'Me',
                                  selected: _filterMe,
                                  onSelected: (_) {
                                    setState(() => _filterMe = true);
                                  },
                                ),
                                const SizedBox(width: MitlistSpacing.sm),
                                AppChip(
                                  label: 'Everyone',
                                  selected: !_filterMe,
                                  onSelected: (_) {
                                    setState(() => _filterMe = false);
                                  },
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.md,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
                        child: _ChoreSkeletonItem(),
                      );
                    },
                    childCount: 5,
                  ),
                ),
              ),
            ] else if (_error != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: Column(
                    children: [
                      AppAlert(
                        type: AppAlertType.error,
                        message: _error!,
                      ),
                      const SizedBox(height: MitlistSpacing.md),
                      AppButton(
                        text: 'Retry',
                        onPressed: () => _loadChores(),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!_hasHousehold) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: AppEmptyState(
                      icon: const AppIcon(
                        name: 'home',
                        size: 56,
                        color: MitlistColors.textTertiary,
                      ),
                      title: 'No household yet',
                      description:
                          'Create or join a household before adding chores.',
                      actions: [
                        AppButton(
                          text: 'Go to households',
                          onPressed: () => context.goNamed('home'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (filtered.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: AppEmptyState(
                      icon: const AppIcon(
                        name: 'clipboardDocumentList',
                        size: 56,
                        color: MitlistColors.textTertiary,
                      ),
                      title: 'No chores yet',
                      actions: [
                        AppButton(
                          text: 'Add a chore',
                          icon: const AppIcon(
                            name: 'plus',
                            size: 16,
                            color: MitlistColors.textOnPrimary,
                          ),
                          onPressed: _addChore,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              for (final section in const [
                'Overdue',
                'Today',
                'This week',
                'Later'
              ])
                if (sections[section]!.isNotEmpty) ...[
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      height: _sectionHeaderHeight,
                      child: Container(
                        color: MitlistColors.surfaceSoft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.md,
                          vertical: MitlistSpacing.sm,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          section.toUpperCase(),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: MitlistColors.textSecondary,
                                  ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MitlistSpacing.md,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final chore = sections[section]![index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: MitlistSpacing.sm,
                            ),
                            child: _ChoreItem(
                              chore: chore,
                              onToggle: () => _toggleComplete(chore.id),
                              onTap: () => _openChoreDetail(chore.id),
                            ),
                          );
                        },
                        childCount: sections[section]!.length,
                      ),
                    ),
                  ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: MitlistColors.surfaceSoft,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class _Chore {
  final String id;
  final String title;
  final String assigneeInitials;
  final DateTime dueDate;
  final bool isMine;
  bool completed;

  _Chore({
    required this.id,
    required this.title,
    required this.assigneeInitials,
    required this.dueDate,
    this.isMine = true,
    this.completed = false,
  });
}

class _StatBlock extends StatelessWidget {
  final int count;
  final String label;
  final Color labelColor;

  const _StatBlock({
    required this.count,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            count.toString(),
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: MitlistSpacing.space1),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: labelColor,
              ),
        ),
      ],
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppSkeleton(
          width: MitlistSpacing.space8,
          height: MitlistSpacing.space8,
        ),
        const SizedBox(height: MitlistSpacing.space1),
        AppSkeleton(
          width: MitlistSpacing.space10,
          height: MitlistSpacing.space3,
        ),
      ],
    );
  }
}

class _ChoreItem extends StatelessWidget {
  final _Chore chore;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _ChoreItem({
    required this.chore,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.sm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: chore.completed,
            onChanged: (_) => onToggle(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: MitlistSpacing.sm,
                ),
                child: Text(
                  chore.title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: MitlistSpacing.space3,
                backgroundColor: MitlistColors.primary100,
                child: Text(
                  chore.assigneeInitials,
                  style: MitlistTypography.labelXSmall(
                    color: MitlistColors.primary900,
                  ),
                ),
              ),
              const SizedBox(height: MitlistSpacing.space1),
              Text(
                _formatDate(chore.dueDate),
                style: MitlistTypography.labelXSmall(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoreSkeletonItem extends StatelessWidget {
  const _ChoreSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.sm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppSkeleton(
            width: MitlistSpacing.space6,
            height: MitlistSpacing.space6,
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AppSkeleton(
                  width: constraints.maxWidth,
                  height: MitlistSpacing.space4,
                );
              },
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSkeleton(
                width: MitlistSpacing.space6,
                height: MitlistSpacing.space6,
                borderRadius: AppSkeletonRadius.sm,
              ),
              const SizedBox(height: MitlistSpacing.space1),
              AppSkeleton(
                width: MitlistSpacing.space8,
                height: MitlistSpacing.space3,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return DateFormat.MMMd().format(date);
}
