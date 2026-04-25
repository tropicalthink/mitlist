import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

enum _VaultCategory { wifi, paint, insurance, warranty, emergency, custom }

class VaultItemFormSheet extends StatefulWidget {
  const VaultItemFormSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'New Vault Item',
      body: const VaultItemFormSheet(),
    );
  }

  @override
  State<VaultItemFormSheet> createState() => _VaultItemFormSheetState();
}

class _VaultItemFormSheetState extends State<VaultItemFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  final List<MapEntry<TextEditingController, TextEditingController>> _fields = [];

  _VaultCategory _category = _VaultCategory.wifi;
  DateTime? _expiryDate;

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  void _addField() {
    setState(() {
      _fields.add(MapEntry(TextEditingController(), TextEditingController()));
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields[index].key.dispose();
      _fields[index].value.dispose();
      _fields.removeAt(index);
    });
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  void _onSave() {
    if (!_canSave) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final field in _fields) {
      field.key.dispose();
      field.value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: 'Item Name',
          hint: 'e.g. Home Wi-Fi',
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Category'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: 'Wi-Fi',
              selected: _category == _VaultCategory.wifi,
              onSelected: (_) => setState(() => _category = _VaultCategory.wifi),
            ),
            AppChip(
              label: 'Paint',
              selected: _category == _VaultCategory.paint,
              onSelected: (_) => setState(() => _category = _VaultCategory.paint),
            ),
            AppChip(
              label: 'Insurance',
              selected: _category == _VaultCategory.insurance,
              onSelected: (_) => setState(() => _category = _VaultCategory.insurance),
            ),
            AppChip(
              label: 'Warranty',
              selected: _category == _VaultCategory.warranty,
              onSelected: (_) => setState(() => _category = _VaultCategory.warranty),
            ),
            AppChip(
              label: 'Emergency',
              selected: _category == _VaultCategory.emergency,
              onSelected: (_) => setState(() => _category = _VaultCategory.emergency),
            ),
            AppChip(
              label: 'Custom',
              selected: _category == _VaultCategory.custom,
              onSelected: (_) => setState(() => _category = _VaultCategory.custom),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Fields'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        ..._fields.asMap().entries.map((entry) {
          final index = entry.key;
          final controllers = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: AppInput(
                    hint: 'Label',
                    controller: controllers.key,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: AppInput(
                    hint: 'Value',
                    controller: controllers.value,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.ghost,
                  color: AppButtonColor.error,
                  size: AppButtonSize.sm,
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeField(index),
                ),
              ],
            ),
          );
        }),
        AppButton(
          variant: AppButtonVariant.outline,
          color: AppButtonColor.primary,
          size: AppButtonSize.md,
          text: 'Add Field',
          onPressed: _addField,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Expiry Date (optional)'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        InkWell(
          onTap: _pickExpiryDate,
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
                    _expiryDate != null
                        ? '${_expiryDate!.day.toString().padLeft(2, '0')}/${_expiryDate!.month.toString().padLeft(2, '0')}/${_expiryDate!.year}'
                        : 'No expiry',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _expiryDate != null
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
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: 'Save Item',
            onPressed: _canSave ? _onSave : null,
          ),
        ),
      ],
    );
  }
}
