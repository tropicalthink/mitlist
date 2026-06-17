import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chore_models.dart';
import '../providers/chore_provider.dart';
import '../providers/group_provider.dart';
import '../router.dart' show currentGroupIdProvider;
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../utils/haptics.dart';
import '../widgets/animated_check_toggle.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../utils/friendly_error.dart';
import '../widgets/chip.dart';
import '../l10n/app_localizations.dart';

enum _Recurrence { none, hourly, daily, weekly, monthly, yearly, adaptive }

enum _AssignmentPolicy {
  roundRobin,
  alphabetical,
  leastDone,
  random,
  noAssignment,
}

class ChoreCreationSheet extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialDescription;
  final ValueNotifier<bool>? dirtyNotifier;

  const ChoreCreationSheet({
    super.key,
    this.initialTitle,
    this.initialDescription,
    this.dirtyNotifier,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialTitle,
    String? initialDescription,
  }) async {
    final dirty = ValueNotifier<bool>(false);
    final l10n = AppLocalizations.of(context)!;
    final future = showAppBottomSheet<bool>(
      context: context,
      title: l10n.choreCreationTitle,
      isDirtyListenable: dirty,
      body: ChoreCreationSheet(
        initialTitle: initialTitle,
        initialDescription: initialDescription,
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
  _Recurrence _recurrence = _Recurrence.none;
  _AssignmentPolicy _assignmentPolicy = _AssignmentPolicy.roundRobin;
  final Set<String> _weekdays = {'monday'};
  bool _trackDateOnly = false;
  bool _rollover = false;
  bool _isSaving = false;
  bool _showAdvanced = false;
  String? _category;

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
    _intervalController.addListener(_markDirty);
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

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isSaving = true);

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final choreService = await ref.read(choreServiceProviderAsync.future);
      final groups = await ref.read(cachedGroupsProvider.future);
      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.choreCreationJoinFirst)),
        );
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

      final chore = await choreService.createChore(
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
          category: _category,
        ),
      );

      // Best-effort: surface who the chore landed on so a new chore reads as
      // part of the household rotation, not an isolated entry. Never blocks the
      // success path if the lookup fails.
      String? assignee;
      try {
        final details = await choreService.getChoreDetails(chore.id);
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

      if (!mounted) return;
      widget.dirtyNotifier?.value = false;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignee == null ? _l10n.choreCreationChoreAdded : _l10n.choreCreationChoreAddedNextUp(assignee),
          ),
        ),
      );
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
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
    switch (_assignmentPolicy) {
      case _AssignmentPolicy.roundRobin:
        return 'round-robin';
      case _AssignmentPolicy.alphabetical:
        return 'in-alphabetical-order';
      case _AssignmentPolicy.leastDone:
        return 'who-least-did-first';
      case _AssignmentPolicy.random:
        return 'random';
      case _AssignmentPolicy.noAssignment:
        return 'no-assignment';
    }
  }

  @override
  void dispose() {
    _intervalController.removeListener(_markDirty);
    _nameController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  // ---- Plain-language descriptions of the current selection ----

  String get _recurrenceHint => switch (_recurrence) {
        _Recurrence.none => _l10n.choreCreationHintNone,
        _Recurrence.hourly => _l10n.choreCreationHintHourly,
        _Recurrence.daily => _l10n.choreCreationHintDaily,
        _Recurrence.weekly => _l10n.choreCreationHintWeekly,
        _Recurrence.monthly => _l10n.choreCreationHintMonthly,
        _Recurrence.yearly => _l10n.choreCreationHintYearly,
        _Recurrence.adaptive => _l10n.choreCreationHintAdaptive,
      };

  String get _assignmentHint => switch (_assignmentPolicy) {
        _AssignmentPolicy.roundRobin => _l10n.choreCreationAssignHintTurns,
        _AssignmentPolicy.alphabetical =>
          _l10n.choreCreationAssignHintAlpha,
        _AssignmentPolicy.leastDone => _l10n.choreCreationAssignHintLeast,
        _AssignmentPolicy.random => _l10n.choreCreationAssignHintRandom,
        _AssignmentPolicy.noAssignment => _l10n.choreCreationAssignHintNone,
      };

  /// Live, singular-aware summary of the repeat interval, e.g. "Every 2 weeks".
  String get _intervalSummary {
    final n = _periodInterval;
    final unit = switch (_recurrence) {
      _Recurrence.hourly => n == 1 ? _l10n.choreCreationUnitHourSingular : _l10n.choreCreationUnitHourPlural,
      _Recurrence.weekly => n == 1 ? _l10n.choreCreationUnitWeekSingular : _l10n.choreCreationUnitWeekPlural,
      _Recurrence.monthly => n == 1 ? _l10n.choreCreationUnitMonthSingular : _l10n.choreCreationUnitMonthPlural,
      _Recurrence.yearly => n == 1 ? _l10n.choreCreationUnitYearSingular : _l10n.choreCreationUnitYearPlural,
      _ => n == 1 ? _l10n.choreCreationUnitDaySingular : _l10n.choreCreationUnitDayPlural,
    };
    return n == 1 ? _l10n.choreCreationEverySingular(unit) : _l10n.choreCreationEveryPlural(n, unit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final groupZones = _activeGroupZones();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Name ─────────────────────────────────────────────────────
        AppInput(
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

        if (groupZones.isNotEmpty) ...[
          _ChipRow(
            label: l10n.choreCreationZoneLabel,
            children: [
              for (final zone in groupZones)
                AppChip(
                  label: zone,
                  selected: _category == zone,
                  onSelected: (_) {
                    setState(() => _category = _category == zone ? null : zone);
                    _markDirty();
                  },
                ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
        ],

        // ── Repeats (inline row) ──────────────────────────────────────
        _ChipRow(
          label: l10n.choreCreationRepeatsLabel,
          children: [
            for (final option in [
              (_Recurrence.none, l10n.choreCreationRecurrenceNone),
              (_Recurrence.daily, l10n.choreCreationRecurrenceDaily),
              (_Recurrence.weekly, l10n.choreCreationRecurrenceWeekly),
              (_Recurrence.monthly, l10n.choreCreationRecurrenceMonthly),
              (_Recurrence.yearly, l10n.choreCreationRecurrenceYearly),
              (_Recurrence.hourly, l10n.choreCreationRecurrenceHourly),
              (_Recurrence.adaptive, l10n.choreCreationRecurrenceAdaptive),
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
            padding: const EdgeInsets.only(left: MitlistSpacing.space14),
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
                            padding:
                                const EdgeInsets.only(right: MitlistSpacing.xs),
                            child: AppChip(
                              label: day.$2,
                              selected: _weekdays.contains(day.$1),
                              onSelected: (_) {
                                setState(() {
                                  if (_weekdays.contains(day.$1) &&
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
                      _ChipRow(
                        label: l10n.choreCreationAssignLabel,
                        children: [
                          for (final option in [
                            (_AssignmentPolicy.roundRobin, l10n.choreCreationAssignTakeTurns),
                            (_AssignmentPolicy.leastDone, l10n.choreCreationAssignLeastDone),
                            (_AssignmentPolicy.alphabetical, l10n.choreCreationAssignAlphabetical),
                            (_AssignmentPolicy.random, l10n.choreCreationAssignRandom),
                            (_AssignmentPolicy.noAssignment, l10n.choreCreationAssignNoAssignee),
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
                      const SizedBox(height: MitlistSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: MitlistSpacing.space14,
                        ),
                        child: Text(
                          _assignmentHint,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: MitlistSpacing.md),
                      _OptionToggle(
                        value: _trackDateOnly,
                        onChanged: (value) {
                          setState(() => _trackDateOnly = value);
                          _markDirty();
                        },
                        title: l10n.choreCreationLogWhenDone,
                        helper:
                            l10n.choreCreationLogWhenDoneHelper,
                      ),
                      const SizedBox(height: MitlistSpacing.md),
                      _OptionToggle(
                        value: _rollover,
                        onChanged: (value) {
                          setState(() => _rollover = value);
                          _markDirty();
                        },
                        title: l10n.choreCreationRollOver,
                        helper:
                            l10n.choreCreationRollOverHelper,
                      ),
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
            text: _isSaving ? l10n.commonAdding : l10n.choreAddChore,
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
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
          width: MitlistSpacing.space14, // 56px — keeps chips aligned across rows
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

