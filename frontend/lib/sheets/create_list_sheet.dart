import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

enum _ListType { shopping, todo, custom }

class CreateListSheet extends StatefulWidget {
  const CreateListSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'New List',
      body: const CreateListSheet(),
    );
  }

  @override
  State<CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<CreateListSheet> {
  final TextEditingController _nameController = TextEditingController();
  _ListType _selectedType = _ListType.shopping;
  String? _selectedGroup;

  final List<String> _groups = const ['Personal', 'Carter St', 'Beach House'];

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  void _onCreate() {
    if (!_canCreate) return;
    Navigator.of(context).pop();
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
          label: 'List Name',
          hint: 'e.g. Weekend Groceries',
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Type'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: 'Shopping',
              selected: _selectedType == _ListType.shopping,
              onSelected: (_) => setState(() => _selectedType = _ListType.shopping),
            ),
            AppChip(
              label: 'To-do',
              selected: _selectedType == _ListType.todo,
              onSelected: (_) => setState(() => _selectedType = _ListType.todo),
            ),
            AppChip(
              label: 'Custom',
              selected: _selectedType == _ListType.custom,
              onSelected: (_) => setState(() => _selectedType = _ListType.custom),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Household'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: _groups.map((group) {
            return AppChip(
              label: group,
              selected: _selectedGroup == group,
              onSelected: (_) => setState(() => _selectedGroup = group),
            );
          }).toList(),
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
