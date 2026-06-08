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

  const ChoreCreationSheet({
    super.key,
    this.initialTitle,
    this.initialDescription,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialTitle,
    String? initialDescription,
  }) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'Add chore',
      body: ChoreCreationSheet(
        initialTitle: initialTitle,
        initialDescription: initialDescription,
      ),
    );
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

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _nameController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
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

      await choreService.createChore(
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
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chore added')),
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
    return parsed < 1 ? 1 : parsed;
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
    _nameController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          textInputAction: TextInputAction.done,
          maxLength: 100,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Notes (optional)',
          hint: 'Add any details for this chore',
          controller: _descriptionController,
          textInputAction: TextInputAction.done,
          maxLength: 500,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Recurrence',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: 'None',
              selected: _recurrence == _Recurrence.none,
              onSelected: (_) => setState(() => _recurrence = _Recurrence.none),
            ),
            Tooltip(
              message: 'No repeating schedule',
              child: AppChip(
                label: 'Hourly',
                selected: _recurrence == _Recurrence.hourly,
                onSelected: (_) =>
                    setState(() => _recurrence = _Recurrence.hourly),
              ),
            ),
            Tooltip(
              message: 'Repeats every day',
              child: AppChip(
                label: 'Daily',
                selected: _recurrence == _Recurrence.daily,
                onSelected: (_) =>
                    setState(() => _recurrence = _Recurrence.daily),
              ),
            ),
            Tooltip(
              message: 'Repeats every week on selected days',
              child: AppChip(
                label: 'Weekly',
                selected: _recurrence == _Recurrence.weekly,
                onSelected: (_) =>
                    setState(() => _recurrence = _Recurrence.weekly),
              ),
            ),
            Tooltip(
              message: 'Repeats once a month on the same date',
              child: AppChip(
                label: 'Monthly',
                selected: _recurrence == _Recurrence.monthly,
                onSelected: (_) =>
                    setState(() => _recurrence = _Recurrence.monthly),
              ),
            ),
            Tooltip(
              message: 'Repeats once a year on the same date',
              child: AppChip(
                label: 'Yearly',
                selected: _recurrence == _Recurrence.yearly,
                onSelected: (_) =>
                    setState(() => _recurrence = _Recurrence.yearly),
              ),
            ),
            Tooltip(
              message: 'Repeats based on completion date, not the calendar',
              child: AppChip(
                label: 'Adaptive',
                selected: _recurrence == _Recurrence.adaptive,
                onSelected: (_) =>
                    setState(() => _recurrence = _Recurrence.adaptive),
              ),
            ),
          ],
        ),
        if (_recurrence != _Recurrence.none) ...[
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: 'Interval',
            hint: '1',
            controller: _intervalController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
        ],
        if (_recurrence == _Recurrence.weekly) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            'Weekdays',
            style: Theme.of(context).textTheme.labelMedium,
          ),
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
                },
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Assignment',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            Tooltip(
              message: 'Assigns to the next person in order',
              child: AppChip(
                label: 'Round-robin',
                selected: _assignmentPolicy == _AssignmentPolicy.roundRobin,
                onSelected: (_) => setState(
                  () => _assignmentPolicy = _AssignmentPolicy.roundRobin,
                ),
              ),
            ),
            Tooltip(
              message: 'Assigns based on alphabetical order of member names',
              child: AppChip(
                label: 'Alphabetical',
                selected: _assignmentPolicy == _AssignmentPolicy.alphabetical,
                onSelected: (_) => setState(
                  () => _assignmentPolicy = _AssignmentPolicy.alphabetical,
                ),
              ),
            ),
            Tooltip(
              message: 'Assigns to whoever has done it the least',
              child: AppChip(
                label: 'Least done',
                selected: _assignmentPolicy == _AssignmentPolicy.leastDone,
                onSelected: (_) => setState(
                  () => _assignmentPolicy = _AssignmentPolicy.leastDone,
                ),
              ),
            ),
            Tooltip(
              message: 'Picks someone at random',
              child: AppChip(
                label: 'Random',
                selected: _assignmentPolicy == _AssignmentPolicy.random,
                onSelected: (_) => setState(
                  () => _assignmentPolicy = _AssignmentPolicy.random,
                ),
              ),
            ),
            Tooltip(
              message: 'Do not assign this chore to anyone',
              child: AppChip(
                label: 'No assignee',
                selected: _assignmentPolicy == _AssignmentPolicy.noAssignment,
                onSelected: (_) => setState(
                  () => _assignmentPolicy = _AssignmentPolicy.noAssignment,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Tooltip(
          message: "Records the chore day but doesn't mark it complete",
          child: Row(
            children: [
              AnimatedCheckToggle(
                value: _trackDateOnly,
                onChanged: (value) => setState(() => _trackDateOnly = value),
                semanticLabelOn: 'Untrack date only',
                semanticLabelOff: 'Track date only',
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Text('Track date only', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        Tooltip(
          message: 'Overdue chores roll over to the next due date',
          child: Row(
            children: [
              AnimatedCheckToggle(
                value: _rollover,
                onChanged: (value) => setState(() => _rollover = value),
                semanticLabelOn: 'Do not rollover overdue due date',
                semanticLabelOff: 'Rollover overdue due date',
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Text('Rollover overdue due date', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isSaving ? 'Adding...' : 'Add chore',
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
