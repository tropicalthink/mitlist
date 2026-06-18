import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/list_models.dart';
import '../providers/group_provider.dart';
import '../providers/list_provider.dart';
import '../router.dart' show currentGroupIdProvider;
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../utils/friendly_error.dart';
import '../l10n/app_localizations.dart';
import '../widgets/chip.dart';

enum _ListType { shopping, todo, custom }

class CreateListSheet extends ConsumerStatefulWidget {
  const CreateListSheet({
    super.key,
    this.initialGroupId,
    this.initialName,
    this.initialType,
  });

  final String? initialGroupId;
  final String? initialName;

  /// One of 'shopping', 'todo', 'custom'. Null → defaults to shopping.
  final String? initialType;

  static Future<bool?> show(
    BuildContext context, {
    String? initialGroupId,
    String? initialName,
    String? initialType,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<bool>(
      context: context,
      title: l10n.sheetCreateListTitle,
      body: CreateListSheet(
        initialGroupId: initialGroupId,
        initialName: initialName,
        initialType: initialType,
      ),
    );
  }

  @override
  ConsumerState<CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends ConsumerState<CreateListSheet> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  _ListType _selectedType = _ListType.shopping;
  String? _selectedGroupId;
  List<Group> _groups = const [];
  bool _isLoadingGroups = true;
  bool _isSubmitting = false;
  String? _errorText;
  String? _nameError;

  static _ListType _listTypeFromString(String? type) => switch (type) {
        'todo' => _ListType.todo,
        'custom' => _ListType.custom,
        _ => _ListType.shopping,
      };

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    _selectedType = _listTypeFromString(widget.initialType);
    _loadGroups();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_nameFocusNode.hasFocus) {
        _nameFocusNode.requestFocus();
      }
    });
  }

  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  Future<void> _loadGroups() async {
    setState(() => _errorText = null);
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      if (!mounted) return;

      setState(() {
        _groups = groups;
        final preferred =
            widget.initialGroupId ?? ref.read(currentGroupIdProvider);
        _selectedGroupId = resolveActiveGroupId(groups, preferred);
        _isLoadingGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = friendlyErrorMessage(e, AppLocalizations.of(context)!);
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

  String _selectedTypeDescription(AppLocalizations l10n) {
    return switch (_selectedType) {
      _ListType.shopping => l10n.createListShoppingDesc,
      _ListType.todo => l10n.createListTodoDesc,
      _ListType.custom => l10n.createListCustomDesc,
    };
  }

  Future<void> _attemptCreate() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = l10n.createListNameRequired);
      return;
    }
    await _onCreate();
  }

  Future<void> _onCreate() async {
    if (!_canCreate || _selectedGroupId == null) return;
    final l10n = AppLocalizations.of(context)!;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createListCreated)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorText != null) ...[
          Text(
            _errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppInput(
          label: l10n.sheetCreateListName,
          hint: l10n.sheetCreateListNameHint,
          controller: _nameController,
          focusNode: _nameFocusNode,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.done,
          maxLength: 100,
          clearable: true,
          errorText: _nameError,
          onChanged: (_) => setState(() {
            _nameError = null;
          }),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          l10n.sheetCreateListType,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: l10n.sheetCreateListTypeShopping,
              selected: _selectedType == _ListType.shopping,
              onSelected: _isSubmitting
                  ? null
                  : (_) => setState(() => _selectedType = _ListType.shopping),
            ),
            AppChip(
              label: l10n.sheetCreateListTypeTodo,
              selected: _selectedType == _ListType.todo,
              onSelected: _isSubmitting
                  ? null
                  : (_) => setState(() => _selectedType = _ListType.todo),
            ),
            AppChip(
              label: l10n.sheetCreateListTypeCustom,
              selected: _selectedType == _ListType.custom,
              onSelected: _isSubmitting
                  ? null
                  : (_) => setState(() => _selectedType = _ListType.custom),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          _selectedTypeDescription(l10n),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          l10n.createListHouseholdLabel,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        if (_isLoadingGroups)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
            child: CircularProgressIndicator(),
          )
        else if (_groups.isEmpty)
          Text(
            l10n.createListNoHousehold,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: _groups.map((group) {
              return AppChip(
                label: group.name.length > 30
                    ? '${group.name.substring(0, 28)}\u2026'
                    : group.name,
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
            text: _isSubmitting ? l10n.recipeCreationCreating : l10n.commonCreate,
            isLoading: _isSubmitting,
            onPressed: !_isLoadingGroups &&
                    !_isSubmitting &&
                    _selectedGroupId != null &&
                    _canCreate
                ? _attemptCreate
                : null,
          ),
        ),
      ],
    );
  }
}
