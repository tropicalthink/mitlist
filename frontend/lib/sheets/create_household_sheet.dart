import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class CreateHouseholdSheet extends StatefulWidget {
  const CreateHouseholdSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'Create Household',
      body: const CreateHouseholdSheet(),
    );
  }

  @override
  State<CreateHouseholdSheet> createState() => _CreateHouseholdSheetState();
}

class _CreateHouseholdSheetState extends State<CreateHouseholdSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  void _onCreate() {
    if (!_canCreate) return;
    Navigator.of(context).pop();
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
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Description (optional)',
          hint: 'A few words about this household',
          controller: _descriptionController,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: 'Create',
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
