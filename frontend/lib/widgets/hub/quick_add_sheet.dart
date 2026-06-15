import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';

Future<void> showQuickAddSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  unawaited(Haptics.light());
  await showAppBottomSheet<void>(
    context: context,
    title: l10n.hubQuickAddTitle,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          text: l10n.hubQuickAddExpense,
          onPressed: () {
            Navigator.of(context).pop();
            context.goNamed('money');
          },
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: l10n.hubQuickAddToList,
          variant: AppButtonVariant.outline,
          onPressed: () {
            Navigator.of(context).pop();
            context.goNamed('lists');
          },
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: l10n.hubQuickAddChore,
          variant: AppButtonVariant.outline,
          onPressed: () {
            Navigator.of(context).pop();
            context.goNamed('chores');
          },
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Divider(
          height: MitlistSpacing.lg,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        AppButton(
          text: l10n.hubQuickAddShoppingTrip,
          variant: AppButtonVariant.outline,
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () {
            Navigator.of(context).pop();
            context.pushNamed('shoppingTrip');
          },
        ),
      ],
    ),
  );
}
