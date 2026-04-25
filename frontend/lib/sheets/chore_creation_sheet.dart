import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

enum _Recurrence { none, daily, weekly, monthly }

class ChoreCreationSheet extends StatefulWidget {
  const ChoreCreationSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'Add Chore',
      body: const ChoreCreationSheet(),
    );
  }

  @override
  State<ChoreCreationSheet> createState() => _ChoreCreationSheetState();
}

class _ChoreCreationSheetState extends State<ChoreCreationSheet> {
  final TextEditingController _nameController = TextEditingController();

  String? _selectedAssignee;
  DateTime? _dueDate;
  _Recurrence _recurrence = _Recurrence.none;

  final List<String> _assignees = const ['You', 'Alex', 'Jordan', 'Sam', 'Unassigned'];

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  void _onCreate() {
    if (!_canCreate) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: 'Chore Name',
          hint: 'e.g. Vacuum living room',
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Assignee'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: _assignees.map((assignee) {
            return AppChip(
              label: assignee,
              selected: _selectedAssignee == assignee,
              onSelected: (_) => setState(() => _selectedAssignee = assignee),
            );
          }).toList(),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Due Date'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        InkWell(
          onTap: _pickDueDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
              vertical: MitlistSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: MitlistColors.surfacePrimary,
              border: Border.all(color: MitlistColors.borderPrimary, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dueDate != null
                        ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                        : 'Select a date',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _dueDate != null
                              ? MitlistColors.textPrimary
                              : MitlistColors.textTertiary,
                        ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: MitlistColors.textPrimary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Recurrence'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
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
            AppChip(
              label: 'Daily',
              selected: _recurrence == _Recurrence.daily,
              onSelected: (_) => setState(() => _recurrence = _Recurrence.daily),
            ),
            AppChip(
              label: 'Weekly',
              selected: _recurrence == _Recurrence.weekly,
              onSelected: (_) => setState(() => _recurrence = _Recurrence.weekly),
            ),
            AppChip(
              label: 'Monthly',
              selected: _recurrence == _Recurrence.monthly,
              onSelected: (_) => setState(() => _recurrence = _Recurrence.monthly),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: 'Add Chore',
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
