import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity_models.dart';
import '../../models/auth_models.dart';
import '../../models/group_models.dart';
import '../../providers/activity_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../repositories/hub_repository.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../utils/active_group_context.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/hub/activity_wall.dart';
import '../../widgets/hub/hub_skeleton.dart';
import '../../widgets/hub/pinwall_section.dart';
import '../../widgets/hub/quick_add_sheet.dart';
import '../../widgets/hub/stats_grid.dart';
import '../../widgets/shell_trailing_actions.dart';
import '../../sheets/create_household_sheet.dart';
import '../../sheets/invite_household_sheet.dart';
import '../../sheets/join_household_sheet.dart';
import '../../sheets/group_settings_sheet.dart';

class _HubSnapshot {
  const _HubSnapshot({
    required this.activities,
    required this.activityError,
  });

  final List<ActivityLogModel> activities;
  final bool activityError;
}

class HouseholdHubScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const HouseholdHubScreen({super.key, this.groupId});

  @override
  ConsumerState<HouseholdHubScreen> createState() =>
      _HouseholdHubScreenState();
}

class _HouseholdHubScreenState extends ConsumerState<HouseholdHubScreen> {
  bool _isLoading = true;
  Object? _error;
  Group? _data;
  List<Group> _households = [];
  _HubSnapshot? _snapshot;
  User? _me;
  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<(List<ActivityLogModel>, bool)>? _activitySub;
  String? _resolvedGroupId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_resolveAndLoad);
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _activitySub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HouseholdHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _groupSub?.cancel();
      _groupSub = null;
      _activitySub?.cancel();
      _activitySub = null;
      _resolveAndLoad();
    }
  }

  Future<void> _resolveAndLoad() async {
    if (widget.groupId != null && widget.groupId!.isNotEmpty) {
      _resolvedGroupId = widget.groupId;
      unawaited(ref.read(currentGroupIdProvider.notifier).set(widget.groupId));
      unawaited(_loadData());
      return;
    }

    final saved = ref.read(currentGroupIdProvider);
    if (saved != null) {
      _resolvedGroupId = saved;
      unawaited(_loadData());
      return;
    }

    try {
      final groupSvc = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupSvc.listGroups(limit: 50);
      final gid = resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
      if (!mounted) return;
      if (isValidGroupId(gid)) {
        _resolvedGroupId = gid;
        unawaited(ref.read(currentGroupIdProvider.notifier).set(gid));
        unawaited(_loadData());
      } else {
        _resolvedGroupId = null;
        _households = groups;
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _switchGroup(String newGroupId) async {
    unawaited(ref.read(currentGroupIdProvider.notifier).set(newGroupId));
    setState(() {
      _resolvedGroupId = newGroupId;
      _isLoading = true;
      _error = null;
    });
    unawaited(_groupSub?.cancel());
    _groupSub = null;
    unawaited(_activitySub?.cancel());
    _activitySub = null;
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);

      var households = <Group>[];
      try {
        households = await groupService.listGroups();
      } catch (_) {
      }

      var activities = <ActivityLogModel>[];
      var activityError = false;
      User? me;

      final actF = ref.read(activityServiceProviderAsync.future);
      final authF = ref.read(authServiceProviderAsync.future);

      try {
        final auth = await authF;
        me = await auth.getMe();
      } catch (_) {
        me = null;
      }

      final activityService = await actF;

      final repo = HubRepository(
        db: ref.read(appDatabaseProvider),
        groups: groupService,
        activity: activityService,
      );

      final cachedGroup = await repo.getGroupOnce(_resolvedGroupId!);
      final cachedActivities =
          await repo.getActivitiesOnce(_resolvedGroupId!);
      if (!mounted) return;
      final hadCache =
          cachedGroup != null || cachedActivities.$1.isNotEmpty;
      setState(() {
        _data = cachedGroup;
        _households = households;
        _snapshot = _HubSnapshot(
          activities: cachedActivities.$1,
          activityError: cachedActivities.$2,
        );
        _me = me;
        _isLoading = !hadCache;
      });
      unawaited(ref.read(currentGroupIdProvider.notifier).set(_resolvedGroupId!));

      await _groupSub?.cancel();
      _groupSub = repo.watchGroup(_resolvedGroupId!).listen((g) {
        if (!mounted || g == null) return;
        setState(() => _data = g);
      });

      await _activitySub?.cancel();
      _activitySub =
          repo.watchActivities(_resolvedGroupId!).listen((tuple) {
        if (!mounted) return;
        setState(() {
          _snapshot = _HubSnapshot(
            activities: tuple.$1,
            activityError: tuple.$2,
          );
        });
      });

      try {
        await repo.refresh(_resolvedGroupId!, activityLimit: 10);
        activities =
            (await repo.getActivitiesOnce(_resolvedGroupId!)).$1;
        activityError =
            (await repo.getActivitiesOnce(_resolvedGroupId!)).$2;
      } catch (_) {
      }

      if (!mounted) return;
      setState(() {
        _data = _data;
        _snapshot = _snapshot ??
            _HubSnapshot(
                activities: activities,
                activityError: activityError);
        _me = me;
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

  Future<void> _onRefresh() async {
    ref.invalidate(
        cachedFinanceSummaryByGroupProvider(_resolvedGroupId!));
    ref.invalidate(cachedListsByGroupProvider(_resolvedGroupId!));
    ref.invalidate(
        cachedCurrentChoresByGroupProvider(_resolvedGroupId!));
    ref.invalidate(
        pinwallPostsByGroupProvider(_resolvedGroupId!));
    await _loadData();

    try {
      final financeRepo =
          await ref.read(financeRepositoryProvider.future);
      await financeRepo.refreshGroup(_resolvedGroupId!,
          limit: 50, offset: 0);
    } catch (_) {
    }
    try {
      final listRepo =
          await ref.read(listRepositoryProvider.future);
      await listRepo.refreshLists(_resolvedGroupId!,
          limit: 50, offset: 0);
    } catch (_) {
    }
    try {
      final choreRepo =
          await ref.read(choreRepositoryProvider.future);
      await choreRepo.refreshCurrentChores(_resolvedGroupId!);
    } catch (_) {
    }
    try {
      final pinRepo =
          await ref.read(pinwallRepositoryProvider.future);
      await pinRepo.refreshPosts(_resolvedGroupId!,
          limit: 20, offset: 0);
    } catch (_) {
    }
  }

  Future<void> _openHouseholdSwitcher(BuildContext context) async {
    await Haptics.light();
    var groups = _households;
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      groups = await svc.listGroups();
      if (mounted) setState(() => _households = groups);
    } catch (_) {}
    if (!context.mounted) return;

    final hubContext = context;
    final rowStyle = Theme.of(hubContext).textTheme.bodyMedium;
    final iconColor =
        rowStyle?.color ?? Theme.of(hubContext).colorScheme.onSurface;

    late BuildContext sheetContext;

    Future<void> onCreateResult(Group? group) async {
      if (group == null || !mounted) return;
      try {
        final svc = await ref.read(groupServiceProviderAsync.future);
        final after = await svc.listGroups();
        if (!mounted) return;
        setState(() => _households = after);
        if (hubContext.mounted) unawaited(_switchGroup(group.id));
      } catch (_) {
        if (mounted) await _loadData();
      }
    }

    Future<void> onJoinResult(Group? group) async {
      if (group == null || !mounted) return;
      try {
        final svc = await ref.read(groupServiceProviderAsync.future);
        final after = await svc.listGroups();
        if (!mounted) return;
        setState(() => _households = after);
        if (hubContext.mounted) unawaited(_switchGroup(group.id));
      } catch (_) {
        if (mounted) await _loadData();
      }
    }

    await showAppBottomSheet<void>(
      context: hubContext,
      title: 'Households',
      body: Builder(
        builder: (ctx) {
          sheetContext = ctx;
          final displayGroups = groups.isNotEmpty
              ? groups
              : (_data != null
                  ? <Group>[_data!]
                  : const <Group>[]);

          Widget actionTile({
            required String iconName,
            required String label,
            required VoidCallback onTap,
          }) {
            return Semantics(
              button: true,
              label: label,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: MitlistSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      AppIcon(name: iconName, size: 22, color: iconColor),
                      const SizedBox(width: MitlistSpacing.md),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: rowStyle?.copyWith(
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (displayGroups.isNotEmpty) ...[
                for (final h in displayGroups)
                  Semantics(
                    button: true,
                    label: 'Switch to ${h.name}',
                    child: InkWell(
                      onTap: groups.length >= 2
                          ? () {
                              Navigator.of(sheetContext).pop();
                              if (h.id != _resolvedGroupId!) {
                                _switchGroup(h.id);
                              }
                            }
                          : null,
                      borderRadius: BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: MitlistSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: rowStyle?.copyWith(
                                      fontWeight: h.id == _resolvedGroupId!
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  if (h.memberCount != null)
                                    Text(
                                      '${h.memberCount} ${h.memberCount == 1 ? 'member' : 'members'}',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            if (h.id == _resolvedGroupId!)
                              AppIcon(
                                name: 'check',
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: MitlistSpacing.sm),
                Container(
                  height: 2,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: MitlistSpacing.sm),
              ],
              actionTile(
                iconName: 'addHomeOutline',
                label: 'Create household',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) async {
                    if (!hubContext.mounted) return;
                    final created =
                        await CreateHouseholdSheet.show(hubContext);
                    await onCreateResult(created);
                  });
                },
              ),
              actionTile(
                iconName: 'keyOutline',
                label: 'Join household',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) async {
                    if (!hubContext.mounted) return;
                    final joined =
                        await JoinHouseholdSheet.show(hubContext);
                    await onJoinResult(joined);
                  });
                },
              ),
              actionTile(
                iconName: 'userPlus',
                label: 'Invite to household',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) async {
                    if (!hubContext.mounted) return;
                    await InviteHouseholdSheet.show(
                      hubContext,
                      groupId: _resolvedGroupId!,
                    );
                  });
                },
              ),
              actionTile(
                iconName: 'cog6ToothOutline',
                label: 'Household settings',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) async {
                    if (!hubContext.mounted) return;
                    await GroupSettingsSheet.show(
                      hubContext,
                      groupId: _resolvedGroupId!,
                    );
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onCreateHousehold() async {
    await Haptics.light();
    if (!mounted) return;
    final created = await CreateHouseholdSheet.show(context);
    await _onHouseholdResult(created);
  }

  Future<void> _onJoinHousehold() async {
    await Haptics.light();
    if (!mounted) return;
    final group = await JoinHouseholdSheet.show(context);
    if (group == null || !mounted) return;
    try {
      final groupSvc = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupSvc.listGroups();
      if (!mounted) return;
      setState(() => _households = groups);
      unawaited(_switchGroup(group.id));
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onHouseholdResult(Group? group) async {
    if (group == null || !mounted) return;
    try {
      final groupSvc = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupSvc.listGroups();
      if (!mounted) return;
      setState(() => _households = groups);
      unawaited(_switchGroup(group.id));
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MitlistSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'mitlist',
              style: MitlistTypography.logo(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppIcon(
              name: 'homeOutline',
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: MitlistSpacing.md),
            Text(
              'Welcome to mitlist',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              'Create or join a household to start sharing lists, chores, and expenses.',
              style: bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MitlistSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: 'Create a household',
                icon: const AppIcon(name: 'addHomeOutline'),
                onPressed: _onCreateHousehold,
              ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                size: AppButtonSize.lg,
                text: 'Join with invite code',
                icon: const AppIcon(name: 'keyOutline'),
                onPressed: _onJoinHousehold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    final name = _data?.name ?? 'Home';
    final titleTextStyle =
        Theme.of(context).appBarTheme.titleTextStyle ??
            Theme.of(context).textTheme.titleLarge;
    final screenW = MediaQuery.sizeOf(context).width;
    final padding = MediaQuery.paddingOf(context).horizontal;
    final actionsReserve = MitlistSpacing.space12 * 4 +
        MitlistSpacing.md +
        MitlistSpacing.sm;
    final textMax =
        (screenW - padding - actionsReserve - MitlistSpacing.space6)
            .clamp(MitlistSpacing.space20, screenW);

    return Semantics(
      button: true,
      label: 'Households, current $name',
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () => _openHouseholdSwitcher(context),
          borderRadius: BorderRadius.zero,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: textMax),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleTextStyle,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.xs),
                AppIcon(
                  name: 'chevronDown',
                  size: 24,
                  color: titleTextStyle?.color ??
                      Theme.of(context).colorScheme.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isLoading || _error != null || _resolvedGroupId == null
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: () => showQuickAddSheet(context),
              icon: const AppIcon(name: 'plus'),
              text: 'Quick add',
              tooltip: 'Quick add',
            ),
      body: _isLoading
          ? const HubSkeleton()
          : _resolvedGroupId == null
              ? _buildEmptyState(context)
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppAlert(
                          type: AppAlertType.error,
                          message:
                              'Couldn\u2019t load this household. Check your connection and try again.',
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
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor:
                            Theme.of(context).colorScheme.surface,
                        leading: null,
                        title: _buildAppBarTitle(context),
                        actions: [
                          IconButton(
                            tooltip: 'Calendar',
                            icon: const AppIcon(name: 'calendarDays'),
                            onPressed: () => context.pushNamed('calendar'),
                          ),
                          ...shellTrailingActions(context),
                          const SizedBox(width: MitlistSpacing.xs),
                        ],
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(MitlistSpacing.md),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            StatsGrid(groupId: _resolvedGroupId!),
                            const SizedBox(height: MitlistSpacing.lg),
                            PinwallSection(
                                groupId: _resolvedGroupId!, me: _me),
                            const SizedBox(height: MitlistSpacing.lg),
                            ActivityWall(
                              activities: _snapshot!.activities,
                              activityError:
                                  _snapshot!.activityError,
                              currentUserId: _me?.id,
                            ),
                            const SizedBox(height: MitlistSpacing.xl),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
