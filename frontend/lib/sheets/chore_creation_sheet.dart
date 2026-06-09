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

enum _TemplateEditAction { save, delete }

enum _AssignmentPolicy {
  roundRobin,
  alphabetical,
  leastDone,
  random,
  noAssignment,
}

/// A common household routine that pre-fills the form. Turns chore creation
/// from a blank config screen into picking from the household's shared rhythm.
class _ChoreTemplate {
  final String name;
  final _Recurrence recurrence;
  final int interval;
  final Set<String> weekdays;
  final _AssignmentPolicy assignment;
  final bool trackDateOnly;
  final bool rollover;
  final String? category;

  const _ChoreTemplate(
    this.name, {
    this.recurrence = _Recurrence.weekly,
    this.interval = 1,
    this.weekdays = const {'monday'},
    this.assignment = _AssignmentPolicy.roundRobin,
    this.trackDateOnly = false,
    this.rollover = true,
    this.category,
  });
}

/// Preset zones offered in the creation sheet. Free-form categories from
/// elsewhere still group correctly; these are just the common starting points.
const _zonePresets = <String>[
  'Kitchen',
  'Bathroom',
  'Living room',
  'Bedroom',
  'Outdoor',
  'Shared',
];

const _choreTemplates = <_ChoreTemplate>[
  _ChoreTemplate(
    'Dishes',
    recurrence: _Recurrence.daily,
    rollover: false,
    category: 'Kitchen',
  ),
  _ChoreTemplate(
    'Take out trash',
    weekdays: {'sunday'},
    assignment: _AssignmentPolicy.roundRobin,
    category: 'Kitchen',
  ),
  _ChoreTemplate('Vacuum', weekdays: {'saturday'}, category: 'Living room'),
  _ChoreTemplate(
    'Clean bathroom',
    weekdays: {'saturday'},
    category: 'Bathroom',
  ),
  _ChoreTemplate('Laundry', weekdays: {'sunday'}, category: 'Shared'),
  _ChoreTemplate(
    'Grocery run',
    weekdays: {'friday'},
    assignment: _AssignmentPolicy.leastDone,
    category: 'Shared',
  ),
  _ChoreTemplate(
    'Water plants',
    recurrence: _Recurrence.adaptive,
    interval: 3,
    trackDateOnly: true,
    assignment: _AssignmentPolicy.noAssignment,
    category: 'Outdoor',
  ),
  _ChoreTemplate(
    'Mop floors',
    interval: 2,
    weekdays: {'saturday'},
    category: 'Kitchen',
  ),
];

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
    future.whenComplete(dirty.dispose);
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
  String? _appliedTemplate;
  String? _appliedSavedId;
  String? _category;
  List<ChoreTemplate> _savedTemplates = [];
  bool _savingTemplate = false;

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
    _loadSavedTemplates();
  }

  Future<String?> _resolveGroupId() async {
    final groupService = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupService.listGroups(limit: 50);
    if (groups.isEmpty) return null;
    return resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
  }

  Future<void> _loadSavedTemplates() async {
    try {
      final groupId = await _resolveGroupId();
      if (groupId == null) return;
      final service = await ref.read(choreServiceProviderAsync.future);
      final templates = await service.listChoreTemplates(groupId);
      if (!mounted) return;
      setState(() => _savedTemplates = templates);
    } catch (_) {
      // Saved routines are an enhancement; the form works without them.
    }
  }

  void _markDirty() => widget.dirtyNotifier?.value = true;

  Future<void> _onEditTemplate(ChoreTemplate t) async {
    final nameController = TextEditingController(text: t.name);
    final result = await showDialog<_TemplateEditAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit routine'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _TemplateEditAction.delete),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _TemplateEditAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final newName = nameController.text.trim();
    nameController.dispose();
    if (result == null || !mounted) return;

    try {
      final service = await ref.read(choreServiceProviderAsync.future);
      if (result == _TemplateEditAction.save) {
        if (newName.isEmpty || newName == t.name) return;
        final updated = await service.updateChoreTemplate(
          t.id,
          UpdateChoreTemplateRequest(name: newName),
        );
        if (!mounted) return;
        setState(() {
          final idx = _savedTemplates.indexWhere((x) => x.id == t.id);
          if (idx != -1) _savedTemplates[idx] = updated;
          if (_appliedSavedId == t.id) _nameController.text = updated.name;
        });
      } else {
        await service.deleteChoreTemplate(t.id);
        if (!mounted) return;
        setState(() {
          _savedTemplates.removeWhere((x) => x.id == t.id);
          if (_appliedSavedId == t.id) _appliedSavedId = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  /// Pre-fills the form from a routine. The name only overwrites an empty
  /// field, so a template never clobbers what the user already typed.
  void _applyTemplate(_ChoreTemplate template) {
    setState(() {
      _appliedTemplate = template.name;
      _appliedSavedId = null;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = template.name;
      }
      _recurrence = template.recurrence;
      _intervalController.text = '${template.interval}';
      _weekdays
        ..clear()
        ..addAll(template.weekdays);
      _assignmentPolicy = template.assignment;
      _trackDateOnly = template.trackDateOnly;
      _rollover = template.rollover;
      _category = template.category;
    });
    _markDirty();
    Haptics.light();
  }

  static _Recurrence _recurrenceFromFrequency(String f) => switch (f) {
        'hourly' => _Recurrence.hourly,
        'daily' => _Recurrence.daily,
        'weekly' => _Recurrence.weekly,
        'monthly' => _Recurrence.monthly,
        'yearly' => _Recurrence.yearly,
        'adaptive' => _Recurrence.adaptive,
        _ => _Recurrence.none,
      };

  static _AssignmentPolicy _policyFromAssignment(String a) => switch (a) {
        'in-alphabetical-order' => _AssignmentPolicy.alphabetical,
        'who-least-did-first' => _AssignmentPolicy.leastDone,
        'random' => _AssignmentPolicy.random,
        'no-assignment' => _AssignmentPolicy.noAssignment,
        _ => _AssignmentPolicy.roundRobin,
      };

  /// Fills the form from a saved routine (a backend [ChoreTemplate]).
  void _applySavedTemplate(ChoreTemplate t) {
    setState(() {
      _appliedSavedId = t.id;
      _appliedTemplate = null;
      if (_nameController.text.trim().isEmpty) _nameController.text = t.name;
      if ((t.description ?? '').isNotEmpty &&
          _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = t.description!;
      }
      _recurrence = _recurrenceFromFrequency(t.frequency);
      _intervalController.text = '${t.periodInterval}';
      _weekdays
        ..clear()
        ..addAll(t.periodConfig.isEmpty ? {'monday'} : t.periodConfig);
      _assignmentPolicy = _policyFromAssignment(t.assignmentType);
      _trackDateOnly = t.trackDateOnly;
      _rollover = t.rollover;
      _category = t.category;
    });
    _markDirty();
    Haptics.light();
  }

  /// Saves the current form as a reusable household routine.
  Future<void> _saveAsRoutine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _savingTemplate) return;
    setState(() => _savingTemplate = true);
    try {
      final groupId = await _resolveGroupId();
      if (groupId == null) {
        if (!mounted) return;
        setState(() => _savingTemplate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create or join a household first.')),
        );
        return;
      }
      final service = await ref.read(choreServiceProviderAsync.future);
      final created = await service.createChoreTemplate(
        CreateChoreTemplateRequest(
          groupId: groupId,
          name: name,
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
      if (!mounted) return;
      setState(() {
        _savingTemplate = false;
        _savedTemplates = [created, ..._savedTemplates];
        _appliedSavedId = created.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${created.name}" as a routine')),
      );
      Haptics.success();
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingTemplate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
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
      final groups = await groupService.listGroups(limit: 50);
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
      Haptics.success();
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

    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.lg),
          child: Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant,
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_savedTemplates.isNotEmpty) ...[
          Text('Your routines', style: textTheme.labelMedium),
          const SizedBox(height: MitlistSpacing.sm),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: [
              for (final t in _savedTemplates)
                GestureDetector(
                  onLongPress: () => _onEditTemplate(t),
                  child: AppChip(
                    label: t.name,
                    selected: _appliedSavedId == t.id,
                    onSelected: (_) => _applySavedTemplate(t),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        Text(
          _savedTemplates.isEmpty ? 'Start from a routine' : 'Or a suggestion',
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            for (final template in _choreTemplates)
              AppChip(
                label: template.name,
                selected: _appliedTemplate == template.name,
                onSelected: (_) => _applyTemplate(template),
              ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          'Tap a routine to fill the form, then tweak anything below.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        divider(),
        AppButton(
          text: _isScanning ? 'Scanning…' : 'Scan chore',
          icon: AppIcon(
            name: _isScanning ? 'hourglassEmpty' : 'documentScanner',
            size: 20,
          ),
          variant: AppButtonVariant.outline,
          color: AppButtonColor.neutral,
          onPressed: _isScanning ? null : _onScan,
          semanticLabel: 'Scan chore via camera',
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Chore name',
          hint: 'e.g. Vacuum living room',
          controller: _nameController,
          textInputAction: TextInputAction.next,
          maxLength: 100,
          onChanged: (_) {
            _markDirty();
            setState(() {});
          },
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Notes (optional)',
          hint: 'Add any details or steps for this chore',
          controller: _descriptionController,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 5,
          maxLength: 500,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text('Zone (optional)', style: textTheme.labelMedium),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            for (final zone in _zonePresets)
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
        Text(
          'Group chores by room or area so your household sees them as a system.',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        divider(),

        // ---- Repeats ----
        Text('Repeats', style: textTheme.labelMedium),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
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
                  setState(() {
                    _recurrence = option.$1;
                    _appliedTemplate = null;
                  });
                  _markDirty();
                },
              ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          _recurrenceHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (_recurrence != _Recurrence.none) ...[
          const SizedBox(height: MitlistSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 96,
                child: AppInput(
                  label: 'Repeat every',
                  hint: '1',
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: MitlistSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.space3),
                  child: Text(
                    _intervalSummary,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_recurrence == _Recurrence.weekly) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text('On these days', style: textTheme.labelMedium),
          const SizedBox(height: MitlistSpacing.sm),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: const [
              ('monday', 'Mon'),
              ('tuesday', 'Tue'),
              ('wednesday', 'Wed'),
              ('thursday', 'Thu'),
              ('friday', 'Fri'),
              ('saturday', 'Sat'),
              ('sunday', 'Sun'),
            ].map((day) {
              return AppChip(
                label: day.$2,
                selected: _weekdays.contains(day.$1),
                onSelected: (_) {
                  setState(() {
                    if (_weekdays.contains(day.$1) && _weekdays.length > 1) {
                      _weekdays.remove(day.$1);
                    } else {
                      _weekdays.add(day.$1);
                    }
                  });
                  _markDirty();
                },
              );
            }).toList(),
          ),
        ],
        divider(),

        // ---- Who does it ----
        Text('Who does it?', style: textTheme.labelMedium),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
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
                  setState(() {
                    _assignmentPolicy = option.$1;
                    _appliedTemplate = null;
                  });
                  _markDirty();
                },
              ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          _assignmentHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        divider(),

        // ---- Options ----
        Text('Options', style: textTheme.labelMedium),
        const SizedBox(height: MitlistSpacing.md),
        _OptionToggle(
          value: _trackDateOnly,
          onChanged: (value) {
            setState(() => _trackDateOnly = value);
            _markDirty();
          },
          title: 'Log when it\'s done, don\'t tick it off',
          helper:
              'Records the day someone did it without checking it off the list. '
              'Good for things you want a history of, like watering plants.',
        ),
        const SizedBox(height: MitlistSpacing.md),
        _OptionToggle(
          value: _rollover,
          onChanged: (value) {
            setState(() => _rollover = value);
            _markDirty();
          },
          title: 'Roll over if it\'s missed',
          helper:
              'If nobody does it in time, it moves to the next due date instead '
              'of piling up as overdue.',
        ),
        const SizedBox(height: MitlistSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            text: _savingTemplate ? 'Saving…' : 'Save as routine',
            icon: const AppIcon(name: 'star', size: 18),
            variant: AppButtonVariant.ghost,
            color: AppButtonColor.neutral,
            size: AppButtonSize.sm,
            isLoading: _savingTemplate,
            onPressed:
                (_canCreate && !_savingTemplate) ? _saveAsRoutine : null,
            semanticLabel: 'Save this chore as a reusable routine',
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
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

/// A labelled switch row with a visible helper line, replacing the previous
/// tooltip-only explanations (which never appear on touch).
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
