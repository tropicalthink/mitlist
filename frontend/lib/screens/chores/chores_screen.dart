import 'package:collection/collection.dart';
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
import '../../sheets/chore_zones_sheet.dart';
import '../../theme/animations.dart';
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
import '../../widgets/list/list_settle_collapse.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/odometer.dart';
import '../../l10n/app_localizations.dart';

import '../../widgets/app_toast.dart';

enum _ChoreMenuAction { manageZones }

class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _refreshFailed = false;
  final List<_Chore> _chores = [];

  /// Occurrences completed in the last 48h — the accountability ledger shown
  /// at the bottom ("who did what, when"), separate from the open-turn queue.
  final List<_DoneEntry> _recentlyDone = [];

  /// Chore ids mid-settle: just marked done, card collapsing out of the queue
  /// before landing in the ledger.
  final Set<String> _settlingIds = {};
  bool _doneSectionExpanded = true;

  /// The chore that just settled into the ledger, so its new row can land
  /// visibly (grow + highlight fade) instead of popping in.
  String? _justLandedChoreId;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  StreamSubscription<List<CurrentChore>>? _sub;
  bool _filterMe = true;
  bool _isMutating = false;
  bool _hasHousehold = false;
  String? _groupId;
  final Logger _logger = Logger();
  Map<String, String> _memberNames = {};
  List<ChoreLoadEntry> _load = const [];
  String? _myUserId;

  // Baseline line height for the pinned section header's labelMedium text; the
  // actual header extent is scaled by the user's text scale in build().
  static const double _labelMediumLineHeight = 16.0;

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
      _hasError = false;
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

      // Background refresh; keep cache if it fails, but surface that the list
      // may be stale so the user isn't acting on silently-old data.
      unawaited(repo.refreshCurrentChores(gid).then((_) {
        if (mounted && _refreshFailed) setState(() => _refreshFailed = false);
      }).catchError((e) {
        _logger.w('Background chores refresh failed', error: e);
        if (mounted) setState(() => _refreshFailed = true);
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
        _hasError = true;
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
    final chores = <_Chore>[];
    final done = <_DoneEntry>[];
    final ledgerCutoff = now.subtract(const Duration(hours: 48));

    for (final entry in currentChores) {
      if (!entry.chore.isActive) continue;

      // The pending occurrence is still marked completed/skipped until the
      // server rotates the turn (optimistic cache state). Treat it as a
      // ledger entry rather than a struck row in the queue.
      final pendingDone = const {'completed', 'skipped'}
          .contains(entry.pendingAssignment?.status.toLowerCase());

      if (!pendingDone) {
        chores.add(_Chore(
          assignmentId: entry.pendingAssignment?.id,
          id: entry.chore.id,
          title: entry.chore.name,
          assigneeInitials:
              _initialsFor(entry.pendingAssignment?.userId, _memberNames),
          assigneeName: _memberNames[entry.pendingAssignment?.userId ?? ''],
          hasAssignee: entry.pendingAssignment?.userId != null,
          dueDate: entry.pendingAssignment?.dueDate ??
              _fallbackDueDate(now, entry.chore.frequency),
          frequency: entry.chore.frequency,
          periodInterval: entry.chore.periodInterval,
          category: entry.chore.category,
          isMine: entry.assignedToMe,
          lastActionLabel: entry.lastAssignment != null
              ? _formatLastAction(_l10n, entry.lastAssignment!)
              : null,
          supplies: entry.chore.supplies,
          nextTurnName: entry.nextAssigneeUserId != null
              ? _memberNames[entry.nextAssigneeUserId]
              : null,
        ));
      }

      // Ledger: the last completed occurrence, so the household can see who
      // did what without asking. A chore legitimately appears in BOTH lists
      // (Sam did it 2h ago, Alex's turn is already pending).
      final last = pendingDone ? entry.pendingAssignment : entry.lastAssignment;
      final lastDoneAt = last?.completedAt;
      if (last != null &&
          last.status.toLowerCase() == 'completed' &&
          lastDoneAt != null &&
          lastDoneAt.isAfter(ledgerCutoff)) {
        done.add(_DoneEntry(
          choreId: entry.chore.id,
          title: entry.chore.name,
          completedAt: lastDoneAt,
          byUserId: last.userId,
          byLabel: _memberNames[last.userId],
          byIsMe: last.userId == _myUserId,
          nextDueDate: pendingDone ? null : entry.pendingAssignment?.dueDate,
          nextTurnName: pendingDone
              ? null
              : _memberNames[entry.pendingAssignment?.userId ?? ''],
          nextTurnIsMine: !pendingDone && entry.assignedToMe,
        ));
      }
    }
    done.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    setState(() {
      _chores
        ..clear()
        ..addAll(chores);
      _recentlyDone
        ..clear()
        ..addAll(done);
      _settlingIds.clear();
      _justLandedChoreId = null;
      _hasHousehold = true;
      _isLoading = allowSkeleton && chores.isEmpty && done.isEmpty;
      _hasError = false;
      // Fresh data landed (cache write follows a successful refresh), so any
      // earlier stale-data notice no longer applies.
      _refreshFailed = false;
    });
  }

  Future<void> _onRefresh() => _loadChores();

  Future<void> _addChore() async {
    unawaited(Haptics.light());
    final created = await ChoreCreationSheet.show(context);
    if (created != true || !mounted) return;

    // A queued or household-assigned chore may not be "Mine" yet, so a filtered
    // list would swallow the row the user just watched themselves create. This
    // is the system widening the view for one moment, not the user changing
    // their mind, so it must not overwrite their saved filter preference.
    if (_filterMe) _setFilterMe(false, persist: false);

    // Keep the live subscription and paint the local create immediately.
    // Restarting the entire load waits for member lookup and resubscription
    // before the user can see the chore they just saved.
    final groupId = _groupId;
    if (groupId == null) return;
    final repo = await ref.read(choreRepositoryProvider.future);
    final current = await repo.getCurrentChoresOnce(groupId);
    if (!mounted || _groupId != groupId) return;
    _applyCurrentChores(current);

    // The local row carries no assignment yet: the server picks the turn. Until
    // it lands the row renders bare (no avatar, no assignee, no next-turn line)
    // beside fully dressed neighbours. Refreshing feeds the watch stream, which
    // repaints the row complete. Best-effort: offline it simply stays queued.
    unawaited(repo.refreshCurrentChores(groupId).then((_) {
      if (mounted && _refreshFailed) setState(() => _refreshFailed = false);
    }).catchError((Object e) {
      _logger.w('Post-create chores refresh failed', error: e);
    }));
  }

  Future<void> _openLoadSheet() async {
    unawaited(Haptics.light());
    await ChoreLoadSheet.show(
      context,
      entries: _load,
      memberNames: _memberNames,
      days: 30,
      myUserId: _myUserId,
    );
  }

  /// Opens the prefilled edit sheet for a chore. The full chore is fetched
  /// fresh so the sheet edits what the server has, not the row's summary.
  Future<void> _editChore(String id, {Chore? chore}) async {
    if (chore == null) {
      try {
        final service = await ref.read(choreServiceProviderAsync.future);
        chore = (await service.getChoreDetails(id)).chore;
      } catch (e) {
        if (!mounted) return;
        _showChoreActionError(friendlyErrorMessage(e, _l10n));
        return;
      }
    }
    if (!mounted) return;
    final updated =
        await ChoreCreationSheet.show(context, existingChore: chore);
    if (updated == true) await _loadChores();
  }

  Future<void> _openChoreDetail(String id) async {
    var chore = _chores.firstWhereOrNull((item) => item.id == id);
    if (chore == null) {
      // Opened from the "Done recently" ledger: the queue row is gone, so
      // synthesize the fallbacks the sheet needs; the service fetch below
      // supplies the real details.
      final entry = _recentlyDone.firstWhereOrNull((e) => e.choreId == id);
      if (entry == null) {
        _logger.w('openChoreDetail: chore $id not in local list');
        return;
      }
      chore = _Chore(
        id: entry.choreId,
        title: entry.title,
        assigneeInitials: '',
        hasAssignee: entry.nextTurnName != null,
        dueDate: entry.nextDueDate ?? DateTime.now(),
        completed: true,
      );
    }
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
    // Editing needs the full chore to prefill the sheet, so it's only offered
    // when the details fetch succeeded.
    final choreForEdit = details?.chore;
    await ChoreDetailSheet.show(
      context,
      choreId: id,
      title: details?.chore.name ?? chore.title,
      statusLabel: _statusLabel(details?.dueStatus, chore.completed),
      assignee: details?.pendingAssignment?.userId != null
          ? _shortUserLabel(details!.pendingAssignment!.userId)
          : chore.assigneeInitials,
      nextAssignee: details?.nextAssigneeUserId != null
          ? _shortUserLabel(details!.nextAssigneeUserId!)
          : chore.nextTurnName,
      frequencyLabel: details != null
          ? _frequencyLabel(
              _l10n, details.chore.frequency, details.chore.periodInterval)
          : _frequencyLabel(_l10n, chore.frequency, chore.periodInterval),
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
          _showChoreActionError(_l10n.choreFailedUpdateSubtask);
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
          _showChoreActionError(_l10n.choreFailedAddSubtask);
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
          _showChoreActionError(
              friendlyErrorMessage(e, AppLocalizations.of(context)!));
        } finally {
          _isMutating = false;
        }
      },
      onAddSuppliesToList: () async {
        await _addSuppliesToList(id);
      },
      onEdit: choreForEdit == null
          ? null
          : () async {
              Navigator.of(context).pop();
              await _editChore(id, chore: choreForEdit);
            },
      onDelete: () => _deleteChore(id),
    );
  }

  String _statusLabel(String? dueStatus, bool completed) {
    if (completed) return _l10n.choreStatusDone;
    return switch (dueStatus) {
      'overdue' => _l10n.choreStatusOverdue,
      'due_today' => _l10n.choreStatusDueToday,
      'due_soon' => _l10n.choreStatusDueSoon,
      'later' => _l10n.choreStatusScheduled,
      _ => _l10n.choreStatusPending,
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
      if (mounted && _refreshFailed) setState(() => _refreshFailed = false);
    } catch (e) {
      _logger.w('Quiet chores refresh failed', error: e);
      if (mounted) setState(() => _refreshFailed = true);
    }
  }

  /// Marking done is a *turn passing*, not a strike-through: the card settles
  /// out of the queue and lands in the "Done recently" ledger with who/when,
  /// while the snackbar says when the chore comes back. The server rotates the
  /// real next turn; a later refresh replaces the optimistic estimate.
  Future<void> _toggleComplete(String id) async {
    if (_isMutating) return;
    _isMutating = true;
    final l10n = AppLocalizations.of(context)!;
    try {
      final chore = _chores.firstWhereOrNull((c) => c.id == id);
      if (chore == null || chore.completed || _settlingIds.contains(id)) {
        return;
      }
      unawaited(Haptics.success());
      chore.completed = true; // guards re-taps while the card settles
      if (MediaQuery.of(context).disableAnimations) {
        _finishSettle(id);
      } else {
        setState(() => _settlingIds.add(id));
        // _finishSettle is invoked by the row's SettleCollapse onCollapsed.
      }

      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.completeOfflineFirst(id, groupId: _groupId);
      if (!mounted) return;
      final isRecurring =
          chore.frequency != 'none' && chore.frequency != 'adaptive';
      final backLabel = isRecurring
          ? l10n.choreDoneBackSnackbar(chore.title,
              _formatDate(_fallbackDueDate(DateTime.now(), chore.frequency)))
          : l10n.choreDoneSnackbar(chore.title);
      AppToast.undo(
        context,
        message: backLabel,
        onUndo: () => _undoComplete(id),
      );
    } catch (e) {
      if (!mounted) return;
      _restoreToQueue(id);
      unawaited(Haptics.failure());
      _showChoreActionError(_l10n.choreFailedComplete);
    } finally {
      _isMutating = false;
    }
  }

  /// Moves a just-completed chore from the queue into the ledger (optimistic
  /// "You · just now" entry). Called when its settle animation finishes.
  void _finishSettle(String id) {
    if (!mounted) return;
    setState(() {
      _settlingIds.remove(id);
      final idx = _chores.indexWhere((c) => c.id == id);
      if (idx == -1) return;
      _justLandedChoreId = id;
      final chore = _chores.removeAt(idx);
      _recentlyDone.insert(
        0,
        _DoneEntry(
          choreId: chore.id,
          title: chore.title,
          completedAt: DateTime.now(),
          byUserId: _myUserId ?? '',
          byLabel: null, // null + byIsMe renders as "You"
          byIsMe: true,
          nextDueDate: null,
          nextTurnName: null,
          nextTurnIsMine: false,
          restoreChore: chore,
        ),
      );
    });
  }

  /// Puts a chore back in the queue (failed complete, or user tapped Undo).
  void _restoreToQueue(String id) {
    if (!mounted) return;
    setState(() {
      _settlingIds.remove(id);
      if (_justLandedChoreId == id) _justLandedChoreId = null;
      final entryIdx = _recentlyDone
          .indexWhere((e) => e.choreId == id && e.restoreChore != null);
      if (entryIdx != -1) {
        final entry = _recentlyDone.removeAt(entryIdx);
        entry.restoreChore!.completed = false;
        _chores.add(entry.restoreChore!);
      } else {
        final chore = _chores.firstWhereOrNull((c) => c.id == id);
        chore?.completed = false;
      }
    });
  }

  Future<void> _undoComplete(String id) async {
    try {
      unawaited(Haptics.light());
      _restoreToQueue(id);
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.undoOfflineFirst(id, groupId: _groupId);
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError(_l10n.choreFailedUndo);
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
      unawaited(Haptics.failure());
      _showChoreActionError(_l10n.choreFailedSkip);
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
        _showChoreActionError(_l10n.choreCreateListFirst);
        return;
      }
      if (!mounted) return;
      final selectedList = await showAppDialog<String>(
        context: context,
        title: _l10n.choreAddSuppliesToList,
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
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).pop(list.id),
              );
            },
          ),
        ),
      );
      if (selectedList == null) return;
      final choreSvc = await ref.read(choreServiceProviderAsync.future);
      await choreSvc.addSuppliesToList(choreId, selectedList);
      if (!mounted) return;
      AppToast.success(context, _l10n.choreSuppliesAdded);
    } catch (e) {
      if (!mounted) return;
      _showChoreActionError(_l10n.choreFailedAddSupplies);
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
      unawaited(Haptics.failure());
      _showChoreActionError(_l10n.choreFailedReschedule);
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
      _showChoreActionError(_l10n.choreFailedUndo);
    } finally {
      _isMutating = false;
    }
  }

  /// Runs once the detail sheet has already confirmed the delete with the
  /// user, so it closes the sheet and deletes without asking again.
  Future<void> _deleteChore(String id) async {
    if (_isMutating) return;
    _isMutating = true;
    Navigator.of(context).pop();
    try {
      final service = await ref.read(choreServiceProviderAsync.future);
      await service.deleteChore(id);
      await _refreshQuietly();
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      _showChoreActionError(
          friendlyErrorMessage(e, AppLocalizations.of(context)!));
    } finally {
      _isMutating = false;
    }
  }

  void _showChoreActionError(String message) {
    AppToast.error(context, message);
  }

  List<_Chore> get _filteredChores {
    if (_filterMe) {
      return _chores.where((c) => c.isMine).toList();
    }
    return _chores.toList();
  }

  void _setFilterMe(bool value, {bool persist = true}) {
    setState(() => _filterMe = value);
    // An automatic widening (see _addChore) is a transient view change, not a
    // preference the user expressed.
    if (!persist) return;
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

  String _sectionTitle(String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'Overdue':
        return l10n.choreSectionOverdue;
      case 'Today':
        return l10n.choreSectionToday;
      case 'This week':
        return l10n.choreSectionThisWeek;
      case 'Later':
        return l10n.choreSectionLater;
      default:
        return key;
    }
  }

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
    final l10n = AppLocalizations.of(context)!;

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
    // The house verdict: overdue across *everyone*, never filtered by
    // Me/Everyone — this is the from-bed "what state is the flat in" read.
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final houseOverdue = _chores.where((c) {
      if (c.completed) return false;
      final due = DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day);
      return due.isBefore(todayDay);
    }).length;
    final hasAny = _chores.isNotEmpty || _recentlyDone.isNotEmpty;

    final showHeader = _hasHousehold && !_isLoading && !_hasError && hasAny;

    // Size the pinned section header against the user's actual text scale so
    // larger accessibility font settings don't clip the label.
    final sectionHeaderHeight = MitlistSpacing.sm * 2 +
        MediaQuery.textScalerOf(context).scale(_labelMediumLineHeight);

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.choreAppBarTitle,
        actions: [
          if (_hasHousehold && _groupId != null)
            PopupMenuButton<_ChoreMenuAction>(
              icon: const AppIcon(name: 'ellipsisVertical'),
              tooltip: l10n.commonOptions,
              onSelected: (action) {
                switch (action) {
                  case _ChoreMenuAction.manageZones:
                    ChoreZonesSheet.show(context, groupId: _groupId!);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ChoreMenuAction.manageZones,
                  child: Row(
                    children: [
                      AppIcon(
                          name: 'squares2x2',
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: MitlistSpacing.sm),
                      Text(l10n.choreManageZones),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: AppButton(
        size: AppButtonSize.lg,
        onPressed:
            _hasHousehold ? _addChore : () => context.goNamed('groupsList'),
        icon: AppIcon(
          name: _hasHousehold ? 'plus' : 'userGroup',
        ),
        text: _hasHousehold ? l10n.choreAddChore : l10n.choreAddHouseholds,
        tooltip: _hasHousehold ? l10n.choreAddChore : l10n.choreAddHouseholds,
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
            ] else if (_hasError) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: Column(
                    children: [
                      AppAlert(
                        type: AppAlertType.error,
                        message: l10n.commonFailedToLoad,
                      ),
                      const SizedBox(height: MitlistSpacing.md),
                      AppButton(
                        text: l10n.commonRetry,
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
                      title: l10n.choreNoHouseholdTitle,
                      description: l10n.choreNoHouseholdDesc,
                      actions: [
                        AppButton(
                          text: l10n.choreGoToHouseholds,
                          onPressed: () => context.goNamed('groupsList'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (!hasAny) ...[
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
                      title: l10n.choreNoChoresTitle,
                      description: l10n.choreNoChoresDesc,
                      actions: [
                        AppButton(
                          text: l10n.choreAddAChore,
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
              if (_refreshFailed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MitlistSpacing.md,
                      MitlistSpacing.md,
                      MitlistSpacing.md,
                      0,
                    ),
                    child: _StaleNotice(
                      message: l10n.choreRefreshFailed,
                      retryLabel: l10n.commonRetry,
                      onRetry: _refreshQuietly,
                    ),
                  ),
                ),
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
                          houseOverdueCount: houseOverdue,
                        ),
                        const SizedBox(height: MitlistSpacing.sm),
                        _FairnessStrip(
                          entries: _load,
                          memberNames: _memberNames,
                          myUserId: _myUserId,
                          onTap: _openLoadSheet,
                        ),
                        const SizedBox(height: MitlistSpacing.sm),
                        // Whose queue you're looking at — a view control, so
                        // it lives with the list rather than inside the
                        // status hero.
                        Row(
                          children: [
                            AppChip(
                              label: l10n.choreMeLabel(myActive),
                              selected: _filterMe,
                              onSelected: (_) => _setFilterMe(true),
                            ),
                            const SizedBox(width: MitlistSpacing.sm),
                            AppChip(
                              label: l10n.choreEveryoneLabel(totalActive),
                              selected: !_filterMe,
                              onSelected: (_) => _setFilterMe(false),
                            ),
                          ],
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
                      title: l10n.choreNothingOnYou,
                      description: l10n.choreNothingOnYouDesc,
                      actions: [
                        AppButton(
                          text: l10n.choreSeeEveryonesChores,
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
                        height: sectionHeaderHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: MitlistSpacing.md,
                            vertical: MitlistSpacing.sm,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _sectionTitle(section),
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
                              child: SettleCollapse(
                                key: ValueKey('chore-${chore.id}'),
                                collapsed: _settlingIds.contains(chore.id),
                                onCollapsed: () => _finishSettle(chore.id),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: MitlistSpacing.sm,
                                  ),
                                  child: _ChoreItem(
                                    chore: chore,
                                    onToggle: () => _toggleComplete(chore.id),
                                    onTap: () => _openChoreDetail(chore.id),
                                    onLongPress: () {
                                      unawaited(Haptics.medium());
                                      _editChore(chore.id);
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: sections[section]!.length,
                        ),
                      ),
                    ),
                  ],
              // The accountability ledger: who did what in the last 48h, and
              // when each chore comes back around. Deliberately unfiltered by
              // Me/Everyone — checking on the household is its whole point.
              if (_recentlyDone.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: MitlistSpacing.sm),
                    child: _DoneRecentlyHeader(
                      count: _recentlyDone.length,
                      expanded: _doneSectionExpanded,
                      onToggle: () => setState(
                          () => _doneSectionExpanded = !_doneSectionExpanded),
                    ),
                  ),
                ),
                if (_doneSectionExpanded)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      MitlistSpacing.md,
                      MitlistSpacing.sm,
                      MitlistSpacing.md,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = _recentlyDone[index];
                          final row = _DoneEntryRow(
                            entry: entry,
                            onTap: () => _openChoreDetail(entry.choreId),
                          );
                          // The just-completed chore lands visibly — the other
                          // half of the queue card's settle-out.
                          if (entry.choreId == _justLandedChoreId) {
                            return _LedgerLanding(
                              key: ValueKey('landed-${entry.choreId}'),
                              child: row,
                            );
                          }
                          return row;
                        },
                        childCount: _recentlyDone.length,
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
    // The child provides its own opaque background and divider, so no wrapping
    // surface is needed here.
    return child;
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

  /// False for `no-assignment` chores — rendered as "Up for grabs" rather
  /// than a "?" avatar.
  final bool hasAssignee;
  final DateTime dueDate;
  final String frequency;
  final int periodInterval;
  final String? category;
  final bool isMine;
  bool completed;
  final String? lastActionLabel;
  final List<String> supplies;

  /// Display name of who the turn passes to next, when the rotation is
  /// deterministic — the wheel's "whose turn is coming" read, as a label.
  final String? nextTurnName;

  _Chore({
    required this.id,
    this.assignmentId,
    required this.title,
    required this.assigneeInitials,
    this.assigneeName,
    this.hasAssignee = true,
    required this.dueDate,
    this.frequency = 'none',
    this.periodInterval = 1,
    this.category,
    this.isMine = true,
    this.completed = false,
    this.lastActionLabel,
    this.supplies = const [],
    this.nextTurnName,
  });

  /// Short label for whose turn it is: "Your turn", "Sam's turn", or null when
  /// unassigned.
  String? turnLabel(AppLocalizations l10n) {
    if (!hasAssignee) return null;
    if (isMine) return l10n.choreYourTurn;
    final name = assigneeName;
    if (name != null && name.isNotEmpty) return l10n.choreSomeonesTurn(name);
    return null;
  }
}

/// One row of the "Done recently" ledger: which occurrence got done, by whom,
/// when, and (once the server has rotated) whose turn comes next.
class _DoneEntry {
  final String choreId;
  final String title;
  final DateTime completedAt;
  final String byUserId;

  /// Display name of who did it; null with [byIsMe] true renders as "You".
  final String? byLabel;
  final bool byIsMe;
  final DateTime? nextDueDate;
  final String? nextTurnName;
  final bool nextTurnIsMine;

  /// Kept only on optimistic entries so Undo can put the exact queue row back.
  final _Chore? restoreChore;

  const _DoneEntry({
    required this.choreId,
    required this.title,
    required this.completedAt,
    required this.byUserId,
    required this.byLabel,
    required this.byIsMe,
    required this.nextDueDate,
    required this.nextTurnName,
    required this.nextTurnIsMine,
    this.restoreChore,
  });
}

/// The people-first hero: leads with what's on *you* right now, and how much
/// of the household's open load you're carrying. Pure status — the
/// Me/Everyone view toggle lives with the list it filters.
class _TurnHero extends StatelessWidget {
  final List<_Chore> myTurn;
  final int myActiveCount;
  final int totalActiveCount;

  /// Overdue across the whole household, unfiltered — the one-line house
  /// verdict checked from bed.
  final int houseOverdueCount;

  const _TurnHero({
    required this.myTurn,
    required this.myActiveCount,
    required this.totalActiveCount,
    required this.houseOverdueCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final caughtUp = myTurn.isEmpty;

    final dueNowCount = myTurn.length;
    final shareLabel = totalActiveCount == 0
        ? l10n.choreNothingShare
        : l10n.choreCarryingShare(myActiveCount, totalActiveCount);
    final houseVerdict = houseOverdueCount > 0
        ? l10n.choreHouseOverdue(houseOverdueCount)
        : l10n.choreHouseAllClear;

    return Semantics(
      label:
          '${caughtUp ? l10n.choreAllCaughtUp : '${dueNowCount == 1 ? l10n.choreHeroDescSingular(dueNowCount) : l10n.choreHeroDescPlural(dueNowCount)} $shareLabel'}, $houseVerdict',
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
                        caughtUp ? l10n.choreYoureClear : l10n.choreYourTurn,
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
                            : '${dueNowCount == 1 ? l10n.choreHeroDescSingular(dueNowCount) : l10n.choreHeroDescPlural(dueNowCount)} $shareLabel.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MitlistSpacing.xs),
                      // The house verdict, quiet but always present: distinct
                      // from *my* verdict above — the whole flat's state.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            color: houseOverdueCount > 0
                                ? colorScheme.error
                                : colorScheme.tertiary,
                          ),
                          const SizedBox(width: MitlistSpacing.space1),
                          Flexible(
                            child: Text(
                              houseVerdict,
                              style: MitlistTypography.labelXSmall(
                                color: houseOverdueCount > 0
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline fairness read: who's carried the household load over the last 30
/// days, as a proportional strip — one segment per member, yours in the brand
/// color — so an uneven split reads as shape before any text. Deliberately
/// thin and unlabeled: visible enough that a freeloader shows, quiet enough
/// that it isn't an accusation. Tap for the per-member breakdown.
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
    final name = memberNames[userId];
    if (name != null && name.isNotEmpty) return name;
    return userId.length <= 8 ? userId : userId.substring(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final total = entries.fold<int>(0, (sum, e) => sum + e.completedCount);

    // Same ordering as the breakdown sheet, so the strip and the sheet agree.
    final shares = entries.where((e) => e.completedCount > 0).toList()
      ..sort((a, b) {
        final byCount = b.completedCount.compareTo(a.completedCount);
        return byCount != 0
            ? byCount
            : _nameFor(a.userId).compareTo(_nameFor(b.userId));
      });

    // Inline (not a card): one less border under the hero card. Stays tappable
    // for the per-member breakdown.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  name: 'chartBar',
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: MitlistSpacing.space2),
                Expanded(
                  child: Text(
                    total == 0
                        ? l10n.choreHowItSplits
                        : '${l10n.choreHowItSplits} · ${l10n.choreDoneLast30Days(total)}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppIcon(
                  name: 'chevronRight',
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (shares.isNotEmpty) ...[
              const SizedBox(height: MitlistSpacing.space1),
              ExcludeSemantics(
                // The text row above already carries the summary; per-segment
                // detail lives in the tap-through sheet.
                child: Row(
                  children: [
                    for (var i = 0; i < shares.length; i++) ...[
                      if (i > 0) const SizedBox(width: MitlistSpacing.space0_5),
                      Expanded(
                        flex: shares[i].completedCount,
                        child: Container(
                          height: 6,
                          color: shares[i].userId == myUserId
                              ? colorScheme.primary
                              : colorScheme.secondary
                                  .withValues(alpha: i.isEven ? 0.6 : 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quiet, dismissible-by-success notice shown when a background refresh fails
/// but cached chores are still on screen, so the user knows the list may be
/// stale and can retry without a full reload.
class _StaleNotice extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _StaleNotice({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        border: Border.all(color: colorScheme.outline, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.sm,
        MitlistSpacing.sm,
        MitlistSpacing.sm,
      ),
      child: Row(
        children: [
          AppIcon(
            name: 'arrowPath',
            size: 16,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          AppButton(
            text: retryLabel,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.ghost,
            onPressed: onRetry,
          ),
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

/// Collapsible header for the "Done recently" ledger — same grammar as the
/// lists' "Checked off" section, with a live count odometer.
class _DoneRecentlyHeader extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  const _DoneRecentlyHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              Text(l10n.choreDoneRecently, style: headerStyle),
              const SizedBox(width: MitlistSpacing.sm),
              MitlistOdometer(value: count, textStyle: headerStyle),
              const Spacer(),
              AppIcon(
                name: expanded ? 'chevronUp' : 'chevronDown',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One ledger row: `chore — who · when`, with the next turn on the right
/// once the server has rotated it. This is how a household checks that the
/// other person actually did their thing.
class _DoneEntryRow extends StatelessWidget {
  final _DoneEntry entry;
  final VoidCallback onTap;

  const _DoneEntryRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final who = entry.byIsMe
        ? l10n.choreLedgerYou
        : (entry.byLabel ?? l10n.choreLedgerSomeone);
    final when = _formatRelativeTime(l10n, entry.completedAt);

    final String? nextTurn;
    if (entry.nextTurnIsMine) {
      nextTurn = l10n.choreYourTurn;
    } else if (entry.nextTurnName != null && entry.nextTurnName!.isNotEmpty) {
      nextTurn = l10n.choreSomeonesTurn(entry.nextTurnName!);
    } else {
      nextTurn = null;
    }

    return Semantics(
      button: true,
      label: [
        entry.title,
        l10n.choreLedgerDoneBy(who, when),
        if (entry.nextDueDate != null)
          l10n.choreBackOnDate(_formatDate(entry.nextDueDate!)),
        if (nextTurn != null) nextTurn,
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
          child: Row(
            children: [
              AppIcon(
                name: 'checkCircle',
                size: 18,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: MitlistSpacing.space0_5),
                    Text(
                      l10n.choreLedgerDoneBy(who, when),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MitlistTypography.labelXSmall(
                        color: colorScheme.onSurfaceVariant,
                      ).copyWith(
                        fontWeight:
                            entry.byIsMe ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.nextDueDate != null) ...[
                const SizedBox(width: MitlistSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.choreBackOnDate(_formatDate(entry.nextDueDate!)),
                      style: MitlistTypography.labelXSmall(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (nextTurn != null) ...[
                      const SizedBox(height: MitlistSpacing.space0_5),
                      Text(
                        nextTurn,
                        style: MitlistTypography.labelXSmall(
                          color: entry.nextTurnIsMine
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ).copyWith(
                          fontWeight: entry.nextTurnIsMine
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrance for a chore that just settled into the "Done recently" ledger:
/// the row grows in and a brief highlight fades out, so completion reads as a
/// visible state change — the card moves *somewhere* — rather than a vanish.
class _LedgerLanding extends StatelessWidget {
  const _LedgerLanding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final highlight = Theme.of(context).colorScheme.tertiaryContainer;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: MitlistAnimations.slow,
      curve: MitlistAnimations.easeEnter,
      child: child,
      builder: (context, t, child) {
        // Grow over the first half; let the highlight linger, fading over the
        // whole run so the eye can find where the chore landed.
        final grow = (t * 2).clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: grow,
            child: ColoredBox(
              color: highlight.withValues(alpha: (1.0 - t) * 0.7),
              child: Opacity(opacity: grow, child: child),
            ),
          ),
        );
      },
    );
  }
}

class _ChoreItem extends StatelessWidget {
  final _Chore chore;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ChoreItem({
    required this.chore,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isComplete = chore.completed;
    final turnLabel = chore.turnLabel(l10n);

    // A linear screen-reader pass doesn't get the visual cues (section header,
    // turn pill, supplies icon, due-date column), so fold them into the row's
    // accessible name. Order: what it is, its state, whose turn, when it's due.
    final suppliesLabel = chore.supplies.isEmpty
        ? null
        : (chore.supplies.length == 1
            ? l10n.choreSupplySingular(chore.supplies.length)
            : l10n.choreSupplyPlural(chore.supplies.length));
    final semanticLabel = <String>[
      chore.title,
      if (isComplete) l10n.choreStatusDone,
      if (turnLabel != null && !isComplete) turnLabel,
      if (chore.nextTurnName != null && !isComplete)
        l10n.choreNextInRotation(chore.nextTurnName!),
      if (!chore.hasAssignee && !isComplete) l10n.choreUpForGrabs,
      _frequencyLabel(l10n, chore.frequency, chore.periodInterval),
      if (suppliesLabel != null) suppliesLabel,
      _formatDate(chore.dueDate),
    ].join(', ');

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.sm,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Semantics(
          button: true,
          label: semanticLabel,
          onLongPressHint: onLongPress != null ? l10n.choreEditTitle : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedCheckToggle(
                value: isComplete,
                onChanged: (_) => onToggle(),
                semanticLabelOn: l10n.choreMarkNotDone(chore.title),
                semanticLabelOff: l10n.choreMarkDone(chore.title),
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
                                l10n, chore.frequency, chore.periodInterval),
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
                          // The rotation made visible: who the turn passes to
                          // once this one is done.
                          if (chore.nextTurnName != null && !isComplete)
                            _MetaChip(
                              icon: 'arrowRight',
                              label: chore.nextTurnName!,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          if (chore.supplies.isNotEmpty)
                            _MetaChip(
                              icon: 'inventoryOutline',
                              label: chore.supplies.length == 1
                                  ? l10n.choreSupplySingular(
                                      chore.supplies.length)
                                  : l10n
                                      .choreSupplyPlural(chore.supplies.length),
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (chore.hasAssignee)
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
                    )
                  else
                    // No rotation on this chore: frame it as an open turn
                    // anyone can claim, not a "?" shrug.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.sm,
                        vertical: MitlistSpacing.space0_5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        l10n.choreUpForGrabs,
                        style: MitlistTypography.labelXSmall(
                          color: colorScheme.onSurfaceVariant,
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

/// Compact "when did this happen" for ledger rows: just now → 5h ago →
/// yesterday → Jul 4.
String _formatRelativeTime(AppLocalizations l10n, DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 60) return l10n.choreLedgerJustNow;
  if (diff.inHours < 24) return l10n.choreLedgerHoursAgo(diff.inHours);
  if (diff.inHours < 48) return l10n.choreLedgerYesterday;
  return _formatDate(at);
}

String _frequencyLabel(AppLocalizations l10n, String frequency, int interval) {
  if (interval > 1) {
    final unit = switch (frequency) {
      'hourly' => l10n.choreCreationUnitHourPlural,
      'daily' => l10n.choreCreationUnitDayPlural,
      'weekly' => l10n.choreCreationUnitWeekPlural,
      'monthly' => l10n.choreCreationUnitMonthPlural,
      'yearly' => l10n.choreCreationUnitYearPlural,
      _ => '',
    };
    if (unit.isNotEmpty) return l10n.choreEveryInterval(interval, unit);
  }
  return switch (frequency) {
    'hourly' => l10n.choreFrequencyHourly,
    'daily' => l10n.choreFrequencyDaily,
    'weekly' => l10n.choreFrequencyWeekly,
    'monthly' => l10n.choreFrequencyMonthly,
    'yearly' => l10n.choreFrequencyYearly,
    'adaptive' => l10n.choreFrequencyAsNeeded,
    _ => l10n.choreFrequencyOneOff,
  };
}

String _formatLastAction(AppLocalizations l10n, ChoreAssignment assignment) {
  if (assignment.completedAt != null) {
    final diff = DateTime.now().difference(assignment.completedAt!);
    if (diff.inDays == 0) return l10n.choreDoneToday;
    if (diff.inDays == 1) return l10n.choreDoneYesterday;
    return l10n.choreDoneDaysAgo(diff.inDays);
  }
  if (assignment.skipReason != null && assignment.skipReason!.isNotEmpty) {
    return l10n.choreSkipped;
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
