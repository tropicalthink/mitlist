import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';

class SettlementConfirmationDialog extends StatelessWidget {
  const SettlementConfirmationDialog({
    super.key,
    required this.amount,
    required this.payer,
    required this.payee,
  });

  final String amount;
  final String payer;
  final String payee;

  static Future<bool?> show({
    required BuildContext context,
    required String amount,
    required String payer,
    required String payee,
  }) async {
    return showAppDialog<bool>(
      context: context,
      title: 'Confirm Payment',
      body: SettlementConfirmationDialog(
        amount: amount,
        payer: payer,
        payee: payee,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(
          amount,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        if (payer == 'You')
          Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.sm),
            child: Text(
              'You\u2019ll pay $payee $amount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else if (payee == 'You')
          Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.sm),
            child: Text(
              '$payer will pay you $amount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.sm),
            child: Text(
              '$payer pays $payee $amount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          children: [
            Expanded(
              child: _PartyBlock(label: 'From', name: payer),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Icon(
              Icons.arrow_forward,
              size: MitlistSpacing.space5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: _PartyBlock(label: 'To', name: payee),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: 'Cancel',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.success,
                size: AppButtonSize.lg,
                text: 'Confirm',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PartyBlock extends StatelessWidget {
  const _PartyBlock({required this.label, required this.name});

  final String label;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
