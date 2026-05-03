import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../app_button.dart';

Future<void> showQuickAddSheet(BuildContext context) async {
  Haptics.light();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick add',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: MitlistSpacing.md),
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
        ),
      );
    },
  );
}
