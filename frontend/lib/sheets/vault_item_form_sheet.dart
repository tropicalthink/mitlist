import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vault_models.dart';
import '../providers/group_provider.dart';
import '../providers/vault_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

enum _VaultCategory { wifi, paint, insurance, warranty, emergency, custom }

class VaultItemFormSheet extends ConsumerStatefulWidget {
  const VaultItemFormSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'New Vault Item',
      body: const VaultItemFormSheet(),
    );
  }

  @override
  ConsumerState<VaultItemFormSheet> createState() => _VaultItemFormSheetState();
}

class _VaultItemFormSheetState extends ConsumerState<VaultItemFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  final List<MapEntry<TextEditingController, TextEditingController>> _fields = [];

  _VaultCategory _category = _VaultCategory.wifi;
  DateTime? _expiryDate;
  bool _isSaving = false;

  bool get _canSave => _nameController.text.trim().isNotEmpty && !_isSaving;

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

  Future<void> _onSave() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final vaultService = await ref.read(vaultServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 1);

      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create or join a household first.')),
        );
        return;
      }

      await vaultService.createVaultItem(
        CreateVaultItemRequest(
          groupId: groups.first.id,
          type: _category.name,
          title: _nameController.text.trim(),
          content: _buildContent(),
          reminderDate: _expiryDate,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault item saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save item: $e')),
      );
    }
  }

  String _buildContent() {
    final pairs = _fields
        .map(
          (entry) => MapEntry(entry.key.text.trim(), entry.value.text.trim()),
        )
        .where((entry) => entry.key.isNotEmpty || entry.value.isNotEmpty)
        .toList();
    return pairs.map((entry) => '${entry.key}: ${entry.value}').join('\n');
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
            text: _isSaving ? 'Saving...' : 'Save Item',
            isLoading: _isSaving,
            onPressed: _canSave ? _onSave : null,
          ),
        ),
      ],
    );
  }
}
