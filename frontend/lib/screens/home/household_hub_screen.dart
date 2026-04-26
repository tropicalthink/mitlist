import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/activity_models.dart';
import '../../models/finance_models.dart';
import '../../models/group_models.dart';
import '../../providers/activity_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/skeleton.dart';
import '../../theme/animations.dart';
import '../../theme/spacing.dart';

const _kHubEntrancePrefsKey = 'mitlist.hubEntranceV1.';

class _HubSnapshot {
  const _HubSnapshot({
    required this.listsCount,
    required this.listsCountError,
    required this.choreCount,
    required this.choresError,
    required this.activities,
    required this.activityError,
    this.lastExpense,
    required this.expensesError,
    required this.recipeCount,
    required this.recipesError,
  });

  final int listsCount;
  final bool listsCountError;
  final int choreCount;
  final bool choresError;
  final List<ActivityLogModel> activities;
  final bool activityError;
  final Expense? lastExpense;
  final bool expensesError;
  final int recipeCount;
  final bool recipesError;
}

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
  _HubSnapshot? _snapshot;
  bool _playEntrance = false;

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
      final prefs = await SharedPreferences.getInstance();
      final entranceKey = '$_kHubEntrancePrefsKey${widget.groupId}';
      final alreadyShown = prefs.getBool(entranceKey) ?? false;

      final groupService = await ref.read(groupServiceProviderAsync.future);
      final group = await groupService.getGroup(widget.groupId);

      int listsCount = 0;
      var listsCountError = false;
      int choreCount = 0;
      var choresError = false;
      var activities = <ActivityLogModel>[];
      var activityError = false;
      Expense? lastExpense;
      var expensesError = false;
      var recipeCount = 0;
      var recipesError = false;

      final listF = ref.read(listServiceProviderAsync.future);
      final choreF = ref.read(choreServiceProviderAsync.future);
      final actF = ref.read(activityServiceProviderAsync.future);
      final finF = ref.read(financeServiceProviderAsync.future);
      final recipeF = ref.read(recipeServiceProviderAsync.future);

      final listService = await listF;
      try {
        final lists = await listService.listLists(widget.groupId);
        listsCount = lists.length;
      } catch (_) {
        listsCountError = true;
      }

      final choreService = await choreF;
      try {
        final chores = await choreService.listChores(widget.groupId);
        choreCount = chores.where((c) => c.isActive).length;
      } catch (_) {
        choresError = true;
      }

      final activityService = await actF;
      try {
        activities = await activityService.listActivityLogs(widget.groupId, limit: 5, offset: 0);
      } catch (_) {
        activityError = true;
      }

      final financeService = await finF;
      try {
        final ex = await financeService.listExpenses(widget.groupId, limit: 20, offset: 0);
        if (ex.isNotEmpty) {
          ex.sort((a, b) => b.date.compareTo(a.date));
          lastExpense = ex.first;
        }
      } catch (_) {
        expensesError = true;
      }

      final recipeService = await recipeF;
      try {
        final recipes = await recipeService.listRecipes(limit: 30, offset: 0);
        recipeCount = recipes.length;
      } catch (_) {
        recipesError = true;
      }

      if (!mounted) return;
      setState(() {
        _data = group;
        _snapshot = _HubSnapshot(
          listsCount: listsCount,
          listsCountError: listsCountError,
          choreCount: choreCount,
          choresError: choresError,
          activities: activities,
          activityError: activityError,
          lastExpense: lastExpense,
          expensesError: expensesError,
          recipeCount: recipeCount,
          recipesError: recipesError,
        );
        _playEntrance = !alreadyShown;
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
                    snapshot: _snapshot!,
                    shouldPlayEntrance: _playEntrance,
                    onEntranceFinished: _markEntranceShown,
                  ),
                ),
    );
  }

  Future<void> _markEntranceShown() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('$_kHubEntrancePrefsKey${widget.groupId}', true);
  }
}

class _StaggeredHubContent extends StatefulWidget {
  const _StaggeredHubContent({
    required this.group,
    required this.snapshot,
    required this.shouldPlayEntrance,
    required this.onEntranceFinished,
  });

  final Group? group;
  final _HubSnapshot snapshot;
  final bool shouldPlayEntrance;
  final Future<void> Function() onEntranceFinished;

  @override
  State<_StaggeredHubContent> createState() => _StaggeredHubContentState();
}

