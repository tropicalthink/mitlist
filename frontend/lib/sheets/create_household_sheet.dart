import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class CreateHouseholdSheet extends ConsumerStatefulWidget {
  const CreateHouseholdSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'Create Household',
      body: const CreateHouseholdSheet(),
    );
  }

  @override
  ConsumerState<CreateHouseholdSheet> createState() => _CreateHouseholdSheetState();
}

class _CreateHouseholdSheetState extends ConsumerState<CreateHouseholdSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isCreating = false;

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isCreating;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isCreating = true);

    try {
      final service = await ref.read(groupServiceProviderAsync.future);
      await service.createGroup(CreateGroupRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Household created')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t create household.')),
      );
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
          label: 'Household Name',
          hint: 'e.g. Carter St',
          controller: _nameController,
          textInputAction: TextInputAction.next,
          maxLength: 80,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Description (optional)',
          hint: 'A few words about this household',
          controller: _descriptionController,
          textInputAction: TextInputAction.done,
          maxLength: 300,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isCreating ? 'Creating...' : 'Create',
            isLoading: _isCreating,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
