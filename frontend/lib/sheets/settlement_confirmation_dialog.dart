import 'package:flutter/material.dart';

import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_icon.dart';

class SettlementConfirmationDialog extends StatefulWidget {
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
      title: 'Confirm payment',
      body: SettlementConfirmationDialog(
        amount: amount,
        payer: payer,
        payee: payee,
      ),
    );
  }

  @override
  State<SettlementConfirmationDialog> createState() =>
      _SettlementConfirmationDialogState();
}

class _SettlementConfirmationDialogState
    extends State<SettlementConfirmationDialog> {
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final amount = widget.amount;
    final payer = widget.payer;
    final payee = widget.payee;

    String description;
    if (payer == payee) {
      description = '$payer already settled';
    } else if (payer == 'You') {
      description = 'You\u2019ll pay $payee $amount';
    } else if (payee == 'You') {
      description = '$payer will pay you $amount';
    } else {
      description = '$payer pays $payee $amount';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        Padding(
          padding: const EdgeInsets.only(top: MitlistSpacing.sm),
          child: Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
            AppIcon(
              name: 'arrowRight',
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
                onPressed: _isConfirming
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.success,
                size: AppButtonSize.lg,
                text: _isConfirming ? 'Confirming...' : 'Confirm',
                isLoading: _isConfirming,
                onPressed: _isConfirming || payer == payee
                    ? null
                    : () {
                        setState(() => _isConfirming = true);
                        Navigator.of(context).pop(true);
                      },
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
          label,
          style: MitlistTypography.labelXSmall(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
