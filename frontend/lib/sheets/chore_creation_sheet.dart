import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chore_models.dart';
import '../providers/chore_provider.dart';
import '../providers/group_provider.dart';
import '../providers/scan_provider.dart';
import '../router.dart' show currentGroupIdProvider;
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../utils/haptics.dart';
import '../widgets/animated_check_toggle.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_input.dart';
import '../utils/friendly_error.dart';
import '../widgets/chip.dart';

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
    final future = showAppBottomSheet<bool>(
      context: context,
      title: 'Add chore',
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
  bool _isScanning = false;
  bool _showAdvanced = false;
  String? _category;

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

  Future<void> _onScan() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;

    setState(() => _isScanning = true);
    _markDirty();

    try {
      final service = await ref.read(scanServiceProviderAsync.future);
      final bytes = await File(picked.path).readAsBytes();
      final result = await service.scanImage(bytes, 'image/jpeg');

      if (!mounted) return;

      if (result.title != null && result.title!.isNotEmpty) {
        _nameController.text = result.title!;
      }
      if (result.steps.isNotEmpty) {
        _descriptionController.text = result.steps.join('\n');
      }

      setState(() => _isScanning = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
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
          const SnackBar(content: Text('Create or join a household first.')),
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
            assignee == null ? 'Chore added' : 'Chore added · next up: $assignee',
          ),
        ),
      );
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
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
        _Recurrence.none => 'A one-time chore. It won\'t come back on its own.',
        _Recurrence.hourly => 'Comes back every set number of hours.',
        _Recurrence.daily => 'Comes back every set number of days.',
        _Recurrence.weekly => 'Comes back each week on the days you pick.',
        _Recurrence.monthly => 'Comes back monthly on the same date.',
        _Recurrence.yearly => 'Comes back yearly on the same date.',
        _Recurrence.adaptive =>
          'Comes back based on when it was last done, not the calendar.',
      };

  String get _assignmentHint => switch (_assignmentPolicy) {
        _AssignmentPolicy.roundRobin => 'Rotates to the next person each time.',
        _AssignmentPolicy.alphabetical =>
          'Goes in alphabetical order of names.',
        _AssignmentPolicy.leastDone => 'Goes to whoever has done it least.',
        _AssignmentPolicy.random => 'Picks someone at random each time.',
        _AssignmentPolicy.noAssignment =>
          'Stays unassigned. Anyone in the household can pick it up.',
      };

  /// Live, singular-aware summary of the repeat interval, e.g. "Every 2 weeks".
  String get _intervalSummary {
    final n = _periodInterval;
    final (singular, plural) = switch (_recurrence) {
      _Recurrence.hourly => ('hour', 'hours'),
      _Recurrence.weekly => ('week', 'weeks'),
      _Recurrence.monthly => ('month', 'months'),
      _Recurrence.yearly => ('year', 'years'),
      _ => ('day', 'days'),
    };
    return n == 1 ? 'Every $singular' : 'Every $n $plural';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final groupZones = _activeGroupZones();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Name + scan ───────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppInput(
                hint: 'Chore name',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                onChanged: (_) {
                  _markDirty();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            _ScanIconButton(
              isScanning: _isScanning,
              onPressed: _isScanning ? null : _onScan,
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),

        if (groupZones.isNotEmpty) ...[
          _ChipRow(
            label: 'Zone',
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
          label: 'Repeats',
          children: [
            for (final option in const [
              (_Recurrence.none, 'None'),
              (_Recurrence.daily, 'Daily'),
              (_Recurrence.weekly, 'Weekly'),
              (_Recurrence.monthly, 'Monthly'),
              (_Recurrence.yearly, 'Yearly'),
              (_Recurrence.hourly, 'Hourly'),
              (_Recurrence.adaptive, 'Adaptive'),
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
                        hint: '1',
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
                        for (final day in const [
                          ('monday', 'Mon'),
                          ('tuesday', 'Tue'),
                          ('wednesday', 'Wed'),
                          ('thursday', 'Thu'),
                          ('friday', 'Fri'),
                          ('saturday', 'Sat'),
                          ('sunday', 'Sun'),
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
                  'More options',
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
                        label: 'Assign',
                        children: [
                          for (final option in const [
                            (_AssignmentPolicy.roundRobin, 'Take turns'),
                            (_AssignmentPolicy.leastDone, 'Least done'),
                            (_AssignmentPolicy.alphabetical, 'Alphabetical'),
                            (_AssignmentPolicy.random, 'Random'),
                            (_AssignmentPolicy.noAssignment, 'No assignee'),
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
                        title: 'Log when done, don\'t tick off',
                        helper:
                            'Records the date without marking it complete. Good for tasks you want a history of.',
                      ),
                      const SizedBox(height: MitlistSpacing.md),
                      _OptionToggle(
                        value: _rollover,
                        onChanged: (value) {
                          setState(() => _rollover = value);
                          _markDirty();
                        },
                        title: 'Roll over if missed',
                        helper:
                            'Shifts to the next due date instead of piling up as overdue.',
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: MitlistSpacing.md),

        // ── Notes ─────────────────────────────────────────────────────
        AppInput(
          hint: 'Notes (optional) — steps, reminders, anything useful',
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
            text: _isSaving ? 'Adding…' : 'Add chore',
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

class _ScanIconButton extends StatelessWidget {
  final bool isScanning;
  final VoidCallback? onPressed;

  const _ScanIconButton({required this.isScanning, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Scan chore via camera',
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: MitlistSpacing.space11,
          height: MitlistSpacing.space11,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline, width: 2),
          ),
          child: Center(
            child: isScanning
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : AppIcon(name: 'documentScanner', size: 20),
          ),
        ),
      ),
    );
  }
}
