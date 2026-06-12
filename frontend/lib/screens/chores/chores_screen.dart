import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:intl/intl.dart';
import '../../models/chore_models.dart';
import '../../providers/chore_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/chore_detail_sheet.dart';
import '../../sheets/chore_load_sheet.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/active_group_context.dart';
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
import '../../widgets/odometer.dart';
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
  String _groupMode = 'due'; // 'due' | 'rhythm' | 'zone'
  bool _isMutating = false;
  bool _hasHousehold = true;
  String? _groupId;
  final Logger _logger = Logger();
  Map<String, String> _memberNames = {};

  static const double _headlineSmallLineHeight = 32.0;
  static const double _labelMediumLineHeight = 16.0;

  static const double _stickyHeaderHeight = MitlistSpacing.md +
      MitlistSpacing.md +
      _headlineSmallLineHeight +
      MitlistSpacing.space1 +
      _labelMediumLineHeight +
      MitlistSpacing.md +
      MitlistSpacing.sm +
      MitlistSpacing.space8 +
      MitlistSpacing.sm +
      // Second control row: "By due date / By rhythm" grouping toggle.
      MitlistSpacing.sm +
      MitlistSpacing.space8 +
      MitlistSpacing.md +
      MitlistSpacing.space1 +
      // Extra headroom: AppCard border (2 px × 2 sides) + AppChip height
      // correction (space11=44 vs the space8=32 used above) and text-scale
      // buffer so the header does not overflow at textScaleFactor ≥ 1.0.
      MitlistSpacing.md +
      MitlistSpacing.sm;

  static const double _sectionHeaderHeight =
      MitlistSpacing.sm + _labelMediumLineHeight + MitlistSpacing.sm;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getBool('chores_filter_me');
      final savedMode = prefs.getString('chores_group_mode');
      if (!mounted) return;
      setState(() {
        if (saved != null) _filterMe = saved;
        if (savedMode != null) _groupMode = savedMode;
      });
    });
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
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
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

      // Load member display names so assignee avatars show real initials.
      try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load chores. Please try again.';
        _isLoading = false;
      });
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
              assigneeInitials: _initialsFor(
                  entry.pendingAssignment?.userId, _memberNames),
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
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!isValidGroupId(groupId)) return;
      final choreService = await ref.read(choreServiceProviderAsync.future);
      final entries = await choreService.getChoreLoad(groupId!, days: 30);
      // Make sure names are available even if the list hasn't loaded them yet.
      var names = _memberNames;
      if (names.isEmpty) {
        try {
          final members = await groupService.listMembers(groupId);
          names = {for (final m in members) m.userId: m.displayName};
        } catch (_) {}
      }
      if (!mounted) return;
      await ChoreLoadSheet.show(
        context,
        entries: entries,
        memberNames: names,
        days: 30,
      );
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError('Failed to load chore stats. Please try again.');
    }
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
          _showChoreActionError('Failed to delete subtask. Please try again.');
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
      final groupSvc = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupSvc.listGroups();
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) return;
      final lists = await listSvc.listLists(groupId, limit: 50);
      final shoppingLists = lists.where((l) => l.type == 'shopping' || l.type == 'general').toList();
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
      body: const Text('This will permanently delete this chore and its history. This cannot be undone.'),
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
      _showChoreActionError('Failed to delete chore. Please try again.');
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

  Map<String, List<_Chore>> _groupBySection(List<_Chore> chores) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekLater = today.add(Duration(days: 7));

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

  static const List<String> _rhythmOrder = [
    'Hourly',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'As needed',
    'One-off',
  ];

  String _rhythmBucket(String frequency) => switch (frequency) {
        'hourly' => 'Hourly',
        'daily' => 'Daily',
        'weekly' => 'Weekly',
        'monthly' => 'Monthly',
        'yearly' => 'Yearly',
        'adaptive' => 'As needed',
        _ => 'One-off',
      };

  /// Groups chores by how often they recur, so the household reads its shared
  /// rhythm rather than only what's due next.
  Map<String, List<_Chore>> _groupByRhythm(List<_Chore> chores) {
    final result = {for (final key in _rhythmOrder) key: <_Chore>[]};
    for (final chore in chores) {
      result[_rhythmBucket(chore.frequency)]!.add(chore);
    }
    return result;
  }

  static const List<String> _zonePreferredOrder = [
    'Kitchen',
    'Bathroom',
    'Living room',
    'Bedroom',
    'Outdoor',
    'Shared',
  ];

  /// Groups chores by room/zone so the household sees them as areas of shared
  /// space rather than a flat list. Returns buckets already in display order.
  Map<String, List<_Chore>> _groupByZone(List<_Chore> chores) {
    final map = <String, List<_Chore>>{};
    for (final chore in chores) {
      final raw = chore.category?.trim();
      final key = (raw == null || raw.isEmpty) ? 'Unsorted' : raw;
      (map[key] ??= []).add(chore);
    }
    int rank(String key) {
      final i = _zonePreferredOrder.indexOf(key);
      if (i >= 0) return i;
      return key == 'Unsorted' ? 1000 : 500;
    }

    final keys = map.keys.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    return {for (final key in keys) key: map[key]!};
  }

  ({int overdue, int today, int done}) _computeStats(List<_Chore> chores) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

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
    final sections = switch (_groupMode) {
      'rhythm' => _groupByRhythm(filtered),
      'zone' => _groupByZone(filtered),
      _ => _groupBySection(filtered),
    };
    final sectionOrder = switch (_groupMode) {
      'rhythm' => _rhythmOrder,
      'zone' => sections.keys.toList(),
      _ => _dueOrder,
    };

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Chores',
        actions: _hasHousehold
            ? [
                IconButton(
                  onPressed: _openLoadSheet,
                  icon: const AppIcon(name: 'chartBar'),
                  tooltip: 'Who\'s doing the chores',
                ),
              ]
            : null,
      ),
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
          physics: AlwaysScrollableScrollPhysics(),
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
                            ? Row(
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
                                      labelColor: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                  Expanded(
                                    child: _StatBlock(
                                      count: stats.today,
                                      label: 'Today',
                                      labelColor: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  Expanded(
                                    child: _StatBlock(
                                      count: stats.done,
                                      label: 'Done',
                                      labelColor: Theme.of(context).colorScheme.tertiary,
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppChip(
                                  label: _chores.isEmpty
                                      ? 'Me'
                                      : 'Me (${_chores.where((c) => c.isMine).length})',
                                  selected: _filterMe,
                                  onSelected: (_) {
                                    setState(() => _filterMe = true);
                                    SharedPreferences.getInstance().then((p) => p.setBool('chores_filter_me', true));
                                  },
                                ),
                                const SizedBox(width: MitlistSpacing.sm),
                                AppChip(
                                  label: _chores.isEmpty
                                      ? 'Everyone'
                                      : 'Everyone (${_chores.length})',
                                  selected: !_filterMe,
                                  onSelected: (_) {
                                    setState(() => _filterMe = false);
                                    SharedPreferences.getInstance().then((p) => p.setBool('chores_filter_me', false));
                                  },
                                ),
                              ],
                            ),
                      const SizedBox(height: MitlistSpacing.sm),
                      Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final mode in const [
                                ('due', 'By due date'),
                                ('rhythm', 'By rhythm'),
                                ('zone', 'By zone'),
                              ]) ...[
                                AppChip(
                                  label: mode.$2,
                                  selected: _groupMode == mode.$1,
                                  onSelected: (_) {
                                    setState(() => _groupMode = mode.$1);
                                    SharedPreferences.getInstance().then((p) =>
                                        p.setString('chores_group_mode', mode.$1));
                                  },
                                ),
                                if (mode.$1 != 'zone')
                                  const SizedBox(width: MitlistSpacing.sm),
                              ],
                            ],
                          ),
                        ),
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
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
            ] else if (filtered.isEmpty && _filterMe && _chores.isNotEmpty) ...[
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
                      title: 'No chores assigned to you',
                      description: 'Your household has chores, but none are assigned to you right now.',
                      actions: [
                        AppButton(
                          text: 'See all chores',
                          variant: AppButtonVariant.outline,
                          onPressed: () {
                            setState(() => _filterMe = false);
                            SharedPreferences.getInstance().then((p) => p.setBool('chores_filter_me', false));
                          },
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
                      lottieAsset: 'assets/animations/lottie/Chores.lottie',
                      icon: AppIcon(
                        name: 'clipboardDocumentList',
                        size: 56,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: 'No chores yet',
                      description: 'Track recurring household tasks. Assign them to anyone in your group.',
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
              for (final section in sectionOrder)
                if (sections[section]!.isNotEmpty) ...[
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      height: _sectionHeaderHeight,
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.md,
                          vertical: MitlistSpacing.sm,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          section,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    required this.dueDate,
    this.frequency = 'none',
    this.periodInterval = 1,
    this.category,
    this.isMine = true,
    this.completed = false,
    this.lastActionLabel,
    this.supplies = const [],
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
    final countStyle = Theme.of(context).textTheme.headlineSmall ??
        const TextStyle(fontSize: 24);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: MitlistOdometer(
            value: count,
            textStyle: countStyle,
          ),
        ),
        const SizedBox(height: MitlistSpacing.space1),
        Text(
          label,
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
        AppSkeleton(
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
    final isComplete = chore.completed;
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
                      if (chore.lastActionLabel != null &&
                          chore.lastActionLabel!.isNotEmpty)
                        Text(
                          chore.lastActionLabel!,
                          style: MitlistTypography.labelXSmall(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (chore.supplies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: MitlistSpacing.xs),
                          child: Row(
                            children: [
                              AppIcon(
                                name: 'inventoryOutline',
                                size: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: MitlistSpacing.space1),
                              Text(
                                '${chore.supplies.length} supply${chore.supplies.length == 1 ? '' : 'ies'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MitlistTypography.labelXSmall(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
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
                      color: Theme.of(context).colorScheme.primaryContainer,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      chore.assigneeInitials,
                      style: MitlistTypography.labelXSmall(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.space1),
                  Text(
                    _formatDate(chore.dueDate),
                    style: MitlistTypography.labelXSmall(
                      color: isComplete
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
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
