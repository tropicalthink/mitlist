import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chore_models.dart';
import '../models/group_models.dart';
import '../providers/chore_provider.dart';
import '../providers/group_provider.dart';
import '../router.dart' show currentGroupIdProvider;
import '../services/scan/grocery_suggestion_service.dart';
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../utils/haptics.dart';
import '../widgets/animated_check_toggle.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_input.dart';
import '../utils/friendly_error.dart';
import '../widgets/chip.dart';
import '../widgets/grocery_suggestion_field.dart';
import '../widgets/app_icon.dart';
import '../l10n/app_localizations.dart';

import '../widgets/app_toast.dart';

enum _Recurrence { none, hourly, daily, weekly, monthly, yearly, adaptive }

/// How the turn rotates when more than one person shares the chore. "No one"
/// and "always this person" are choices on the who-picker itself, not
/// policies.
enum _AssignmentPolicy {
  roundRobin,
  leastDone,
  random,
  alphabetical,
}

class ChoreCreationSheet extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialDescription;

  /// When set, the sheet edits this chore in place instead of creating a new
  /// one: every field is prefilled and saving PATCHes the existing chore.
  final Chore? existingChore;
  final ValueNotifier<bool>? dirtyNotifier;

  const ChoreCreationSheet({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.existingChore,
    this.dirtyNotifier,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialTitle,
    String? initialDescription,
    Chore? existingChore,
  }) async {
    final dirty = ValueNotifier<bool>(false);
    final l10n = AppLocalizations.of(context)!;
    final future = showAppBottomSheet<bool>(
      context: context,
      title:
          existingChore == null ? l10n.choreCreationTitle : l10n.choreEditTitle,
      isDirtyListenable: dirty,
      body: ChoreCreationSheet(
        initialTitle: initialTitle,
        initialDescription: initialDescription,
        existingChore: existingChore,
        dirtyNotifier: dirty,
      ),
    );
    unawaited(future.whenComplete(dirty.dispose));
    return future;
  }

  @override
  ConsumerState<ChoreCreationSheet> createState() => _ChoreCreationSheetState();
}

