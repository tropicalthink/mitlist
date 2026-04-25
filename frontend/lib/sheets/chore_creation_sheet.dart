import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chore_models.dart';
import '../providers/chore_provider.dart';
import '../providers/group_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

enum _Recurrence { none, daily, weekly, monthly }

class ChoreCreationSheet extends ConsumerStatefulWidget {
  const ChoreCreationSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'Add Chore',
      body: const ChoreCreationSheet(),
    );
  }

  @override
  ConsumerState<ChoreCreationSheet> createState() => _ChoreCreationSheetState();
}

class _ChoreCreationSheetState extends ConsumerState<ChoreCreationSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  _Recurrence _recurrence = _Recurrence.none;
  bool _isSaving = false;

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isSaving = true);

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final choreService = await ref.read(choreServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 1);

      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create or join a household first.')),
        );
        return;
      }

      await choreService.createChore(
        CreateChoreRequest(
          groupId: groups.first.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          frequency: _frequencyValue(),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chore added')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add chore: $e')),
      );
    }
  }

  String _frequencyValue() {
    switch (_recurrence) {
      case _Recurrence.none:
        return 'none';
      case _Recurrence.daily:
        return 'daily';
      case _Recurrence.weekly:
        return 'weekly';
      case _Recurrence.monthly:
        return 'monthly';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
        AppInput(
          label: 'Notes (optional)',
          hint: 'Add any details for this chore',
          controller: _descriptionController,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Recurrence'.toUpperCase(),
          style:
              MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
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
              onSelected: (_) =>
                  setState(() => _recurrence = _Recurrence.daily),
            ),
            AppChip(
              label: 'Weekly',
              selected: _recurrence == _Recurrence.weekly,
              onSelected: (_) =>
                  setState(() => _recurrence = _Recurrence.weekly),
            ),
            AppChip(
              label: 'Monthly',
              selected: _recurrence == _Recurrence.monthly,
              onSelected: (_) =>
                  setState(() => _recurrence = _Recurrence.monthly),
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
            text: _isSaving ? 'Adding...' : 'Add Chore',
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
