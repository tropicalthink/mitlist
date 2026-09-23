import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/outbox_provider.dart';
import '../storage/app_database.dart';
import '../theme/spacing.dart';
import '../utils/outbox_op_label.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_bottom_sheet.dart';

/// Shows the failed-changes review surface: every dead-lettered outbox op with
/// its error, and per-change Retry / Discard actions. This is the dead-letter
/// review the banner's count used to promise but never delivered.
Future<void> showFailedChangesSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet(
    context: context,
    title: l10n.sheetFailedChangesTitle,
    body: const _FailedChangesBody(),
  );
}

class _FailedChangesBody extends ConsumerWidget {
  const _FailedChangesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final opsAsync = ref.watch(failedOutboxOpsProvider);
    final ops = opsAsync.valueOrNull ?? const <OutboxOp>[];

    if (ops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.lg),
        child: Text(
          l10n.sheetFailedChangesEmpty,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Text(
              l10n.sheetFailedChangesDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...ops.map((op) => Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: _FailedOpCard(op: op),
              )),
          const SizedBox(height: MitlistSpacing.xs),
          AppButton(
            text: l10n.sheetFailedChangesRetryAll,
            icon: const Icon(Icons.refresh, size: 16),
            variant: AppButtonVariant.soft,
            onPressed: () {
              ref.read(outboxCoordinatorProvider).valueOrNull?.retryFailed();
            },
          ),
        ],
      ),
    );
  }
}

class _FailedOpCard extends ConsumerWidget {
  final OutboxOp op;
  const _FailedOpCard({required this.op});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10nChild = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final coordinator = ref.read(outboxCoordinatorProvider).valueOrNull;
    final itemId = outboxOpItemIdForNameLookup(op);
    final itemName = itemId == null
        ? null
        : ref.watch(outboxListItemNameProvider(itemId)).valueOrNull;

    return AppCard(
      variant: AppCardVariant.soft,
      tint: AppCardTint.warning,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            outboxOpLabel(l10nChild, op, itemName: itemName),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          if (op.lastError != null && op.lastError!.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              op.lastError!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: MitlistSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: l10nChild.sheetFailedChangesRetry,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.outline,
                  onPressed: () => coordinator?.retryOp(op.id),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: AppButton(
                  text: l10nChild.sheetFailedChangesDiscard,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  color: AppButtonColor.error,
                  onPressed: () => coordinator?.discardFailedOp(op.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