class _ChoreCreationSheetState extends ConsumerState<ChoreCreationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _intervalController =
      TextEditingController(text: '1');
  final TextEditingController _supplyController = TextEditingController();
  final FocusNode _supplyFocusNode = FocusNode();
  _Recurrence _recurrence = _Recurrence.none;
  _AssignmentPolicy _assignmentPolicy = _AssignmentPolicy.roundRobin;
  final Set<String> _weekdays = {'monday'};
  bool _trackDateOnly = false;
  bool _rollover = false;
  bool _isSaving = false;
  bool _showAdvanced = false;
  // Scheduling folds behind a one-line summary for the common one-off chore;
  // forced open once a recurrence is chosen so it's never hidden.
  bool _showRecurrence = false;
  bool _showZone = false;
  String? _category;
  String? _groupId;
  final List<String> _supplies = [];

  /// Household members for the who-picker. Loaded best-effort; the picker
  /// simply stays at "Everyone" if the lookup fails.
  List<({String id, String name})> _members = const [];

  /// Selected member ids. Empty = the whole household rotates.
  final Set<String> _who = {};

  /// True when the chore is explicitly unassigned ("No one").
  bool _noOne = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _nameController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    final existing = widget.existingChore;
    if (existing != null) _prefillFrom(existing);
    _intervalController.addListener(_markDirty);
    unawaited(_loadMembers());
  }

  /// Mirrors [_onCreate]'s state→request mapping in the other direction so an
  /// edited chore opens exactly as it was saved.
  void _prefillFrom(Chore chore) {
    _nameController.text = chore.name;
    _descriptionController.text = chore.description ?? '';
    _recurrence = switch (chore.frequency) {
      'hourly' => _Recurrence.hourly,
      'daily' => _Recurrence.daily,
      'weekly' => _Recurrence.weekly,
      'monthly' => _Recurrence.monthly,
      'yearly' => _Recurrence.yearly,
      'adaptive' => _Recurrence.adaptive,
      _ => _Recurrence.none,
    };
    _intervalController.text = chore.periodInterval.toString();
    if (chore.periodConfig.isNotEmpty) {
      _weekdays
        ..clear()
        ..addAll(chore.periodConfig);
    }
    _trackDateOnly = chore.trackDateOnly;
    _rollover = chore.rollover;
    _category = chore.category;
    _supplies.addAll(chore.supplies);
    _noOne = chore.assignmentType == 'no-assignment';
    if (!_noOne) _who.addAll(chore.assignmentConfig);
    _assignmentPolicy = switch (chore.assignmentType) {
      'in-alphabetical-order' => _AssignmentPolicy.alphabetical,
      'who-least-did-first' => _AssignmentPolicy.leastDone,
      'random' => _AssignmentPolicy.random,
      _ => _AssignmentPolicy.roundRobin,
    };
  }

  Future<void> _loadMembers() async {
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId =
          resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
      if (groupId == null) return;
      if (mounted) setState(() => _groupId = groupId);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final members = await groupService.listMembers(groupId);
      if (!mounted) return;
      setState(() {
        _members = [
          for (final m in members) (id: m.userId, name: m.displayName),
        ];
      });
    } catch (_) {
      // Who-picker falls back to "Everyone"; assignment still works.
    }
  }

  void _markDirty() => widget.dirtyNotifier?.value = true;

  List<String> _activeGroupZones() {
    final groups = ref.watch(cachedGroupsProvider).valueOrNull;
    if (groups == null || groups.isEmpty) return const [];
    final groupId =
        resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    if (groupId == null) return const [];
    for (final group in groups) {
      if (group.id == groupId) return group.choreZones;
    }
    return const [];
  }

  /// Same lookup outside build, where `ref.watch` isn't allowed.
  List<String> _readGroupZones() {
    final groups = ref.read(cachedGroupsProvider).valueOrNull;
    if (groups == null || groups.isEmpty) return const [];
    final groupId =
        resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    if (groupId == null) return const [];
    for (final group in groups) {
      if (group.id == groupId) return group.choreZones;
    }
    return const [];
  }

  /// Zones are the household's, not the chore's, so editing them writes
  /// straight through to the group. They're editable from here because the
  /// moment you need a new zone is the moment you're filing a chore under one
  /// — sending people to household settings mid-create loses the chore.
  Future<bool> _persistZones(List<String> zones) async {
    final l10n = AppLocalizations.of(context)!;
    final groups = ref.read(cachedGroupsProvider).valueOrNull ?? const [];
    final groupId =
        resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    if (groupId == null) return false;
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      await svc.updateGroup(groupId, UpdateGroupRequest(choreZones: zones));
      await refreshCachedGroups(ref);
      return true;
    } catch (e) {
      if (!mounted) return false;
      AppToast.error(context, friendlyErrorMessage(e, l10n));
      return false;
    }
  }

  Future<void> _addZone() async {
    final l10n = AppLocalizations.of(context)!;
    final existing = _readGroupZones();
    final controller = TextEditingController();
    final entered = await showAppDialog<String>(
      context: context,
      title: l10n.sheetGroupSettingsAddZone,
      body: AppInput(
        hint: l10n.sheetGroupSettingsZoneHint,
        controller: controller,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          text: l10n.commonAdd,
          onPressed: () => Navigator.of(context).pop(controller.text),
        ),
      ],
    );
    controller.dispose();
    if (!mounted) return;

    final name = entered?.trim() ?? '';
    if (name.isEmpty) return;

    // Already there under some casing: just select it rather than duplicating.
    final match =
        existing.firstWhereOrNull((z) => z.toLowerCase() == name.toLowerCase());
    if (match != null) {
      setState(() => _category = match);
      _markDirty();
      return;
    }

    if (!await _persistZones([...existing, name])) return;
    if (!mounted) return;
    unawaited(Haptics.light());
    setState(() => _category = name);
    _markDirty();
  }

  Future<void> _removeZone(String zone) async {
    final l10n = AppLocalizations.of(context)!;
    unawaited(Haptics.medium());
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.choreCreationRemoveZoneTitle,
      body: Text(l10n.choreCreationRemoveZoneBody(zone)),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          text: l10n.commonRemove,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    final remaining = _readGroupZones().where((z) => z != zone).toList();
    if (!await _persistZones(remaining)) return;
    if (!mounted) return;
    if (_category == zone) setState(() => _category = null);
  }

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isSaving = true);

    final existing = widget.existingChore;
    if (existing != null) {
      await _onSaveEdit(existing);
      return;
    }

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final choreService = await ref.read(choreServiceProviderAsync.future);
      final groups = await ref.read(cachedGroupsProvider.future);
      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() => _isSaving = false);
        AppToast.info(context, _l10n.choreCreationJoinFirst);
        return;
      }

      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) {
        setState(() => _isSaving = false);
        return;
      }

      // Offline-first: the chore is queued and visible immediately. We wait a
      // moment for it to reach the server, purely so an online create can still
      // name the assignee below; expiring just means the outbox finishes it.
      final choreRepo = await ref.read(choreRepositoryProvider.future);
      final result = await choreRepo.createOfflineFirst(
        CreateChoreRequest(
          groupId: groupId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          frequency: _frequencyValue(),
          periodInterval: _periodInterval,
          periodConfig:
              _recurrence == _Recurrence.weekly ? _weekdays.toList() : const [],
          trackDateOnly: _trackDateOnly,
          rollover: _rollover,
          assignmentType: _assignmentTypeValue(),
          // Empty = whole household; one id = a fixed owner; several = the
          // rotation pool. The backend's rotation state honors this subset.
          assignmentConfig: _noOne ? const [] : _who.toList(),
          supplies: List.unmodifiable(_supplies),
          category: _category,
        ),
        syncWindow: const Duration(milliseconds: 1500),
      );

      // Best-effort: surface who the chore landed on so a new chore reads as
      // part of the household rotation, not an isolated entry. Never blocks the
      // success path if the lookup fails. Skipped entirely when the create is
      // still queued — the server assigns the rotation, so until it has the
      // chore there is no assignee to name, and asking would just stall on a
      // connection we already know is not answering.
      String? assignee;
      if (result.synced) {
        try {
          final details = await choreService.getChoreDetails(result.chore.id);
          if (details.assignedToMe) {
            assignee = 'you';
          } else {
            final assigneeId = details.pendingAssignment?.userId;
            if (assigneeId != null) {
              final members = await groupService.listMembers(groupId);
              for (final m in members) {
                if (m.userId == assigneeId) {
                  assignee = m.displayName;
                  break;
                }
              }
            }
          }
        } catch (_) {
          // Confirmation is a nicety; fall back to the plain message.
        }
      }

      if (!mounted) return;
      widget.dirtyNotifier?.value = false;
      Navigator.of(context).pop(true);
      AppToast.success(
          context,
          assignee == null
              ? _l10n.choreCreationChoreAdded
              : _l10n.choreCreationChoreAddedNextUp(assignee));
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.error(
          context, friendlyErrorMessage(e, AppLocalizations.of(context)!));
    }
  }

  /// The backend's PATCH replaces name/schedule/assignment wholesale rather
  /// than merging, so the full chore is sent back — including fields this
  /// sheet doesn't edit (rotation type, start date), which are echoed
  /// unchanged so they survive the round trip.
  Future<void> _onSaveEdit(Chore existing) async {
    try {
      final choreService = await ref.read(choreServiceProviderAsync.future);
      await choreService.updateChore(
        existing.id,
        UpdateChoreRequest(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          rotationType: existing.rotationType,
          frequency: _frequencyValue(),
          periodInterval: _periodInterval,
          periodConfig:
              _recurrence == _Recurrence.weekly ? _weekdays.toList() : const [],
          startDate: existing.startDate,
          trackDateOnly: _trackDateOnly,
          rollover: _rollover,
          assignmentType: _assignmentTypeValue(),
          assignmentConfig: _noOne ? const [] : _who.toList(),
          supplies: List.unmodifiable(_supplies),
          category: _category,
        ),
      );

      // The direct PATCH bypasses the offline cache, so pull the queue fresh
      // before callers repaint from it. Best-effort: the server already has
      // the edit, and the caller refreshes again on the `true` result.
      try {
        final choreRepo = await ref.read(choreRepositoryProvider.future);
        await choreRepo.refreshCurrentChores(existing.groupId);
      } catch (_) {}

      if (!mounted) return;
      widget.dirtyNotifier?.value = false;
      Navigator.of(context).pop(true);
      AppToast.success(context, _l10n.choreEditSaved);
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.error(
          context, friendlyErrorMessage(e, AppLocalizations.of(context)!));
    }
  }

  String _frequencyValue() {
    switch (_recurrence) {
      case _Recurrence.none:
        return 'none';
      case _Recurrence.hourly:
        return 'hourly';
      case _Recurrence.daily:
        return 'daily';
      case _Recurrence.weekly:
        return 'weekly';
      case _Recurrence.monthly:
        return 'monthly';
      case _Recurrence.yearly:
        return 'yearly';
      case _Recurrence.adaptive:
        return 'adaptive';
    }
  }

  int get _periodInterval {
    final parsed = int.tryParse(_intervalController.text.trim()) ?? 1;
    if (parsed < 1) return 1;
    if (parsed > 999) return 999;
    return parsed;
  }

  String _assignmentTypeValue() {
    if (_noOne) return 'no-assignment';
    // A single fixed owner is a rotation of one — the backend honors
    // assignment_config as the member pool, so any policy degenerates
    // correctly; round-robin keeps it obvious.
    if (_who.length == 1) return 'round-robin';
    switch (_assignmentPolicy) {
      case _AssignmentPolicy.roundRobin:
        return 'round-robin';
      case _AssignmentPolicy.alphabetical:
        return 'in-alphabetical-order';
      case _AssignmentPolicy.leastDone:
        return 'who-least-did-first';
      case _AssignmentPolicy.random:
        return 'random';
    }
  }

  @override
  void dispose() {
    _intervalController.removeListener(_markDirty);
    _nameController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    _supplyController.dispose();
    _supplyFocusNode.dispose();
    super.dispose();
  }

  void _addSupply([String? submitted]) {
    final supply = (submitted ?? _supplyController.text).trim();
    if (supply.isEmpty) return;
    final alreadyAdded = _supplies.any(
      (existing) => existing.toLowerCase() == supply.toLowerCase(),
    );
    setState(() {
      if (!alreadyAdded) _supplies.add(supply);
      _supplyController.clear();
    });
    if (!alreadyAdded) _markDirty();
    _supplyFocusNode.requestFocus();
  }

  void _removeSupply(String supply) {
    setState(() => _supplies.remove(supply));
    _markDirty();
  }

  // ---- Plain-language descriptions of the current selection ----

  /// Short recurrence label for the collapsed schedule summary line.
  String _recurrenceValueLabel(AppLocalizations l10n) => switch (_recurrence) {
        _Recurrence.none => l10n.choreCreationRecurrenceNone,
        _Recurrence.hourly => l10n.choreCreationRecurrenceHourly,
        _Recurrence.daily => l10n.choreCreationRecurrenceDaily,
        _Recurrence.weekly => l10n.choreCreationRecurrenceWeekly,
        _Recurrence.monthly => l10n.choreCreationRecurrenceMonthly,
        _Recurrence.yearly => l10n.choreCreationRecurrenceYearly,
        _Recurrence.adaptive => l10n.choreCreationRecurrenceAdaptive,
      };

  String get _recurrenceHint => switch (_recurrence) {
        _Recurrence.none => _l10n.choreCreationHintNone,
        _Recurrence.hourly => _l10n.choreCreationHintHourly,
        _Recurrence.daily => _l10n.choreCreationHintDaily,
        _Recurrence.weekly => _l10n.choreCreationHintWeekly,
        _Recurrence.monthly => _l10n.choreCreationHintMonthly,
        _Recurrence.yearly => _l10n.choreCreationHintYearly,
        _Recurrence.adaptive => _l10n.choreCreationHintAdaptive,
      };

  /// Plain-language readback of the who-picker: "Always Sam", "Rotates
  /// between the 2 people you picked", policy hints for the full household,
  /// or the unassigned hint.
  String get _whoHint {
    if (_noOne) return _l10n.choreCreationAssignHintNone;
    if (_who.length == 1) {
      final name = _members
          .where((m) => m.id == _who.first)
          .map((m) => m.name)
          .firstOrNull;
      if (name != null && name.isNotEmpty) {
        return _l10n.choreWhoAlways(name);
      }
    }
    final policyHint = switch (_assignmentPolicy) {
      _AssignmentPolicy.roundRobin => _l10n.choreCreationAssignHintTurns,
      _AssignmentPolicy.alphabetical => _l10n.choreCreationAssignHintAlpha,
      _AssignmentPolicy.leastDone => _l10n.choreCreationAssignHintLeast,
      _AssignmentPolicy.random => _l10n.choreCreationAssignHintRandom,
    };
    if (_who.length > 1) {
      return '${_l10n.choreWhoAmongSelected(_who.length)} $policyHint';
    }
    return policyHint;
  }

  /// Live, singular-aware summary of the repeat interval, e.g. "Every 2 weeks".
  String get _intervalSummary {
    final n = _periodInterval;
    final unit = switch (_recurrence) {
      _Recurrence.hourly => n == 1
          ? _l10n.choreCreationUnitHourSingular
          : _l10n.choreCreationUnitHourPlural,
      _Recurrence.weekly => n == 1
          ? _l10n.choreCreationUnitWeekSingular
          : _l10n.choreCreationUnitWeekPlural,
      _Recurrence.monthly => n == 1
          ? _l10n.choreCreationUnitMonthSingular
          : _l10n.choreCreationUnitMonthPlural,
      _Recurrence.yearly => n == 1
          ? _l10n.choreCreationUnitYearSingular
          : _l10n.choreCreationUnitYearPlural,
      _ => n == 1
          ? _l10n.choreCreationUnitDaySingular
          : _l10n.choreCreationUnitDayPlural,
    };
    return n == 1
        ? _l10n.choreCreationEverySingular(unit)
        : _l10n.choreCreationEveryPlural(n, unit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final groupZones = _activeGroupZones();
    // Scheduling stays folded for the common one-off chore, but forces open the
    // moment a recurrence is chosen so an active schedule is never hidden.
    final recurrenceOpen = _showRecurrence || _recurrence != _Recurrence.none;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Name (the headline: one big field, then decisions) ────────
        AppInput(
          size: AppInputSize.lg,
          hint: l10n.choreCreationNameHint,
          controller: _nameController,
          textInputAction: TextInputAction.next,
          maxLength: 100,
          onChanged: (_) {
            _markDirty();
            setState(() {});
          },
        ),
        const SizedBox(height: MitlistSpacing.md),

        // ── Who does it? (first-class: chores are about people) ──────
        _ChipRow(
          label: l10n.choreCreationAssignLabel,
          children: [
            AppChip(
              label: l10n.choreWhoEveryone,
              selected: !_noOne && _who.isEmpty,
              onSelected: (_) {
                setState(() {
                  _noOne = false;
                  _who.clear();
                });
                _markDirty();
              },
            ),
            for (final member in _members)
              AppChip(
                label: member.name,
                selected: !_noOne && _who.contains(member.id),
                onSelected: (_) {
                  setState(() {
                    _noOne = false;
                    if (!_who.add(member.id)) _who.remove(member.id);
                  });
                  _markDirty();
                },
              ),
            AppChip(
              label: l10n.choreWhoNoOne,
              selected: _noOne,
              onSelected: (_) {
                setState(() {
                  _noOne = !_noOne;
                  if (_noOne) _who.clear();
                });
                _markDirty();
              },
            ),
          ],
        ),
        // The rotation policy only means something when several people share
        // the chore; a single owner or "no one" hides it.
        if (!_noOne && _who.length != 1) ...[
          const SizedBox(height: MitlistSpacing.sm),
          _ChipRow(
            label: l10n.choreWhoOrderLabel,
            children: [
              for (final option in [
                (
                  _AssignmentPolicy.roundRobin,
                  l10n.choreCreationAssignTakeTurns
                ),
                (
                  _AssignmentPolicy.leastDone,
                  l10n.choreCreationAssignLeastDone
                ),
                (_AssignmentPolicy.random, l10n.choreCreationAssignRandom),
                (
                  _AssignmentPolicy.alphabetical,
                  l10n.choreCreationAssignAlphabetical
                ),
              ])
                AppChip(
                  label: option.$2,
                  selected: _assignmentPolicy == option.$1,
                  onSelected: (_) {
                    setState(() => _assignmentPolicy = option.$1);
                    _markDirty();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: MitlistSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(left: MitlistSpacing.space14),
          child: Text(
            _whoHint,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),

        // ── Zone (folded: filing, not a decision) ─────────────────────
        _SummaryLine(
          text: '${l10n.choreCreationZoneLabel} · '
              '${_category ?? l10n.choreCreationZoneNone}',
          semanticLabel: l10n.choreCreationZoneLabel,
          expanded: _showZone,
          onTap: () => setState(() => _showZone = !_showZone),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _showZone
              ? Padding(
                  padding: const EdgeInsets.only(top: MitlistSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The row is here even with no zones yet: the add chip is
                      // how the first one gets made, and a household that never
                      // opens settings would otherwise never meet zones at all.
                      _ChipRow(
                        label: l10n.choreCreationZoneLabel,
                        children: [
                          for (final zone in groupZones)
                            AppChip(
                              label: zone,
                              selected: _category == zone,
                              onSelected: (_) {
                                setState(() => _category =
                                    _category == zone ? null : zone);
                                _markDirty();
                              },
                              onLongPress: () => unawaited(_removeZone(zone)),
                            ),
                          AppChip(
                            label: l10n.sheetGroupSettingsAddZone,
                            leading: const AppIcon(name: 'plus', size: 14),
                            onSelected: (_) => unawaited(_addZone()),
                          ),
                        ],
                      ),
                      if (groupZones.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: MitlistSpacing.space14,
                            top: MitlistSpacing.space1,
                          ),
                          child: Text(
                            l10n.choreCreationZoneManageHint,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: MitlistSpacing.sm),

        // ── Repeats (folded to a calm summary line; tap to change) ────
        _SummaryLine(
          text:
              '${l10n.choreCreationRepeatsLabel} · ${_recurrenceValueLabel(l10n)}',
          semanticLabel: l10n.choreCreationRepeatsLabel,
          expanded: recurrenceOpen,
          onTap: () => setState(() => _showRecurrence = !_showRecurrence),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: recurrenceOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: MitlistSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ChipRow(
                        label: l10n.choreCreationRepeatsLabel,
                        children: [
                          for (final option in [
                            (
                              _Recurrence.none,
                              l10n.choreCreationRecurrenceNone
                            ),
                            (
                              _Recurrence.daily,
                              l10n.choreCreationRecurrenceDaily
                            ),
                            (
                              _Recurrence.weekly,
                              l10n.choreCreationRecurrenceWeekly
                            ),
                            (
                              _Recurrence.monthly,
                              l10n.choreCreationRecurrenceMonthly
                            ),
                            (
                              _Recurrence.yearly,
                              l10n.choreCreationRecurrenceYearly
                            ),
                            (
                              _Recurrence.hourly,
                              l10n.choreCreationRecurrenceHourly
                            ),
                            (
                              _Recurrence.adaptive,
                              l10n.choreCreationRecurrenceAdaptive
                            ),
                          ])
                            AppChip(
                              label: option.$2,
                              selected: _recurrence == option.$1,
                              onSelected: (_) {
                                setState(() => _recurrence = option.$1);
                                _markDirty();
                              },
                            ),
                        ],
                      ),
                      if (_recurrence != _Recurrence.none) ...[
                        const SizedBox(height: MitlistSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: MitlistSpacing.space14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _recurrenceHint,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: MitlistSpacing.sm),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 72,
                                    child: AppInput(
                                      hint: l10n.choreCreationIntervalHint,
                                      controller: _intervalController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: MitlistSpacing.sm),
                                  Text(
                                    _intervalSummary,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              if (_recurrence == _Recurrence.weekly) ...[
                                const SizedBox(height: MitlistSpacing.sm),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final day in [
                                        ('monday', l10n.choreDayMon),
                                        ('tuesday', l10n.choreDayTue),
                                        ('wednesday', l10n.choreDayWed),
                                        ('thursday', l10n.choreDayThu),
                                        ('friday', l10n.choreDayFri),
                                        ('saturday', l10n.choreDaySat),
                                        ('sunday', l10n.choreDaySun),
                                      ])
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: MitlistSpacing.xs),
                                          child: AppChip(
                                            label: day.$2,
                                            selected:
                                                _weekdays.contains(day.$1),
                                            onSelected: (_) {
                                              setState(() {
                                                if (_weekdays
                                                        .contains(day.$1) &&
                                                    _weekdays.length > 1) {
                                                  _weekdays.remove(day.$1);
                                                } else {
                                                  _weekdays.add(day.$1);
                                                }
                                              });
                                              _markDirty();
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: MitlistSpacing.md),

        // ── More options (collapsible) ────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.choreCreationMoreOptions,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_supplies.isNotEmpty)
                  Text(
                    ' · ${_supplies.length == 1 ? l10n.choreSupplySingular(1) : l10n.choreSupplyPlural(_supplies.length)}',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: MitlistSpacing.xs),
                AnimatedRotation(
                  turns: _showAdvanced ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _showAdvanced
              ? Padding(
                  padding: const EdgeInsets.only(top: MitlistSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OptionToggle(
                        value: _trackDateOnly,
                        onChanged: (value) {
                          setState(() => _trackDateOnly = value);
                          _markDirty();
                        },
                        title: l10n.choreCreationLogWhenDone,
                        helper: l10n.choreCreationLogWhenDoneHelper,
                      ),
                      const SizedBox(height: MitlistSpacing.md),
                      _OptionToggle(
                        value: _rollover,
                        onChanged: (value) {
                          setState(() => _rollover = value);
                          _markDirty();
                        },
                        title: l10n.choreCreationRollOver,
                        helper: l10n.choreCreationRollOverHelper,
                      ),
                      if (_groupId != null) ...[
                        const SizedBox(height: MitlistSpacing.md),
                        Text(
                          l10n.choreDetailSupplies,
                          style: textTheme.labelMedium,
                        ),
                        const SizedBox(height: MitlistSpacing.sm),
                        if (_supplies.isNotEmpty) ...[
                          Wrap(
                            spacing: MitlistSpacing.xs,
                            runSpacing: MitlistSpacing.xs,
                            children: [
                              for (final supply in _supplies)
                                Semantics(
                                  button: true,
                                  label: '${l10n.commonRemove} $supply',
                                  child: AppChip(
                                    label: supply,
                                    selected: true,
                                    leading: const AppIcon(name: 'xMark'),
                                    onSelected: (_) => _removeSupply(supply),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: MitlistSpacing.sm),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GrocerySuggestionField(
                                controller: _supplyController,
                                focusNode: _supplyFocusNode,
                                groupId: _groupId!,
                                suggestionContext:
                                    GrocerySuggestionContext.choreSupply,
                                label: l10n.choreDetailSupplies,
                                onSubmitted: _addSupply,
                                submitOnSelect: true,
                              ),
                            ),
                            const SizedBox(width: MitlistSpacing.sm),
                            AppButton(
                              text: l10n.commonAdd,
                              size: AppButtonSize.sm,
                              variant: AppButtonVariant.outline,
                              onPressed: () => _addSupply(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: MitlistSpacing.md),

        // ── Notes ─────────────────────────────────────────────────────
        AppInput(
          hint: l10n.choreCreationNotesHint,
          controller: _descriptionController,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 5,
          maxLength: 500,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: MitlistSpacing.md),

        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: widget.existingChore != null
                ? (_isSaving ? l10n.commonSaving : l10n.commonSave)
                : (_isSaving ? l10n.commonAdding : l10n.choreAddChore),
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}

/// A tappable one-line summary that folds an editor away for the common case,
/// mirroring the expense sheet's payer/split summary. Reads as a phrase with an
/// expand chevron; hard-edged bordered box so it reads as an editable control.
class _SummaryLine extends StatelessWidget {
  final String text;
  final String semanticLabel;
  final bool expanded;
  final VoidCallback onTap;

  const _SummaryLine({
    required this.text,
    required this.semanticLabel,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Icon(
                  Icons.expand_more,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled single-row chip picker. The label is fixed-width so multiple
/// `_ChipRow`s stack with their chips left-aligned.
class _ChipRow extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _ChipRow({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width:
              MitlistSpacing.space14, // 56px — keeps chips aligned across rows
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(right: MitlistSpacing.xs),
                    child: child,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String helper;

  const _OptionToggle({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCheckToggle(
          value: value,
          onChanged: onChanged,
          semanticLabelOn: '$title (on)',
          semanticLabelOff: '$title (off)',
        ),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: MitlistSpacing.xs),
                  child: Text(title, style: textTheme.bodyMedium),
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  helper,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
