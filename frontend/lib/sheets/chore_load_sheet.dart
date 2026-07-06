import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/chore_models.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';

/// Shows how chore completions are split across the household over a window.
/// Every known member appears, including those at zero, so an uneven load is
/// obvious rather than hidden.
class ChoreLoadSheet extends StatelessWidget {
  final List<ChoreLoadEntry> entries;
  final Map<String, String> memberNames;
  final int days;
  final String? myUserId;

  const ChoreLoadSheet({
    super.key,
    required this.entries,
    required this.memberNames,
    this.days = 30,
    this.myUserId,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ChoreLoadEntry> entries,
    required Map<String, String> memberNames,
    int days = 30,
    String? myUserId,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context)!.choreLoadTitle,
      body: ChoreLoadSheet(
        entries: entries,
        memberNames: memberNames,
        days: days,
        myUserId: myUserId,
      ),
    );
  }

  String _nameFor(String userId) {
    final name = memberNames[userId];
    if (name != null && name.isNotEmpty) return name;
    return userId.length <= 8 ? userId : userId.substring(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Merge so every known member shows, including those who've done nothing.
    final counts = <String, int>{
      for (final id in memberNames.keys) id: 0,
    };
    for (final e in entries) {
      counts[e.userId] = e.completedCount;
    }
    final rows = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0
            ? byCount
            : _nameFor(a.key).compareTo(_nameFor(b.key));
      });

    final total = rows.fold<int>(0, (sum, r) => sum + r.value);
    final maxCount = rows.isEmpty ? 0 : rows.first.value;

    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.lg),
        child: Text(
          l10n.choreLoadEmpty(days),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.choreLoadSummary(total, days),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        for (final row in rows) ...[
          _LoadBar(
            name: _nameFor(row.key),
            count: row.value,
            maxCount: maxCount,
            share: total == 0 ? 0 : row.value / total,
            isMe: row.key == myUserId,
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
      ],
    );
  }
}

class _LoadBar extends StatelessWidget {
  final String name;
  final int count;
  final int maxCount;
  final double share;

  /// Your own bar carries the brand color; everyone else's stays neutral so
  /// your share is readable at a glance.
  final bool isMe;

  const _LoadBar({
    required this.name,
    required this.count,
    required this.maxCount,
    required this.share,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    final isIdle = count == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: isMe ? FontWeight.w700 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Text(
              '$count · ${(share * 100).round()}%',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Container(
          height: MitlistSpacing.sm,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(color: colorScheme.outlineVariant, width: 1),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: isIdle ? 0 : fraction.clamp(0.02, 1.0),
            child: Container(
              color: isMe ? colorScheme.primary : colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
