import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:intl/intl.dart';
import '../../models/chore_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show BottomNavScaffold, currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/chore_detail_sheet.dart';
import '../../sheets/chore_load_sheet.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/shell_tab_load.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/animated_strikethrough.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';

class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  bool _isLoading = true;
  String? _error;
  final List<_Chore> _chores = [];
  StreamSubscription<List<CurrentChore>>? _sub;
  bool _filterMe = true;
  bool _isMutating = false;
  bool _hasHousehold = false;
  String? _groupId;
  final Logger _logger = Logger();
  Map<String, String> _memberNames = {};
  List<ChoreLoadEntry> _load = const [];
  String? _myUserId;

  static const double _labelMediumLineHeight = 16.0;

  // Pinned section header (Overdue / Today / This week / Later).
  static const double _sectionHeaderHeight =
      MitlistSpacing.sm + _labelMediumLineHeight + MitlistSpacing.sm;

  bool _tabLoadStarted = false;
  bool _insideShell = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getBool('chores_filter_me');
      if (!mounted) return;
      if (saved != null) setState(() => _filterMe = saved);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateTabIfNeeded());
  }

  void _activateTabIfNeeded() {
    if (_tabLoadStarted || !mounted) return;
    final insideShell =
        context.findAncestorWidgetOfExactType<BottomNavScaffold>() != null;
    _insideShell = insideShell;
    if (insideShell && !shouldActivateShellTab(ref, choresShellTabIndex)) {
      return;
    }
    _tabLoadStarted = true;
    _loadChores();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadChores() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(currentGroupIdProvider.notifier).ensureLoaded();
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!isValidGroupId(groupId)) {
        if (!mounted) return;
        setState(() {
          _chores.clear();
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      final repo = await ref.read(choreRepositoryProvider.future);

      // Load member display names so assignee avatars and turn labels show
      // real names.
      try {
        final groupService = await ref.read(groupServiceProviderAsync.future);
        final members = await groupService.listMembers(groupId!);
        if (mounted) {
          setState(() {
            _memberNames = {for (final m in members) m.userId: m.displayName};
          });
        }
      } catch (_) {}

      await _sub?.cancel();
      final gid = groupId!;
      _groupId = gid;
      _sub = repo.watchCurrentChores(gid).listen((currentChores) {
        if (!mounted) return;
        _applyCurrentChores(currentChores);
      });

      // Attach SSE so completions from other household members arrive live.
      final sseService = ref.read(sseServiceProvider);
      repo.attachSse(sseService, gid);

      final cached = await repo.getCurrentChoresOnce(gid);
      if (!mounted) return;
      _applyCurrentChores(cached, allowSkeleton: cached.isEmpty);

      // Background refresh; keep cache if it fails.
      unawaited(repo.refreshCurrentChores(gid).catchError((e) {
        _logger.w('Background chores refresh failed', error: e);
      }));

      // Best-effort context for the fairness strip: who I am (to highlight my
      // share) and how the load has been split over the last 30 days. The UI
      // is already rendered from cache, so these only enrich it.
      if (_insideShell) {
        unawaited(_loadFairnessContext(gid));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load chores. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFairnessContext(String gid) async {
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final me = await authService.getMe();
      if (mounted) setState(() => _myUserId = me.id);
    } catch (_) {}
    try {
      final choreService = await ref.read(choreServiceProviderAsync.future);
      final load = await choreService.getChoreLoad(gid, days: 30);
      if (mounted) setState(() => _load = load);
    } catch (e) {
      _logger.w('Chore load fetch failed', error: e);
    }
  }

  void _applyCurrentChores(List<CurrentChore> currentChores,
      {bool allowSkeleton = false}) {
    final now = DateTime.now();
    final chores = currentChores
        .map((entry) => _Chore(
              assignmentId: entry.pendingAssignment?.id,
              id: entry.chore.id,
              title: entry.chore.name,
              assigneeInitials:
                  _initialsFor(entry.pendingAssignment?.userId, _memberNames),
              assigneeName: _memberNames[entry.pendingAssignment?.userId ?? ''],
              dueDate: entry.pendingAssignment?.dueDate ??
                  _fallbackDueDate(now, entry.chore.frequency),
              frequency: entry.chore.frequency,
              periodInterval: entry.chore.periodInterval,
              category: entry.chore.category,
              isMine: entry.assignedToMe,
              completed: !entry.chore.isActive ||
                  entry.pendingAssignment?.status.toLowerCase() == 'completed',
              lastActionLabel: entry.lastAssignment != null
                  ? _formatLastAction(entry.lastAssignment!)
                  : null,
              supplies: entry.chore.supplies,
            ))
        .toList();

    setState(() {
      _chores
        ..clear()
        ..addAll(chores);
      _hasHousehold = true;
      _isLoading = allowSkeleton && chores.isEmpty;
      _error = null;
    });
  }

  Future<void> _onRefresh() => _loadChores();

  Future<void> _addChore() async {
    unawaited(Haptics.light());
    final created = await ChoreCreationSheet.show(context);
    if (created == true) {
      await _loadChores();
    }
  }

  Future<void> _openLoadSheet() async {
    unawaited(Haptics.light());
    await ChoreLoadSheet.show(
      context,
      entries: _load,
      memberNames: _memberNames,
      days: 30,
    );
  }

  Future<void> _openChoreDetail(String id) async {
    final chore = _chores.firstWhere((item) => item.id == id);
    ChoreDetails? details;
    List<ChoreSubtask> subtasks = [];
    try {
      final service = await ref.read(choreServiceProviderAsync.future);
      details = await service.getChoreDetails(id);
      subtasks = await service.listSubtasks(id);
    } catch (_) {
      // Keep the sheet available when an older API does not expose details yet.
    }
    if (!mounted) return;
    unawaited(Haptics.light());
    await ChoreDetailSheet.show(
      context,
      choreId: id,
      title: details?.chore.name ?? chore.title,
      statusLabel: _statusLabel(details?.dueStatus, chore.completed),
      assignee: details?.pendingAssignment?.userId != null
          ? _shortUserLabel(details!.pendingAssignment!.userId)
          : chore.assigneeInitials,
      dueDate: details?.pendingAssignment?.dueDate ?? chore.dueDate,
      trackedCount: details?.stats.trackedCount,
      lastTrackedAt: details?.stats.lastTrackedAt,
      lastDoneByLabel: details?.stats.lastDoneByUserId != null
          ? _shortUserLabel(details!.stats.lastDoneByUserId!)
          : null,
      averageFrequencyHours: details?.stats.averageFrequencyHours,
      subtasks: subtasks,
      supplies: details?.chore.supplies ?? [],
      onMarkDone: chore.completed
          ? null
          : () async {
              Navigator.of(context).pop();
              await _toggleComplete(id);
            },
      onSkip: chore.completed
          ? null
          : (reason) async {
              Navigator.of(context).pop();
              await _skipChore(id, reason: reason);
            },
      onRescheduleTomorrow: chore.completed
          ? null
          : () async {
              Navigator.of(context).pop();
              await _rescheduleTomorrow(id);
            },
      onUndo: () async {
        Navigator.of(context).pop();
        await _undoLastExecution(id);
      },
      onToggleSubtask: (subtaskId, completed) async {
        if (_isMutating) return;
        _isMutating = true;
        try {
          final service = await ref.read(choreServiceProviderAsync.future);
          await service.updateSubtask(subtaskId, completed: completed);
        } catch (e) {
          if (!mounted) return;
          _showChoreActionError('Failed to update subtask. Please try again.');
        } finally {
          _isMutating = false;
        }
      },
      onAddSubtask: (title) async {
        if (_isMutating) return null;
        _isMutating = true;
        try {
          final service = await ref.read(choreServiceProviderAsync.future);
          final created = await service.createSubtask(id, title);
          return created.id;
        } catch (e) {
          if (!mounted) return null;
          _showChoreActionError('Failed to add subtask. Please try again.');
          return null;
        } finally {
          _isMutating = false;
        }
      },
      onDeleteSubtask: (subtaskId) async {
        if (_isMutating) return;
        _isMutating = true;
        try {
          final service = await ref.read(choreServiceProviderAsync.future);
          await service.deleteSubtask(subtaskId);
        } catch (e) {
          if (!mounted) return;
          unawaited(Haptics.failure());
          _showChoreActionError(friendlyErrorMessage(e));
        } finally {
          _isMutating = false;
        }
      },
      onAddSuppliesToList: () async {
        await _addSuppliesToList(id);
      },
      onDelete: () => _confirmDeleteChore(id),
    );
  }

  String _statusLabel(String? dueStatus, bool completed) {
    if (completed) return 'Done';
    return switch (dueStatus) {
      'overdue' => 'Overdue',
      'due_today' => 'Due today',
      'due_soon' => 'Due soon',
      'later' => 'Scheduled',
      _ => 'Pending',
    };
  }

  String _shortUserLabel(String userId) {
    final name = _memberNames[userId];
    if (name != null && name.isNotEmpty) return name;
    if (userId.length <= 8) return userId;
    return userId.substring(0, 8);
  }

  /// Quiet sync: pulls fresh data without resetting the stream subscription
  /// or flashing skeletons. Used after mutations that bypass the repo cache.
  Future<void> _refreshQuietly() async {
    final gid = _groupId;
    if (gid == null) return;
    try {
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.refreshCurrentChores(gid);
    } catch (e) {
      _logger.w('Quiet chores refresh failed', error: e);
    }
  }

  Future<void> _toggleComplete(String id) async {
    if (_isMutating) return;
    _isMutating = true;
    try {
      final chore = _chores.firstWhere((c) => c.id == id);
      if (chore.completed) {
        return;
      }
      // Optimistic: strike through instantly; the repo patches its cache and
      // reconciles with the server in the background.
      setState(() => chore.completed = true);
      unawaited(Haptics.success());
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.completeOfflineFirst(id, groupId: _groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${chore.title} done',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoComplete(id),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final chore = _chores.where((c) => c.id == id).firstOrNull;
        chore?.completed = false;
      });
      _showChoreActionError('Failed to complete chore. Please try again.');
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _undoComplete(String id) async {
    try {
      unawaited(Haptics.light());
      setState(() {
        final chore = _chores.where((c) => c.id == id).firstOrNull;
        chore?.completed = false;
      });
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.undoOfflineFirst(id, groupId: _groupId);
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError(
          'Failed to undo chore execution. Please try again.');
    }
  }

  Future<void> _skipChore(String id, {String? reason}) async {
    if (_isMutating) return;
    _isMutating = true;
    try {
      if (reason != null && reason.isNotEmpty) {
        final service = await ref.read(choreServiceProviderAsync.future);
        await service.skipChore(id, skipReason: reason);
        await _refreshQuietly();
      } else {
        final repo = await ref.read(choreRepositoryProvider.future);
        await repo.skipOfflineFirst(id, groupId: _groupId);
      }
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError('Failed to skip chore. Please try again.');
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _addSuppliesToList(String choreId) async {
    if (_isMutating) return;
    _isMutating = true;
    try {
      final listSvc = await ref.read(listServiceProviderAsync.future);
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) return;
      final lists = await listSvc.listLists(groupId, limit: 50);
      final shoppingLists = lists
          .where((l) => l.type == 'shopping' || l.type == 'general')
          .toList();
      if (shoppingLists.isEmpty) {
        if (!mounted) return;
        _showChoreActionError('Create a shopping list first.');
        return;
      }
      if (!mounted) return;
      final selectedList = await showAppDialog<String>(
        context: context,
        title: 'Add supplies to list',
        body: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: shoppingLists.length,
            itemBuilder: (_, idx) {
              final list = shoppingLists[idx];
              return ListTile(
                title: Text(
                  list.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(list.id),
              );
            },
          ),
        ),
      );
      if (selectedList == null) return;
      final choreSvc = await ref.read(choreServiceProviderAsync.future);
      await choreSvc.addSuppliesToList(choreId, selectedList);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplies added to list')),
      );
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError('Failed to add supplies. Please try again.');
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _rescheduleTomorrow(String id) async {
    if (_isMutating) return;
    _isMutating = true;
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.rescheduleOfflineFirst(id, tomorrow, groupId: _groupId);
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError('Failed to reschedule chore. Please try again.');
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _undoLastExecution(String id) async {
    if (_isMutating) return;
    _isMutating = true;
    try {
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.undoOfflineFirst(id, groupId: _groupId);
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError(
          'Failed to undo chore execution. Please try again.');
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _confirmDeleteChore(String id) async {
    if (_isMutating) return;
    _isMutating = true;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete chore',
      body: const Text(
          'This will permanently delete this chore and its history. This cannot be undone.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Delete',
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) {
      _isMutating = false;
      return;
    }
    Navigator.of(context).pop();
    try {
      final service = await ref.read(choreServiceProviderAsync.future);
      await service.deleteChore(id);
      await _refreshQuietly();
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      _showChoreActionError(friendlyErrorMessage(e));
    } finally {
      _isMutating = false;
    }
  }

  void _showChoreActionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_Chore> get _filteredChores {
    if (_filterMe) {
      return _chores.where((c) => c.isMine).toList();
    }
    return _chores.toList();
  }

  void _setFilterMe(bool value) {
    setState(() => _filterMe = value);
    SharedPreferences.getInstance()
        .then((p) => p.setBool('chores_filter_me', value));
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

  static const List<String> _dueOrder = [
    'Overdue',
    'Today',
    'This week',
    'Later',
  ];

  /// Chores assigned to me that need doing now (overdue or due today). This is
  /// the "your turn" set the hero leads with.
  List<_Chore> _myTurnNow() {
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _chores.where((c) {
      if (!c.isMine || c.completed) return false;
      final due = DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day);
      return due.isBefore(tomorrow);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellVisitedTabsProvider, (previous, next) {
      _activateTabIfNeeded();
    });
    ref.listen<String?>(currentGroupIdProvider, (previous, next) {
      if (previous != next) {
        _loadChores();
      }
    });

    final filtered = _filteredChores;
    final sections = _groupBySection(filtered);
    final myActive = _chores.where((c) => c.isMine && !c.completed).length;
    final totalActive = _chores.where((c) => !c.completed).length;
    final myTurn = _myTurnNow();

    final showHeader =
        _hasHousehold && !_isLoading && _error == null && _chores.isNotEmpty;

    return Scaffold(
      appBar: MitlistAppBar.titleText('Chores'),
      floatingActionButton: AppButton(
        size: AppButtonSize.lg,
        onPressed:
            _hasHousehold ? _addChore : () => context.goNamed('groupsList'),
        icon: AppIcon(
          name: _hasHousehold ? 'plus' : 'userGroup',
        ),
        text: _hasHousehold ? 'Add chore' : 'Households',
        tooltip: _hasHousehold ? 'Add chore' : 'Households',
      ),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_isLoading) ...[
              const SliverToBoxAdapter(child: _HeaderSkeleton()),
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
                      lottieAsset: 'assets/animations/lottie/House.lottie',
                      icon: AppIcon(
                        name: 'userGroup',
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: 'No household yet',
                      description:
                          'Create or join a household before adding chores.',
                      actions: [
                        AppButton(
                          text: 'Go to households',
                          onPressed: () => context.goNamed('groupsList'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (_chores.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: AppEmptyState(
                      lottieAsset: 'assets/animations/lottie/Chores.lottie',
                      icon: AppIcon(
                        name: 'clipboardDocumentList',
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: 'No chores yet',
                      description:
                          'Track recurring household tasks. Assign them to anyone in your group.',
                      actions: [
                        AppButton(
                          text: 'Add a chore',
                          icon: AppIcon(
                            name: 'plus',
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: _addChore,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (showHeader)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MitlistSpacing.md,
                      MitlistSpacing.md,
                      MitlistSpacing.md,
                      MitlistSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TurnHero(
                          myTurn: myTurn,
                          myActiveCount: myActive,
                          totalActiveCount: totalActive,
                          overdueCount: sections['Overdue']!
                              .where((c) => !c.completed)
                              .length,
                          todayCount: sections['Today']!
                              .where((c) => !c.completed)
                              .length,
                          filterMe: _filterMe,
                          onShowMine: () => _setFilterMe(true),
                          onShowEveryone: () => _setFilterMe(false),
                        ),
                        const SizedBox(height: MitlistSpacing.sm),
                        _FairnessStrip(
                          entries: _load,
                          memberNames: _memberNames,
                          myUserId: _myUserId,
                          onTap: _openLoadSheet,
                        ),
                      ],
                    ),
                  ),
                ),
              if (filtered.isEmpty && _filterMe)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MitlistSpacing.md,
                      MitlistSpacing.xl,
                      MitlistSpacing.md,
                      MitlistSpacing.md,
                    ),
                    child: AppEmptyState(
                      icon: AppIcon(
                        name: 'checkCircle',
                        size: 48,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      title: 'Nothing on you right now',
                      description:
                          'Your household has chores, but none are assigned to you.',
                      actions: [
                        AppButton(
                          text: 'See everyone\'s chores',
                          variant: AppButtonVariant.outline,
                          onPressed: () => _setFilterMe(false),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final section in _dueOrder)
                  if (sections[section]!.isNotEmpty) ...[
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        height: _sectionHeaderHeight,
                        child: Container(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          padding: const EdgeInsets.symmetric(
                            horizontal: MitlistSpacing.md,
                            vertical: MitlistSpacing.sm,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
                            return ListEntrance(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: MitlistSpacing.sm,
                                ),
                                child: _ChoreItem(
                                  chore: chore,
                                  onToggle: () => _toggleComplete(chore.id),
                                  onTap: () => _openChoreDetail(chore.id),
                                ),
                              ),
                            );
                          },
                          childCount: sections[section]!.length,
                        ),
                      ),
                    ),
                  ],
              const SliverToBoxAdapter(
                child: SizedBox(height: MitlistSpacing.space20),
              ),
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
      color: Theme.of(context).colorScheme.surface,
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
  final String? assignmentId;
  final String title;
  final String assigneeInitials;
  final String? assigneeName;
  final DateTime dueDate;
  final String frequency;
  final int periodInterval;
  final String? category;
  final bool isMine;
  bool completed;
  final String? lastActionLabel;
  final List<String> supplies;

  _Chore({
    required this.id,
    this.assignmentId,
    required this.title,
    required this.assigneeInitials,
    this.assigneeName,
    required this.dueDate,
    this.frequency = 'none',
    this.periodInterval = 1,
    this.category,
    this.isMine = true,
    this.completed = false,
    this.lastActionLabel,
    this.supplies = const [],
  });

  /// Short label for whose turn it is: "Your turn", "Sam's turn", or null when
  /// unassigned.
  String? turnLabel() {
    if (isMine) return 'Your turn';
    final name = assigneeName;
    if (name != null && name.isNotEmpty) return "$name's turn";
    return null;
  }
}

/// The people-first hero: leads with what's on *you* right now, and how much
/// of the household's open load you're carrying.
class _TurnHero extends StatelessWidget {
  final List<_Chore> myTurn;
  final int myActiveCount;
  final int totalActiveCount;
  final int overdueCount;
  final int todayCount;
  final bool filterMe;
  final VoidCallback onShowMine;
  final VoidCallback onShowEveryone;

  const _TurnHero({
    required this.myTurn,
    required this.myActiveCount,
    required this.totalActiveCount,
    required this.overdueCount,
    required this.todayCount,
    required this.filterMe,
    required this.onShowMine,
    required this.onShowEveryone,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final caughtUp = myTurn.isEmpty;

    final dueNowCount = myTurn.length;
    final shareLabel = totalActiveCount == 0
        ? 'Nothing on you right now'
        : 'Carrying $myActiveCount of $totalActiveCount open chores';

    return Semantics(
      label: caughtUp
          ? 'You are all caught up'
          : '$dueNowCount due now. $shareLabel',
      child: AppCard(
        variant: caughtUp ? AppCardVariant.outlined : AppCardVariant.filled,
        tint: caughtUp ? AppCardTint.neutral : AppCardTint.primary,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: MitlistSpacing.space11,
                  height: MitlistSpacing.space11,
                  decoration: BoxDecoration(
                    color: caughtUp
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.surface,
                    border: Border.all(color: colorScheme.outline, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(
                    name: caughtUp ? 'checkCircle' : 'cleaningServices',
                    size: 24,
                    color:
                        caughtUp ? colorScheme.tertiary : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caughtUp ? "You're clear" : 'Your turn',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MitlistSpacing.xs),
                      Text(
                        caughtUp
                            ? shareLabel
                            : '$dueNowCount ${dueNowCount == 1 ? 'chore needs' : 'chores need'} you now. $shareLabel.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.md),
            Wrap(
              spacing: MitlistSpacing.sm,
              runSpacing: MitlistSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppChip(
                  label: 'Me ($myActiveCount)',
                  selected: filterMe,
                  onSelected: (_) => onShowMine(),
                ),
                AppChip(
                  label: 'Everyone ($totalActiveCount)',
                  selected: !filterMe,
                  onSelected: (_) => onShowEveryone(),
                ),
                _HeaderCountChip(label: 'Overdue', count: overdueCount),
                _HeaderCountChip(label: 'Today', count: todayCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCountChip extends StatelessWidget {
  final String label;
  final int count;

  const _HeaderCountChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.sm,
        vertical: MitlistSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: Text(
        '$label $count',
        style: MitlistTypography.labelXSmall(
          color: count > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ).copyWith(fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w500),
      ),
    );
  }
}

/// Inline fairness read: who's carried the household load over the last 30
/// days. Your share is the brand color so an uneven split is obvious at a
/// glance. Tap for the per-member breakdown.
class _FairnessStrip extends StatelessWidget {
  final List<ChoreLoadEntry> entries;
  final Map<String, String> memberNames;
  final String? myUserId;
  final VoidCallback onTap;

  const _FairnessStrip({
    required this.entries,
    required this.memberNames,
    required this.myUserId,
    required this.onTap,
  });

  String _nameFor(String userId) {
    if (userId == myUserId) return 'You';
    final name = memberNames[userId];
    if (name != null && name.isNotEmpty) return name;
    return userId.length <= 6 ? userId : userId.substring(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Merge so every known member shows, including those at zero.
    final counts = <String, int>{for (final id in memberNames.keys) id: 0};
    for (final e in entries) {
      counts[e.userId] = e.completedCount;
    }
    final rows = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : _nameFor(a.key).compareTo(_nameFor(b.key));
      });
    final total = rows.fold<int>(0, (sum, e) => sum + e.value);

    // Neutral tones cycled for everyone who isn't you, so adjacent segments
    // stay distinguishable while "you" keeps the brand color.
    final otherTones = <Color>[
      colorScheme.onSurfaceVariant,
      colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      colorScheme.outline,
    ];
    Color toneFor(String userId, int otherIndex) => userId == myUserId
        ? colorScheme.primary
        : otherTones[otherIndex % otherTones.length];

    final header = Row(
      children: [
        AppIcon(
          name: 'chartBar',
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: MitlistSpacing.space2),
        Text(
          'How it splits',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          'Last 30 days',
          style: MitlistTypography.labelXSmall(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: MitlistSpacing.space1),
        AppIcon(
          name: 'chevronRight',
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );

    Widget body;
    if (total == 0) {
      body = Text(
        'No chores logged yet. Be the first to mark one done.',
        style:
            textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    } else {
      var otherIndex = 0;
      final segments = <Widget>[];
      final legend = <Widget>[];
      for (final entry in rows) {
        if (entry.value <= 0) continue;
        final isMe = entry.key == myUserId;
        final color = toneFor(entry.key, isMe ? 0 : otherIndex);
        if (!isMe) otherIndex++;
        segments.add(
          Expanded(
            flex: entry.value,
            child: Container(color: color),
          ),
        );
        legend.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, color: color),
              const SizedBox(width: MitlistSpacing.space1),
              Text(
                '${_nameFor(entry.key)} ${entry.value}',
                style: MitlistTypography.labelXSmall(
                  color:
                      isMe ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ).copyWith(
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MitlistSpacing.space2,
            child: Row(children: segments),
          ),
          const SizedBox(height: MitlistSpacing.space2),
          Wrap(
            spacing: MitlistSpacing.md,
            runSpacing: MitlistSpacing.space1,
            children: legend,
          ),
        ],
      );
    }

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.sm,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: MitlistSpacing.sm),
          body,
        ],
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => AppSkeleton(
              width: constraints.maxWidth,
              height: MitlistSpacing.space20,
              borderRadius: AppSkeletonRadius.sm,
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => AppSkeleton(
              width: constraints.maxWidth,
              height: MitlistSpacing.space16,
              borderRadius: AppSkeletonRadius.sm,
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          Row(
            children: [
              AppSkeleton(
                width: MitlistSpacing.space12,
                height: MitlistSpacing.space11,
                borderRadius: AppSkeletonRadius.sm,
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AppSkeleton(
                width: MitlistSpacing.space20,
                height: MitlistSpacing.space11,
                borderRadius: AppSkeletonRadius.sm,
              ),
            ],
          ),
        ],
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isComplete = chore.completed;
    final turnLabel = chore.turnLabel();
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.sm,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: chore.title,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedCheckToggle(
                value: isComplete,
                onChanged: (_) => onToggle(),
                semanticLabelOn: 'Mark ${chore.title} as not done',
                semanticLabelOff: 'Mark ${chore.title} as done',
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: MitlistSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedStrikethrough(
                        text: chore.title,
                        struck: isComplete,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: MitlistSpacing.space1),
                      Wrap(
                        spacing: MitlistSpacing.sm,
                        runSpacing: MitlistSpacing.space1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaChip(
                            icon: 'arrowPath',
                            label: _frequencyLabel(
                                chore.frequency, chore.periodInterval),
                            color: colorScheme.onSurfaceVariant,
                          ),
                          if (turnLabel != null && !isComplete)
                            _MetaChip(
                              dot: true,
                              label: turnLabel,
                              color: chore.isMine
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              emphasized: chore.isMine,
                            ),
                          if (chore.supplies.isNotEmpty)
                            _MetaChip(
                              icon: 'inventoryOutline',
                              label:
                                  '${chore.supplies.length} ${chore.supplies.length == 1 ? 'supply' : 'supplies'}',
                              color: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      if (chore.lastActionLabel != null &&
                          chore.lastActionLabel!.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: MitlistSpacing.space1),
                          child: Text(
                            chore.lastActionLabel!,
                            style: MitlistTypography.labelXSmall(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: MitlistSpacing.space6,
                    height: MitlistSpacing.space6,
                    decoration: BoxDecoration(
                      color: chore.isMine
                          ? colorScheme.primary
                          : colorScheme.primaryContainer,
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      chore.assigneeInitials,
                      style: MitlistTypography.labelXSmall(
                        color: chore.isMine
                            ? colorScheme.onPrimary
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.space1),
                  Text(
                    _formatDate(chore.dueDate),
                    style: MitlistTypography.labelXSmall(
                      color: isComplete ? colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline metadata pill used on chore rows (recurrence, whose turn,
/// supplies). Not interactive; sized far below a tap target on purpose.
class _MetaChip extends StatelessWidget {
  final String? icon;
  final bool dot;
  final String label;
  final Color color;
  final bool emphasized;

  const _MetaChip({
    this.icon,
    this.dot = false,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot)
          Container(width: 6, height: 6, color: color)
        else if (icon != null)
          AppIcon(name: icon!, size: 12, color: color),
        const SizedBox(width: MitlistSpacing.space1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MitlistTypography.labelXSmall(color: color).copyWith(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
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

String _frequencyLabel(String frequency, int interval) {
  if (interval > 1) {
    final unit = switch (frequency) {
      'hourly' => 'hours',
      'daily' => 'days',
      'weekly' => 'weeks',
      'monthly' => 'months',
      'yearly' => 'years',
      _ => '',
    };
    if (unit.isNotEmpty) return 'Every $interval $unit';
  }
  return switch (frequency) {
    'hourly' => 'Hourly',
    'daily' => 'Daily',
    'weekly' => 'Weekly',
    'monthly' => 'Monthly',
    'yearly' => 'Yearly',
    'adaptive' => 'As needed',
    _ => 'One-off',
  };
}

String _formatLastAction(ChoreAssignment assignment) {
  if (assignment.completedAt != null) {
    final diff = DateTime.now().difference(assignment.completedAt!);
    if (diff.inDays == 0) return 'Done today';
    if (diff.inDays == 1) return 'Done yesterday';
    return 'Done ${diff.inDays}d ago';
  }
  if (assignment.skipReason != null && assignment.skipReason!.isNotEmpty) {
    return 'Skipped';
  }
  return '';
}

String _initialsFor(String? userId, Map<String, String> names) {
  if (userId == null || userId.isEmpty) return '?';
  final name = names[userId];
  if (name != null && name.isNotEmpty) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
  // Fall back to first alphabetic character in the userId.
  for (final c in userId.split('')) {
    if (RegExp(r'[a-zA-Z]').hasMatch(c)) return c.toUpperCase();
  }
  return '?';
}

DateTime _fallbackDueDate(DateTime now, String frequency) {
  switch (frequency) {
    case 'hourly':
      return now.add(const Duration(hours: 1));
    case 'daily':
      return now.add(const Duration(days: 1));
    case 'weekly':
      return now.add(const Duration(days: 7));
    case 'monthly':
      return DateTime(now.year, now.month + 1, now.day);
    case 'yearly':
      return DateTime(now.year + 1, now.month, now.day);
    default:
      return DateTime(now.year, now.month, now.day);
  }
}
