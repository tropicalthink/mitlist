import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/list_models.dart';
import '../providers/group_provider.dart';
import '../providers/list_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

enum _ListType { shopping, todo, custom }

class CreateListSheet extends ConsumerStatefulWidget {
  const CreateListSheet({
    super.key,
    this.initialGroupId,
    this.initialName,
  });

  final String? initialGroupId;
  final String? initialName;

  static Future<bool?> show(
    BuildContext context, {
    String? initialGroupId,
    String? initialName,
  }) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'New List',
      body: CreateListSheet(
        initialGroupId: initialGroupId,
        initialName: initialName,
      ),
    );
  }

  @override
  ConsumerState<CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends ConsumerState<CreateListSheet> {
  final TextEditingController _nameController = TextEditingController();
  _ListType _selectedType = _ListType.shopping;
  String? _selectedGroupId;
  List<Group> _groups = const [];
  bool _isLoadingGroups = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    _loadGroups();
  }

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  Future<void> _loadGroups() async {
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
      if (!mounted) return;

      setState(() {
        _groups = groups;
        final preferred = widget.initialGroupId;
        _selectedGroupId = groups.any((group) => group.id == preferred)
            ? preferred
            : (groups.isNotEmpty ? groups.first.id : null);
        _isLoadingGroups = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to load households.';
        _isLoadingGroups = false;
      });
    }
  }

  String get _selectedTypeValue {
    return switch (_selectedType) {
      _ListType.shopping => 'shopping',
      _ListType.todo => 'todo',
      _ListType.custom => 'custom',
    };
  }

  Future<void> _onCreate() async {
    if (!_canCreate || _selectedGroupId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final listService = await ref.read(listServiceProviderAsync.future);
      await listService.createList(
        CreateListRequest(
          groupId: _selectedGroupId!,
          name: _nameController.text.trim(),
          type: _selectedTypeValue,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to create list.';
        _isSubmitting = false;
      });
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
        if (_errorText != null) ...[
          Text(
            _errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MitlistColors.error500,
                ),
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppInput(
          label: 'List Name',
          hint: 'e.g. Weekend Groceries',
          controller: _nameController,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Type'.toUpperCase(),
          style:
              MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: 'Shopping',
              selected: _selectedType == _ListType.shopping,
              onSelected: _isSubmitting
                  ? null
                  : (_) => setState(() => _selectedType = _ListType.shopping),
            ),
            AppChip(
              label: 'To-do',
              selected: _selectedType == _ListType.todo,
              onSelected: _isSubmitting
                  ? null
                  : (_) => setState(() => _selectedType = _ListType.todo),
            ),
            AppChip(
              label: 'Custom',
              selected: _selectedType == _ListType.custom,
              onSelected: _isSubmitting
                  ? null
                  : (_) => setState(() => _selectedType = _ListType.custom),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Household'.toUpperCase(),
          style:
              MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        if (_isLoadingGroups)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
            child: CircularProgressIndicator(),
          )
        else if (_groups.isEmpty)
          Text(
            'No household available.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: _groups.map((group) {
              return AppChip(
                label: group.name,
                selected: _selectedGroupId == group.id,
                onSelected: _isSubmitting
                    ? null
                    : (_) => setState(() => _selectedGroupId = group.id),
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
            onPressed: _canCreate && !_isLoadingGroups && !_isSubmitting
                ? _onCreate
                : null,
          ),
        ),
      ],
    );
  }
}
