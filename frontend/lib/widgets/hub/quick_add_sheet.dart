import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';

Future<void> showQuickAddSheet(BuildContext context) async {
  Haptics.light();
  await showAppBottomSheet<void>(
    context: context,
    title: 'Quick add',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          text: 'Add expense',
          onPressed: () {
            Navigator.of(context).pop();
            context.pushNamed('money');
          },
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: 'Add to a list',
          variant: AppButtonVariant.outline,
          onPressed: () {
            Navigator.of(context).pop();
            context.pushNamed('lists');
          },
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: 'Add chore',
          variant: AppButtonVariant.outline,
          onPressed: () {
            Navigator.of(context).pop();
            context.pushNamed('chores');
          },
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Divider(
          height: MitlistSpacing.lg,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        AppButton(
          text: 'Start shopping trip',
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
