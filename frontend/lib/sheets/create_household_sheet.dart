import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_currency_dropdown.dart';
import '../utils/friendly_error.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_input.dart';

import '../widgets/app_toast.dart';

class CreateHouseholdSheet extends ConsumerStatefulWidget {
  const CreateHouseholdSheet({super.key});

  static Future<Group?> show(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<Group>(
      context: context,
      title: l10n.sheetCreateHouseholdTitle,
      body: const CreateHouseholdSheet(),
    );
  }

  @override
  ConsumerState<CreateHouseholdSheet> createState() =>
      _CreateHouseholdSheetState();
}

class _CreateHouseholdSheetState extends ConsumerState<CreateHouseholdSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _currency = 'USD';
  bool _isCreating = false;

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isCreating;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isCreating = true);

    try {
      final service = await ref.read(groupServiceProviderAsync.future);
      final group = await service.createGroup(CreateGroupRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        currency: _currency,
      ));
      // The cached household list must be refetched before any screen
      // resolves its active group against it — without this the new group is
      // missing from the cache and the home screen lands on "no household"
      // until an app restart.
      // Seed the cache with the household the server just handed us, then
      // refresh. Seeding first means the new household is present even if the
      // refetch fails — no screen should land on "no household" for one that
      // demonstrably exists.
      await refreshCachedGroups(ref, ensure: group);
      if (!mounted) return;
      Navigator.of(context).pop(group);
      final l10n = AppLocalizations.of(context)!;
      AppToast.success(context, l10n.createHouseholdCreated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      AppToast.error(
          context, friendlyErrorMessage(e, AppLocalizations.of(context)!));
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: l10n.sheetCreateHouseholdName,
          hint: l10n.sheetCreateHouseholdNameHint,
          controller: _nameController,
          textInputAction: TextInputAction.next,
          maxLength: 80,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: l10n.createHouseholdDescriptionOptional,
          hint: l10n.sheetGroupSettingsDescriptionHint,
          controller: _descriptionController,
          textInputAction: TextInputAction.done,
          maxLength: 300,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCurrencyDropdown(
          value: _currency,
          onChanged: (v) {
            if (v != null) setState(() => _currency = v);
          },
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isCreating
                ? l10n.recipeCreationCreating
                : l10n.groupsCreateHousehold,
            isLoading: _isCreating,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
