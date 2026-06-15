import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return showAppBottomSheet(
    context: context,
    title: 'Failed changes',
    body: const _FailedChangesBody(),
  );
}

class _FailedChangesBody extends ConsumerWidget {
  const _FailedChangesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(failedOutboxOpsProvider);
    final ops = opsAsync.valueOrNull ?? const <OutboxOp>[];

    if (ops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.lg),
        child: Text(
          'No failed changes. Everything is synced or waiting to retry.',
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
              'These changes couldn’t be saved to the server. Retry to send '
              'them again, or discard to drop them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...ops.map((op) => Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: _FailedOpCard(op: op),
              )),
          const SizedBox(height: MitlistSpacing.xs),
          AppButton(
            text: 'Retry all',
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
    final theme = Theme.of(context);
    final coordinator = ref.read(outboxCoordinatorProvider).valueOrNull;

    return AppCard(
      variant: AppCardVariant.soft,
      tint: AppCardTint.warning,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_label(op), style: theme.textTheme.bodyMedium),
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
                  text: 'Retry',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.outline,
                  onPressed: () => coordinator?.retryOp(op.id),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: AppButton(
                  text: 'Discard',
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
  static String _label(OutboxOp op) {
    final verb = switch (op.type) {
      'createItem' => 'Add item',
      'updateItem' => 'Update item',
      'deleteItem' => 'Delete item',
      'reorderItems' => 'Reorder list',
      'createExpense' => 'Add expense',
      'updateExpense' => 'Update expense',
      'deleteExpense' => 'Delete expense',
      'createRecipe' => 'Add recipe',
      'updateRecipe' => 'Update recipe',
      'deleteRecipe' => 'Delete recipe',
      'completeChore' => 'Complete chore',
      'skipChore' => 'Skip chore',
      'rescheduleChore' => 'Reschedule chore',
      'undoChore' => 'Undo chore',
      'createPinwallPost' => 'Post to pinwall',
      'deletePinwallPost' => 'Delete pinwall post',
      _ => 'Change',
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
