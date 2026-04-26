import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/group_models.dart';
import '../../providers/list_provider.dart';
import '../../providers/group_provider.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/skeleton.dart';
import '../../theme/animations.dart';
import '../../theme/spacing.dart';

class HouseholdHubScreen extends ConsumerStatefulWidget {
  final String groupId;

  const HouseholdHubScreen({super.key, required this.groupId});

  @override
  ConsumerState<HouseholdHubScreen> createState() => _HouseholdHubScreenState();
}

class _HouseholdHubScreenState extends ConsumerState<HouseholdHubScreen> {
  bool _isLoading = true;
  Object? _error;
  Group? _data;
  int _listsCount = 0;
  bool _listsCountError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final group = await groupService.getGroup(widget.groupId);
      int listsCount = 0;
      var listsCountError = false;
      try {
        final listService = await ref.read(listServiceProviderAsync.future);
        final lists = await listService.listLists(widget.groupId);
        listsCount = lists.length;
      } catch (_) {
        listsCountError = true;
      }
      if (!mounted) return;
      setState(() {
        _data = group;
        _listsCount = listsCount;
        _listsCountError = listsCountError;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back to households',
          onPressed: () => context.goNamed('home'),
        ),
        title: Text(
          _data?.name ?? 'Household',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'cog6Tooth'),
            tooltip: 'Household settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Household settings are coming soon.'),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(MitlistSpacing.md),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const _SkeletonDashboard()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppAlert(
                          type: AppAlertType.error,
                          message: 'Couldn’t load this household. Check your connection and try again.',
                        ),
                        const SizedBox(height: MitlistSpacing.md),
                        AppButton(
                          text: 'Retry',
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _StaggeredHubContent(
                    group: _data,
                    listsCount: _listsCount,
                    listsCountError: _listsCountError,
                  ),
                ),
    );
  }
}

class _StaggeredHubContent extends StatefulWidget {
  const _StaggeredHubContent({
    required this.group,
    required this.listsCount,
    required this.listsCountError,
  });

  final Group? group;
  final int listsCount;
  final bool listsCountError;

  @override
  State<_StaggeredHubContent> createState() => _StaggeredHubContentState();
}

class _StaggeredHubContentState extends State<_StaggeredHubContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  static const int _kRows = 4;

  late final List<Animation<double>> _entrances;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entrances = List<Animation<double>>.generate(_kRows, (i) {
      final start = (i * 0.1).clamp(0.0, 0.75);
      final end = (start + 0.4).clamp(0.0, 1.0);
      if (end <= start) {
        return const AlwaysStoppedAnimation<double>(1);
      }
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _stagger,
          curve: Interval(
            start,
            end,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback(_runEntrance);
  }

  void _runEntrance(_) {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _stagger.value = 1;
      return;
    }
    _stagger.forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Semantics(
        label: 'Household home',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HouseholdIntro(group: widget.group),
            const SizedBox(height: MitlistSpacing.lg),
            _staggered(
              0,
              _HubDestinationRow(
                iconName: 'clipboardDocumentList',
                label: 'Lists',
                routeName: 'lists',
                semanticLabel: _listsSemantic(
                  count: widget.listsCount,
                  countError: widget.listsCountError,
                ),
                subtitle: _listsSubtitle(
                  count: widget.listsCount,
                  countError: widget.listsCountError,
                ),
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            _staggered(
              1,
              const _HubDestinationRow(
                iconName: 'check',
                label: 'Chores',
                routeName: 'chores',
                semanticLabel: 'Chores, shared tasks',
                subtitle: 'Shared tasks',
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            _staggered(
              2,
              const _HubDestinationRow(
                iconName: 'banknotes',
                label: 'Money',
                routeName: 'money',
                semanticLabel: 'Money, expenses and balances',
                subtitle: 'Expenses and balances',
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            _staggered(
              3,
              const _HubDestinationRow(
                iconName: 'bookOpen',
                label: 'Recipes',
                routeName: 'recipes',
                semanticLabel: 'Recipes, meals and ideas',
                subtitle: 'Meals and ideas',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _listsSubtitle({required int count, required bool countError}) {
    if (countError) {
      return 'Count unavailable';
    }
    if (count == 0) {
      return 'No lists yet';
    }
    return '$count list${count == 1 ? '' : 's'}';
  }

  String _listsSemantic({required int count, required bool countError}) {
    if (countError) {
      return 'Lists, count unavailable';
    }
    if (count == 0) {
      return 'Lists, no lists yet';
    }
    return 'Lists, $count list${count == 1 ? '' : 's'}';
  }

  Widget _staggered(int index, Widget child) {
    if (index >= _entrances.length) return child;
    return AnimatedBuilder(
      animation: _entrances[index],
      builder: (context, child) {
        final t = _entrances[index].value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, MitlistAnimations.cardEnterOffset * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _HouseholdIntro extends StatelessWidget {
  const _HouseholdIntro({required this.group});

  final Group? group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final desc = group?.description?.trim();

    if (desc != null && desc.isNotEmpty) {
      return SelectionArea(
        child: Text(
          desc,
          style: textTheme.bodyLarge,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Text(
      'Lists, money, chores, and recipes in one place.',
      style: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _HubDestinationRow extends StatelessWidget {
  const _HubDestinationRow({
    required this.iconName,
    required this.label,
    required this.subtitle,
    required this.semanticLabel,
    required this.routeName,
  });

  final String iconName;
  final String label;
  final String subtitle;
  final String semanticLabel;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    void handleTap() {
      Haptics.light();
      context.pushNamed(routeName);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      interactive: true,
      semanticLabel: semanticLabel,
      onTap: handleTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIcon(
            name: iconName,
            size: 24,
            color: colorScheme.primary,
          ),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ExcludeSemantics(
            child: AppIcon(
              name: 'chevronRight',
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeleton(width: 260, height: 20),
          const SizedBox(height: MitlistSpacing.lg),
          ...List.generate(4, (i) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == 3 ? 0 : MitlistSpacing.sm,
              ),
              child: const _SkeletonRow(),
            );
          }),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        children: [
          AppSkeleton(width: 24, height: 24),
          SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 100, height: 16),
                SizedBox(height: MitlistSpacing.xs),
                AppSkeleton(width: 160, height: 12),
              ],
            ),
          ),
          AppSkeleton(width: 20, height: 20),
        ],
      ),
    );
  }
}
