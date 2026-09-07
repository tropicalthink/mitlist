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
import '../../l10n/app_localizations.dart';
import '../../repositories/hub_repository.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../utils/active_group_context.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../theme/list_tile_accent.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/hub/activity_wall.dart';
import '../../widgets/hub/hub_skeleton.dart';
import '../../widgets/hub/onboarding_card.dart';
import '../../widgets/hub/pinwall_section.dart';
import '../../widgets/hub/quick_add_sheet.dart';
import '../../providers/meal_plan_provider.dart';
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
  ConsumerState<HouseholdHubScreen> createState() => _HouseholdHubScreenState();
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

    await ref.read(currentGroupIdProvider.notifier).ensureLoaded();
    final saved = ref.read(currentGroupIdProvider);
    if (saved != null) {
      try {
        final groups = await ref.read(cachedGroupsProvider.future);
        final gid = resolveActiveGroupId(groups, saved);
        if (!mounted) return;
        if (isValidGroupId(gid)) {
          _resolvedGroupId = gid;
          if (gid != saved) {
            unawaited(ref.read(currentGroupIdProvider.notifier).set(gid));
          }
          unawaited(_loadData());
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = e;
          });
        }
        return;
      }
    }

    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final gid =
          resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
      if (!mounted) return;
      if (isValidGroupId(gid)) {
        _resolvedGroupId = gid;
        unawaited(ref.read(currentGroupIdProvider.notifier).set(gid));
        unawaited(_loadData());
      } else {
        // The cache says no household, but the cache can be behind: an
        // invite accepted a moment ago, a household created on another
        // device. Ask the server once before concluding there is nothing
        // here, or a brand-new member is bounced into the setup flow for the
        // very household they just joined.
        final fresh = await _refetchGroups() ?? groups;
        final freshGid =
            resolveActiveGroupId(fresh, ref.read(currentGroupIdProvider));
        if (!mounted) return;
        if (isValidGroupId(freshGid)) {
          _resolvedGroupId = freshGid;
          unawaited(ref.read(currentGroupIdProvider.notifier).set(freshGid));
          unawaited(_loadData());
          return;
        }
        // No household on this account. The board setup flow owns that state;
        // an empty hub behind dead tabs would only restate it with less help.
        // The skeleton stays up for the frame or two the redirect takes.
        _resolvedGroupId = null;
        _households = fresh;
        context.goNamed('onboarding');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e;
        });
      }
    }
  }

  /// A network refresh of the household list, or null when it could not be
  /// done (offline, or a test harness without a repository behind the cache).
  Future<List<Group>?> _refetchGroups() async {
    try {
      await refreshCachedGroups(ref);
      return await ref.read(cachedGroupsProvider.future);
    } catch (_) {
      return null;
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
        households = await ref.read(cachedGroupsProvider.future);
      } catch (_) {}

      var activities = <ActivityLogModel>[];
      var activityError = false;
      User? me;

      final actF = ref.read(activityServiceProviderAsync.future);
      final authF = ref.read(authServiceProviderAsync.future);

      // Paint from the saved profile and refresh it in the background. Awaiting
      // `/auth/me` here held the cached hub behind a full connect timeout on
      // every offline launch.
      try {
        final auth = await authF;
        me = auth.cachedMe;
        unawaited(auth.getMe().then((fresh) {
          if (mounted) setState(() => _me = fresh);
        }).catchError((_) {}));
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
      final cachedActivities = await repo.getActivitiesOnce(_resolvedGroupId!);
      if (!mounted) return;
      final hadCache = cachedGroup != null || cachedActivities.$1.isNotEmpty;
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
      unawaited(
          ref.read(currentGroupIdProvider.notifier).set(_resolvedGroupId!));

      await _groupSub?.cancel();
      _groupSub = repo.watchGroup(_resolvedGroupId!).listen((g) {
        if (!mounted || g == null) return;
        setState(() => _data = g);
      });

      await _activitySub?.cancel();
      _activitySub = repo.watchActivities(_resolvedGroupId!).listen((tuple) {
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
        final tuple = await repo.getActivitiesOnce(_resolvedGroupId!);
        activities = tuple.$1;
        activityError = tuple.$2;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _data = _data;
        _snapshot = _snapshot ??
            _HubSnapshot(activities: activities, activityError: activityError);
        // `_me` may already hold the fresh profile from the background fetch.
        _me ??= me;
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
    ref.invalidate(cachedFinanceSummaryByGroupProvider(_resolvedGroupId!));
    ref.invalidate(cachedListsByGroupProvider(_resolvedGroupId!));
    ref.invalidate(cachedCurrentChoresByGroupProvider(_resolvedGroupId!));
    ref.invalidate(pinwallPostsByGroupProvider(_resolvedGroupId!));
    ref.invalidate(todayMealPlansProvider(_resolvedGroupId!));
    ref.invalidate(weekMealPlansSummaryProvider(_resolvedGroupId!));
    await _loadData();

    try {
      final financeRepo = await ref.read(financeRepositoryProvider.future);
      await financeRepo.refreshGroup(_resolvedGroupId!, limit: 50, offset: 0);
    } catch (_) {}
    try {
      final listRepo = await ref.read(listRepositoryProvider.future);
      await listRepo.refreshLists(_resolvedGroupId!, limit: 50, offset: 0);
    } catch (_) {}
    try {
      final choreRepo = await ref.read(choreRepositoryProvider.future);
      await choreRepo.refreshCurrentChores(_resolvedGroupId!);
    } catch (_) {}
    try {
      final pinRepo = await ref.read(pinwallRepositoryProvider.future);
      // Deliberately the default limit: the hub only renders the first handful
      // of notes, but it shares one cache blob with the board, so refreshing a
      // short page here would drop the board's remaining notes.
      await pinRepo.refreshPosts(_resolvedGroupId!);
    } catch (_) {}
  }

  Future<void> _openHouseholdSwitcher(BuildContext context) async {
    await Haptics.light();
    var groups = _households;
    try {
      await refreshCachedGroups(ref);
      groups = await ref.read(cachedGroupsProvider.future);
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
        await refreshCachedGroups(ref, ensure: group);
        final after = await ref.read(cachedGroupsProvider.future);
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
        await refreshCachedGroups(ref, ensure: group);
        final after = await ref.read(cachedGroupsProvider.future);
        if (!mounted) return;
        setState(() => _households = after);
        if (hubContext.mounted) unawaited(_switchGroup(group.id));
      } catch (_) {
        if (mounted) await _loadData();
      }
    }

    await showAppBottomSheet<void>(
      context: hubContext,
      title: AppLocalizations.of(hubContext)!.hubHouseholdsSheetTitle,
      body: Builder(
        builder: (ctx) {
          sheetContext = ctx;
          final l10n = AppLocalizations.of(ctx)!;
          final displayGroups = groups.isNotEmpty
              ? groups
              : (_data != null ? <Group>[_data!] : const <Group>[]);

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
                          style:
                              rowStyle?.copyWith(fontWeight: FontWeight.w500),
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
                  Builder(builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    final accent = ListTileAccent.fromSeed(
                        h.id, Theme.of(context).brightness);
                    final isActive = h.id == _resolvedGroupId;
                    final trimmed = h.name.trim();
                    final initial = trimmed.isEmpty
                        ? '?'
                        : trimmed.substring(0, 1).toUpperCase();
                    return Semantics(
                      button: true,
                      selected: isActive,
                      label: AppLocalizations.of(context)!
                          .hubSwitchToHousehold(h.name),
                      child: Padding(
                        padding:
                            const EdgeInsets.only(bottom: MitlistSpacing.xs),
                        child: Material(
                          color: isActive
                              ? cs.surfaceContainerHighest
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(MitlistTheme.radiusMd),
                          child: InkWell(
                            onTap: groups.length >= 2
                                ? () {
                                    Navigator.of(sheetContext).pop();
                                    if (!isActive) _switchGroup(h.id);
                                  }
                                : null,
                            borderRadius:
                                BorderRadius.circular(MitlistTheme.radiusMd),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: MitlistSpacing.sm,
                                horizontal: MitlistSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  // Household initial chip, colour-seeded from
                                  // the id so each household reads distinctly.
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: accent.tileBackground,
                                      borderRadius: BorderRadius.circular(
                                          MitlistTheme.radiusSm),
                                      border: Border.all(
                                          color: accent.stripe, width: 2),
                                    ),
                                    child: Text(
                                      initial,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: accent.titleColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: MitlistSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          h.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: rowStyle?.copyWith(
                                            fontWeight: isActive
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        if (h.memberCount != null)
                                          Text(
                                            l10n.commonMember(h.memberCount!),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    AppIcon(
                                      name: 'check',
                                      size: 18,
                                      color: cs.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: MitlistSpacing.sm),
                Container(
                  height: 2,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: MitlistSpacing.sm),
              ],
              actionTile(
                iconName: 'addHomeOutline',
                label: l10n.hubCreateHousehold,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!hubContext.mounted) return;
                    final created = await CreateHouseholdSheet.show(hubContext);
                    await onCreateResult(created);
                  });
                },
              ),
              actionTile(
                iconName: 'keyOutline',
                label: l10n.hubJoinHousehold,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!hubContext.mounted) return;
                    final joined = await JoinHouseholdSheet.show(hubContext);
                    await onJoinResult(joined);
                  });
                },
              ),
              actionTile(
                iconName: 'userPlus',
                label: l10n.hubInviteToHousehold,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
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
                label: l10n.hubHouseholdSettings,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
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

  Widget _buildAppBarTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = _data?.name ?? l10n.hubAppBarTitle;
    final titleTextStyle = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    final screenW = MediaQuery.sizeOf(context).width;
    final padding = MediaQuery.paddingOf(context).horizontal;
    final actionsReserve =
        MitlistSpacing.space12 * 4 + MitlistSpacing.md + MitlistSpacing.sm;
    final textMax = (screenW - padding - actionsReserve - MitlistSpacing.space6)
        .clamp(MitlistSpacing.space20, screenW);

    return Semantics(
      button: true,
      label: l10n.hubHouseholdsCurrent(name),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () => _openHouseholdSwitcher(context),
          borderRadius: BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
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
    // Other screens switch household by writing the provider and coming
    // here: the account page, the households list, a notification tap. This
    // screen lives in the shell's IndexedStack, so nothing rebuilds it for
    // that; it has to follow the provider itself or it keeps showing the
    // house it loaded first. Its own switcher goes through _switchGroup and
    // writes the same id, which this ignores as already current.
    ref.listen<String?>(currentGroupIdProvider, (previous, next) {
      if (next == null || next == previous) return;
      if (widget.groupId != null && widget.groupId!.isNotEmpty) return;
      if (_resolvedGroupId == null || next == _resolvedGroupId) return;
      unawaited(_switchGroup(next));
    });

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      floatingActionButton:
          _isLoading || _error != null || _resolvedGroupId == null
              ? null
              : AppButton(
                  size: AppButtonSize.lg,
                  onPressed: () => showQuickAddSheet(context),
                  icon: const AppIcon(name: 'plus'),
                  text: l10n.hubQuickAdd,
                  tooltip: l10n.hubQuickAdd,
                ),
      body: _isLoading
          ? const HubSkeleton()
          : _error != null && _resolvedGroupId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppAlert(
                          type: AppAlertType.error,
                          message: l10n.hubLoadError,
                        ),
                        const SizedBox(height: MitlistSpacing.md),
                        AppButton(
                          text: l10n.commonRetry,
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _resolveAndLoad();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              // No household: _resolveAndLoad already sent us to the board
              // setup flow; keep the skeleton up while the redirect lands.
              : _resolvedGroupId == null
                  ? const HubSkeleton()
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(MitlistSpacing.md),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppAlert(
                                  type: AppAlertType.error,
                                  message: l10n.hubLoadError,
                                ),
                                const SizedBox(height: MitlistSpacing.md),
                                AppButton(
                                  text: l10n.commonRetry,
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
                                    tooltip: l10n.hubCalendarTooltip,
                                    icon: const AppIcon(name: 'calendarDays'),
                                    onPressed: () =>
                                        context.pushNamed('calendar'),
                                  ),
                                  ...shellTrailingActions(context),
                                  const SizedBox(width: MitlistSpacing.xs),
                                ],
                              ),
                              SliverPadding(
                                padding:
                                    const EdgeInsets.all(MitlistSpacing.md),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    if (!(ref
                                            .watch(
                                                hubQuickStartDismissedProvider)
                                            .valueOrNull ??
                                        true)) ...[
                                      HubQuickStart(
                                        groupId: _resolvedGroupId!,
                                        onDismiss: () => ref.invalidate(
                                            hubQuickStartDismissedProvider),
                                      ),
                                      const SizedBox(height: MitlistSpacing.lg),
                                    ],
                                    PinwallSection(
                                        groupId: _resolvedGroupId!, me: _me),
                                    const SizedBox(height: MitlistSpacing.lg),
                                    ActivityWall(
                                      activities: _snapshot!.activities,
                                      activityError: _snapshot!.activityError,
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
