import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/outbox_provider.dart';
import '../storage/app_database.dart';
import '../theme/spacing.dart';
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
              ref
                  .read(outboxCoordinatorProvider)
                  .valueOrNull
                  ?.retryFailed();
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

    return AppCard(
      variant: AppCardVariant.soft,
      tint: AppCardTint.warning,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_label(l10nChild, op), style: theme.textTheme.bodyMedium),
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

  /// Human-readable summary of what the op was trying to do, using the entity
  /// name from the payload when available.
  static String _label(AppLocalizations l10n, OutboxOp op) {
    final verb = switch (op.type) {
      'createItem' => l10n.sheetFailedChangesOpAddItem,
      'updateItem' => l10n.sheetFailedChangesOpUpdateItem,
      'deleteItem' => l10n.sheetFailedChangesOpDeleteItem,
      'reorderItems' => l10n.sheetFailedChangesOpReorderItems,
      'createExpense' => l10n.sheetFailedChangesOpCreateExpense,
      'updateExpense' => l10n.sheetFailedChangesOpUpdateExpense,
      'deleteExpense' => l10n.sheetFailedChangesOpDeleteExpense,
      'createRecipe' => l10n.sheetFailedChangesOpCreateRecipe,
      'updateRecipe' => l10n.sheetFailedChangesOpUpdateRecipe,
      'deleteRecipe' => l10n.sheetFailedChangesOpDeleteRecipe,
      'completeChore' => l10n.sheetFailedChangesOpCompleteChore,
      'skipChore' => l10n.sheetFailedChangesOpSkipChore,
      'rescheduleChore' => l10n.sheetFailedChangesOpRescheduleChore,
      'undoChore' => l10n.sheetFailedChangesOpUndoChore,
      'createPinwallPost' => l10n.sheetFailedChangesOpCreatePinwallPost,
      'deletePinwallPost' => l10n.sheetFailedChangesOpDeletePinwallPost,
      _ => l10n.sheetFailedChangesOpChange,
    };
    final name = _payloadName(op.payloadJson);
    return name == null ? verb : '$verb — $name';
  }

  static String? _payloadName(String payloadJson) {
    try {
      final map = (jsonDecode(payloadJson) as Map).cast<String, dynamic>();
      final name = map['name'] ?? map['content'] ?? map['title'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
    } catch (_) {
      // Best-effort label only.
    }
    return null;
  }
}
