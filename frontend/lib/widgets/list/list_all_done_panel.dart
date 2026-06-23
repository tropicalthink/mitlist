import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/spacing.dart';
import '../app_button.dart';
import '../app_icon.dart';

/// Quiet landing for a fully checked-off list: acknowledgment plus the one
/// action that actually comes next mid-errand — clear the checked items.
class ListAllDonePanel extends StatelessWidget {
  const ListAllDonePanel({super.key, required this.onClearChecked});

  final VoidCallback onClearChecked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Row(
        children: [
          AppIcon(name: 'checkCircle', size: 20, color: colorScheme.primary),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              l10n.listDetailAllCheckedOff,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppButton(
            text: l10n.listDetailClearChecked,
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            onPressed: onClearChecked,
          ),
        ],
      ),
    );
  }
}
