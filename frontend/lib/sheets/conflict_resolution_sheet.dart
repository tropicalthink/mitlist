import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/finance_provider.dart';
import '../providers/list_provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/outbox_provider.dart';
import '../storage/app_database.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

/// Shows unresolved edit conflicts (someone else changed an item while your
/// change was queued). Per conflict: keep your version or use theirs.
Future<void> showConflictResolutionSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet(
    context: context,
    title: l10n.sheetConflictTitle,
    body: const _ConflictBody(),
  );
}

class _ConflictBody extends ConsumerWidget {
  const _ConflictBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final conflicts = ref.watch(conflictsProvider).valueOrNull ?? const [];

    if (conflicts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.lg),
        child: Text(
          'No conflicts to resolve.',
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
              l10n.sheetConflictDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...conflicts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: _ConflictCard(conflict: c),
              )),
        ],
      ),
    );
  }
}

class _ConflictCard extends ConsumerWidget {
  final Conflict conflict;
  const _ConflictCard({required this.conflict});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final keys =
        conflict.entityType == 'updateExpense' ? _expenseKeys : _itemKeys;
    final mine = _summarize(_patchFields(conflict.localPayloadJson), keys);
    final theirs = _summarize(_fields(conflict.serverPayloadJson), keys);

    return AppCard(
      variant: AppCardVariant.soft,
      tint: AppCardTint.warning,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title(conflict), style: theme.textTheme.bodyMedium),
          const SizedBox(height: MitlistSpacing.sm),
          _versionRow(context, l10n.sheetConflictLocal, mine),
          const SizedBox(height: MitlistSpacing.xs),
          _versionRow(context, l10n.sheetConflictServer, theirs),
          const SizedBox(height: MitlistSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: l10n.sheetConflictKeepLocal,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.outline,
                  onPressed: () => _resolve(ref, keepLocal: true),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: AppButton(
                  text: l10n.sheetConflictKeepServer,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.soft,
                  onPressed: () => _resolve(ref, keepLocal: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Conflicts are keyed by the op type that produced them, so the owning
  /// repository is chosen from that rather than assumed to be lists.
  Future<void> _resolve(WidgetRef ref, {required bool keepLocal}) async {
    switch (conflict.entityType) {
      case 'updateExpense':
        final repo = await ref.read(financeRepositoryProvider.future);
        await (keepLocal
            ? repo.resolveConflictKeepLocal(conflict)
            : repo.resolveConflictAcceptServer(conflict));
      default:
        final repo = await ref.read(listRepositoryProvider.future);
        await (keepLocal
            ? repo.resolveConflictKeepLocal(conflict)
            : repo.resolveConflictAcceptServer(conflict));
    }
  }

  Widget _versionRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: theme.textTheme.labelSmall),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  static String _title(Conflict c) {
    final fields = _fields(c.serverPayloadJson);
    if (c.entityType == 'updateExpense') {
      final desc = fields['description'];
      return desc is String && desc.isNotEmpty
          ? 'Expense: $desc'
          : 'Expense changed';
    }
    final name = fields['name'];
    return name is String && name.isNotEmpty ? 'Item: $name' : 'Item changed';
  }

  /// Fields worth showing per entity — enough to tell two versions apart
  /// without dumping the whole payload.
  static const _itemKeys = [
    'name',
    'quantity',
    'unit',
    'note',
    'checked',
    'price_cents'
  ];
  static const _expenseKeys = [
    'description',
    'amount',
    'currency',
    'category',
    'notes',
    'date'
  ];

  static Map<String, dynamic> _fields(String json) {
    try {
      return (jsonDecode(json) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  /// Local op payload nests the edit under `patch`.
  static Map<String, dynamic> _patchFields(String json) {
    final map = _fields(json);
    final patch = map['patch'];
    if (patch is Map) return patch.cast<String, dynamic>();
    return map;
  }

  static String _summarize(Map<String, dynamic> fields, List<String> keys) {
    final parts = <String>[];
    for (final k in keys) {
      final v = fields[k] ?? fields[_camel(k)];
      if (v != null && '$v'.isNotEmpty) parts.add('$k: $v');
    }
    return parts.isEmpty ? '(no visible fields)' : parts.join(', ');
  }

  static String _camel(String snake) {
    final parts = snake.split('_');
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }
}
