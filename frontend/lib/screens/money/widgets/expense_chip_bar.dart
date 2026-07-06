import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/spacing.dart';
import '../../../widgets/chip.dart';

/// The Timeline / Settlements tab switcher.
class ExpenseChipBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const ExpenseChipBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: MitlistSpacing.sm,
      runSpacing: MitlistSpacing.sm,
      children: [
        AppChip(
          label: l10n.expenseTabTimeline,
          selected: selectedTab == 0,
          onSelected: (_) => onTabChanged(0),
        ),
        AppChip(
          label: l10n.expenseTabSettlements,
          selected: selectedTab == 1,
          onSelected: (_) => onTabChanged(1),
        ),
      ],
    );
  }
}
