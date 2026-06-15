import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/list_provider.dart';
import '../providers/outbox_provider.dart';
import '../storage/app_database.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

/// Shows unresolved edit conflicts (someone else changed an item while your
/// change was queued). Per conflict: keep your version or use theirs.
Future<void> showConflictResolutionSheet(BuildContext context) {
  return showAppBottomSheet(
    context: context,
    title: 'Resolve conflicts',
    body: const _ConflictBody(),
  );
}

class _ConflictBody extends ConsumerWidget {
  const _ConflictBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'Someone else changed these while your edit was waiting to sync. '
              'Choose which version to keep.',
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
    final theme = Theme.of(context);
    final mine = _summarize(_patchFields(conflict.localPayloadJson));
    final theirs = _summarize(_fields(conflict.serverPayloadJson));

    return AppCard(
      variant: AppCardVariant.soft,
      tint: AppCardTint.warning,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title(conflict), style: theme.textTheme.bodyMedium),
          const SizedBox(height: MitlistSpacing.sm),
          _versionRow(context, 'Your version', mine),
          const SizedBox(height: MitlistSpacing.xs),
          _versionRow(context, 'Their version', theirs),
          const SizedBox(height: MitlistSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Keep mine',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.outline,
                  onPressed: () async {
                    final repo =
                        await ref.read(listRepositoryProvider.future);
                    await repo.resolveConflictKeepLocal(conflict);
                  },
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: AppButton(
                  text: 'Use theirs',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.soft,
                  onPressed: () async {
                    final repo =
                        await ref.read(listRepositoryProvider.future);
                    await repo.resolveConflictAcceptServer(conflict);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    final name = fields['name'];
    return name is String && name.isNotEmpty ? 'Item: $name' : 'Item changed';
  }

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

  static String _summarize(Map<String, dynamic> fields) {
    const keys = ['name', 'quantity', 'unit', 'note', 'checked', 'price_cents'];
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
