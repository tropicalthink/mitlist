import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/grocery_provider.dart';
import '../../services/restock_service.dart';
import '../../theme/spacing.dart';
import 'list_suggestion_line.dart';

/// What the household will probably need soon, as up to [maxLines] faint
/// lines at the end of a shopping list under a quiet "You might also need".
/// Each says why ("Due again · 6d ago"); tapping one adds it, swiping one
/// away hides it until it would be due again.
///
/// Renders nothing while loading, on error, or when nothing is left after
/// dropping what the list already has and what was swiped away: no spinners
/// or error UI, so it never clutters the list.
class RunningLowLines extends ConsumerStatefulWidget {
  const RunningLowLines({
    super.key,
    required this.groupId,
    required this.currentItemNames,
    this.currentCanonicalIds = const {},
    required this.onAdd,
    this.maxLines = 3,
  });

  /// The household group whose purchase history the predictor reads.
  final String groupId;

  /// Lowercased names of items already on the open list.
  final Set<String> currentItemNames;

  /// Canonical items already on the open list. A row typed as "Milch" and a
  /// suggestion named "Whole milk" share an item even though the names differ.
  final Set<String> currentCanonicalIds;

  /// The screen writes the item through the offline-first path.
  final void Function(RestockSuggestion suggestion) onAdd;
  final int maxLines;

  @override
  ConsumerState<RunningLowLines> createState() => _RunningLowLinesState();
}

/// Swiped-away suggestions, per household: canonical id → when.
String _dismissedKey(String groupId) => 'restock_dismissed:$groupId';

class _RunningLowLinesState extends ConsumerState<RunningLowLines> {
  Map<String, DateTime> _dismissed = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadDismissed());
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_dismissedKey(widget.groupId)) ?? [];
      final parsed = <String, DateTime>{};
      for (final entry in raw) {
        final split = entry.lastIndexOf('|');
        if (split <= 0) continue;
        final at = int.tryParse(entry.substring(split + 1));
        if (at == null) continue;
        parsed[entry.substring(0, split)] =
            DateTime.fromMillisecondsSinceEpoch(at);
      }
      if (mounted) setState(() => _dismissed = parsed);
    } catch (_) {}
  }

  Future<void> _dismiss(RestockSuggestion suggestion) async {
    final now = DateTime.now();
    setState(() {
      _dismissed = {..._dismissed, suggestion.canonicalItemId: now};
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_dismissedKey(widget.groupId), [
        for (final e in _dismissed.entries)
          '${e.key}|${e.value.millisecondsSinceEpoch}',
      ]);
    } catch (_) {}
  }

  /// Swiped away less than one buying cycle ago (at least a few days).
  bool _isDismissed(RestockSuggestion s) {
    final at = _dismissed[s.canonicalItemId];
    if (at == null) return false;
    final quiet = Duration(days: s.intervalDays < 3 ? 3 : s.intervalDays);
    return DateTime.now().difference(at) < quiet;
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(runningLowProvider(widget.groupId));
    final suggestions = asyncValue.valueOrNull;
    if (suggestions == null) return const SizedBox.shrink();
    final shown = suggestions
        .where((s) =>
            !widget.currentItemNames.contains(s.name.toLowerCase()) &&
            !widget.currentCanonicalIds.contains(s.canonicalItemId) &&
            !_isDismissed(s))
        .take(widget.maxLines)
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: MitlistSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              0,
              MitlistSpacing.md,
              MitlistSpacing.xs,
            ),
            child: Text(
              l10n.scanReviewYouMightNeed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final s in shown)
            Dismissible(
              key: ValueKey('restock-${s.canonicalItemId}'),
              onDismissed: (_) => unawaited(_dismiss(s)),
              child: ListSuggestionLine(
                name: s.name,
                detail: _detail(l10n, s),
                semanticLabel: '${s.name}. ${_detail(l10n, s)}',
                onTap: () => widget.onAdd(s),
              ),
            ),
        ],
      ),
    );
  }

  String _detail(AppLocalizations l10n, RestockSuggestion s) {
    final reason = switch (s.reason) {
      RestockReason.due => l10n.restockReasonDue,
      RestockReason.usual => l10n.restockReasonUsual,
      RestockReason.goesWith => l10n.restockReasonGoesWith,
    };
    return '$reason · ${l10n.runningLowDaysAgo(s.daysSince)}';
  }
}