class _StaggeredHubContentState extends State<_StaggeredHubContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  static const int _kSegmentCount = 4;

  late final List<Animation<double>> _entrances;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entrances = List<Animation<double>>.generate(_kSegmentCount, (i) {
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
    _stagger.addStatusListener(_onStaggerStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runEntrance());
  }

  void _onStaggerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.shouldPlayEntrance) {
      widget.onEntranceFinished();
    }
  }

  void _runEntrance() {
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _stagger.value = 1;
      if (widget.shouldPlayEntrance) {
        widget.onEntranceFinished();
      }
      return;
    }
    if (widget.shouldPlayEntrance) {
      _stagger.forward();
    } else {
      _stagger.value = 1;
    }
  }

  @override
  void dispose() {
    _stagger.removeStatusListener(_onStaggerStatus);
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
            _HouseholdContextLine(group: widget.group, snapshot: widget.snapshot),
            const SizedBox(height: MitlistSpacing.lg),
            _staggered(
              0,
              _GlanceHeroCard(
                snapshot: widget.snapshot,
              ),
            ),
            if (!widget.snapshot.activityError && widget.snapshot.activities.isNotEmpty) ...[
              const SizedBox(height: MitlistSpacing.md),
              _staggered(
                1,
                _ActivityPreviewCard(activities: widget.snapshot.activities),
              ),
            ],
            const SizedBox(height: MitlistSpacing.md),
            _staggered(
              2,
              _RecipesCallout(
                count: widget.snapshot.recipeCount,
                countError: widget.snapshot.recipesError,
              ),
            ),
            const SizedBox(height: MitlistSpacing.lg),
            _staggered(
              3,
              _AppShortcuts(
                listsSubtitle: _listsShortSubtitle(
                  count: widget.snapshot.listsCount,
                  countError: widget.snapshot.listsCountError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _listsShortSubtitle({required int count, required bool countError}) {
    if (countError) return 'Count unavailable';
    if (count == 0) return 'None yet';
    return '$count list${count == 1 ? '' : 's'}';
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

class _HouseholdContextLine extends StatelessWidget {
  const _HouseholdContextLine({required this.group, required this.snapshot});

  final Group? group;
  final _HubSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final desc = group?.description?.trim();

    final members = group?.memberCount;
    String? line;
    if (members != null) {
      line = members == 1 ? '1 person in this home' : '$members people in this home';
    }

    if (desc != null && desc.isNotEmpty) {
      return SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (line != null)
              Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: Text(
                  line,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            Text(
              desc,
              style: textTheme.bodyLarge,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
    if (line != null) {
      return Text(
        line,
        style: textTheme.bodyLarge,
      );
    }
    if (!snapshot.listsCountError && !snapshot.choresError) {
      final l = snapshot.listsCount;
      final c = snapshot.choreCount;
      return Text(
        l + c == 0
            ? 'Nothing here yet — add a list or a chore to get started.'
            : 'This home has $l list${l == 1 ? '' : 's'} and $c active chore${c == 1 ? '' : 's'}.',
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }
    return Text(
      'A shared place for this household on mitlist.',
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}

class _GlanceHeroCard extends StatelessWidget {
  const _GlanceHeroCard({required this.snapshot});

  final _HubSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final primary = _heroPrimaryAction(snapshot);
    void go() {
      Haptics.light();
      context.pushNamed(primary.route);
    }

    return AppCard(
      variant: AppCardVariant.filled,
      tint: AppCardTint.primary,
      padding: AppCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start here',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            primary.headline,
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            primary.caption,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          if (primary.statsLine != null) ...[
            const SizedBox(height: MitlistSpacing.md),
            Text(
              primary.statsLine!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            text: primary.buttonLabel,
            onPressed: go,
            size: AppButtonSize.lg,
            semanticLabel: primary.buttonLabel,
            tooltip: primary.buttonLabel,
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction {
  const _PrimaryAction({
    required this.route,
    required this.headline,
    required this.caption,
    required this.buttonLabel,
    this.statsLine,
  });

  final String route;
  final String headline;
  final String caption;
  final String buttonLabel;
  final String? statsLine;
}

_PrimaryAction _heroPrimaryAction(_HubSnapshot s) {
  String fmtList() {
    if (s.listsCountError) return 'Lists unknown';
    if (s.listsCount == 0) return 'No lists';
    return '${s.listsCount} list${s.listsCount == 1 ? '' : 's'}';
  }

  String fmtChore() {
    if (s.choresError) return 'Chores unknown';
    if (s.choreCount == 0) return 'No active chores';
    return '${s.choreCount} active chore${s.choreCount == 1 ? '' : 's'}';
  }

  final stats = '${fmtList()} · ${fmtChore()}';

  if (!s.choresError && s.choreCount > 0) {
    return _PrimaryAction(
      route: 'chores',
      headline: 'Chores are active',
      caption: 'Keep the home running—see what’s due in this group.',
      buttonLabel: 'Open chores',
      statsLine: stats,
    );
  }
  if (!s.listsCountError && s.listsCount > 0) {
    return _PrimaryAction(
      route: 'lists',
      headline: 'Your shared lists',
      caption: 'Pick up where you left off on groceries and to-dos.',
      buttonLabel: 'Open lists',
      statsLine: stats,
    );
  }
  if (s.lastExpense != null && !s.expensesError) {
    final d = DateFormat.MMMd().format(s.lastExpense!.date);
    return _PrimaryAction(
      route: 'money',
      headline: 'Money activity',
      caption: 'Last recorded: ${s.lastExpense!.description} ($d).',
      buttonLabel: 'Open money',
      statsLine: stats,
    );
  }
  if (!s.listsCountError && !s.choresError) {
    return _PrimaryAction(
      route: 'lists',
      headline: 'Set up this home',
      caption: 'Add a list, a chore, or an expense to make this space yours.',
      buttonLabel: 'Create a list',
      statsLine: stats,
    );
  }
  return _PrimaryAction(
    route: 'lists',
    headline: 'Welcome',
    caption: 'Open lists to get started, or use the app tabs anytime.',
    buttonLabel: 'Open lists',
    statsLine: null,
  );
}

class _ActivityPreviewCard extends StatelessWidget {
  const _ActivityPreviewCard({required this.activities});

  final List<ActivityLogModel> activities;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final show = activities.take(3).toList();

    return AppCard(
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent in this home',
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: MitlistSpacing.md),
          for (var i = 0; i < show.length; i++) ...[
            if (i > 0) const SizedBox(height: MitlistSpacing.sm),
            _ActivityLine(item: show[i]),
          ],
        ],
      ),
    );
  }
}

String _formatActivityLine(ActivityLogModel a) {
  final when = _relativeDay(a.createdAt);
  final kind = a.entityType.toLowerCase();
  if (kind.contains('expense') || kind.contains('split')) {
    return 'Money update · $when';
  }
  if (kind.contains('chore') || kind.contains('assignment')) {
    return 'Chore activity · $when';
  }
  if (kind.contains('list')) {
    return 'List update · $when';
  }
  return 'Activity ${a.action} · $when';
}

String _relativeDay(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(t.year, t.month, t.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  if (diff < 7) return '$diff days ago';
  return DateFormat.MMMd().format(t);
}

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({required this.item});

  final ActivityLogModel item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      _formatActivityLine(item),
      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
    );
  }
}

class _RecipesCallout extends StatelessWidget {
  const _RecipesCallout({required this.count, required this.countError});

  final int count;
  final bool countError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    void open() {
      Haptics.light();
      context.goNamed('recipes');
    }
    final sub = countError
        ? 'Open your cookbook to browse and save meals — also from the Kitchen tab.'
        : count == 0
            ? 'No recipes saved yet — add your first and build your book.'
            : 'You have $count saved recipe${count == 1 ? '' : 's'}. Open from here or the Kitchen tab.';

    return AppCard(
      variant: AppCardVariant.soft,
      tint: AppCardTint.primary,
      padding: AppCardPadding.lg,
      interactive: true,
      onTap: open,
      semanticLabel: 'Recipes, open cookbook. $sub',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 32,
            color: colorScheme.primary,
          ),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitchen & recipes',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  sub,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: MitlistSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    text: 'Browse recipes',
                    onPressed: open,
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.sm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppShortcuts extends StatelessWidget {
  const _AppShortcuts({required this.listsSubtitle});

  final String listsSubtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Open elsewhere in the app',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        _TextShortcut(
          label: 'Lists',
          detail: listsSubtitle,
          onTap: () {
            Haptics.light();
            context.pushNamed('lists');
          },
        ),
        const Divider(height: 1),
        _TextShortcut(
          label: 'Chores',
          detail: 'Shared tasks',
          onTap: () {
            Haptics.light();
            context.pushNamed('chores');
          },
        ),
        const Divider(height: 1),
        _TextShortcut(
          label: 'Money',
          detail: 'Expenses & balances',
          onTap: () {
            Haptics.light();
            context.pushNamed('money');
          },
        ),
        const Divider(height: 1),
        _TextShortcut(
          label: 'Kitchen',
          detail: 'Recipes & meal ideas',
          onTap: () {
            Haptics.light();
            context.goNamed('recipes');
          },
        ),
        const Divider(height: 1),
        _TextShortcut(
          label: 'You',
          detail: 'Account & profile',
          onTap: () {
            Haptics.light();
            context.pushNamed('you');
          },
        ),
      ],
    );
  }
}

class _TextShortcut extends StatelessWidget {
  const _TextShortcut({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: MitlistSpacing.xs),
                    Text(
                      detail,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                name: 'chevronRight',
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSkeleton(width: 200, height: 18),
          const SizedBox(height: MitlistSpacing.lg),
          AppCard(
            variant: AppCardVariant.filled,
            tint: AppCardTint.primary,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 80, height: 12),
                SizedBox(height: MitlistSpacing.md),
                AppSkeleton(width: 220, height: 22),
                SizedBox(height: MitlistSpacing.sm),
                AppSkeleton(width: 260, height: 16),
                SizedBox(height: MitlistSpacing.lg),
                AppSkeleton(width: double.infinity, height: 44),
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          const AppSkeleton(width: 160, height: 14),
          const SizedBox(height: MitlistSpacing.md),
          ...List.generate(3, (i) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == 2 ? 0 : MitlistSpacing.sm,
              ),
              child: const AppCard(
                child: AppSkeleton(width: double.infinity, height: 40),
              ),
            );
          }),
        ],
      ),
    );
  }
}
