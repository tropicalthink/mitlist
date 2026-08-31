import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/group_models.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/app_switch.dart';

/// What the cookbook form hands back: a trimmed, non-empty name and whether
/// the cookbook should be visible to the household.
class CookbookFormResult {
  final String name;
  final bool shareWithHousehold;

  const CookbookFormResult({
    required this.name,
    required this.shareWithHousehold,
  });
}

/// Create/edit form for a cookbook. [household] is the household a shared
/// cookbook lands in; null disables the share switch and says why.
Future<CookbookFormResult?> showCookbookFormSheet(
  BuildContext context, {
  required Group? household,
  String? initialName,
  bool initialShared = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final editing = initialName != null;
  return showAppBottomSheet<CookbookFormResult>(
    context: context,
    title: editing ? l10n.cookbooksEditSheetTitle : l10n.cookbooksSheetTitle,
    body: _CookbookForm(
      household: household,
      initialName: initialName,
      initialShared: initialShared,
    ),
  );
}

class _CookbookForm extends StatefulWidget {
  final Group? household;
  final String? initialName;
  final bool initialShared;

  const _CookbookForm({
    required this.household,
    required this.initialName,
    required this.initialShared,
  });

  @override
  State<_CookbookForm> createState() => _CookbookFormState();
}

class _CookbookFormState extends State<_CookbookForm> {
  late final TextEditingController _nameController;
  late bool _shareWithHousehold;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _shareWithHousehold = widget.initialShared && widget.household != null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = widget.household;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          controller: _nameController,
          label: l10n.cookbooksFieldName,
          errorText: _error,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppSwitchListTile(
          title: l10n.cookbooksShareWithHousehold,
          subtitle: household == null
              ? l10n.cookbooksNoHouseholdDesc
              : (_shareWithHousehold
                  ? l10n.cookbooksShareWithHouseholdDesc(household.name)
                  : l10n.cookbooksPersonalDesc),
          value: _shareWithHousehold,
          onChanged: household == null
              ? null
              : (value) => setState(() => _shareWithHousehold = value),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              text: l10n.commonCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            AppButton(
              text: l10n.commonSave,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.cookbooksValidationName);
      return;
    }
    Navigator.of(context).pop(CookbookFormResult(
      name: name,
      shareWithHousehold: _shareWithHousehold,
    ));
  }
}
