import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/initial_sync_provider.dart';
import '../providers/outbox_provider.dart';
import '../router.dart';
import '../sheets/conflict_resolution_sheet.dart';
import '../screens/you/feature_board_widgets.dart' show featureBoardRelativeTime;
import '../sheets/failed_changes_sheet.dart';
import '../storage/app_database.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/outbox_op_label.dart';
import 'app_card.dart';
import 'app_bottom_sheet.dart';

/// A small banner that shows offline, syncing, or sync-error states.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(outboxStateProvider);
    final initialSync = ref.watch(initialSyncProvider);

    return stateAsync.when(
      data: (state) {
        if (state.status == OutboxStatus.online) {
          // Outbox is quiet — give the bar to the cold-start refresh, so a
          // launch on stale cache is visibly syncing (or visibly failed).
          return switch (initialSync) {
            InitialSyncStatus.syncing =>
              const _InitialSyncBanner(failed: false),
            InitialSyncStatus.failed => const _InitialSyncBanner(failed: true),
            _ => const SizedBox.shrink(),
          };
        }
        return _Banner(state: state);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Banner extends ConsumerWidget {
  final OutboxState state;

  const _Banner({required this.state});

  /// Whether a sheet opened from the banner is still up. The banner sits
  /// above the Navigator, so a modal barrier never covers it and every extra
  /// tap while a sheet is open would stack another one on top. One banner
  /// exists per app, so a class-level flag is enough to serialise them.
  static bool _sheetOpen = false;

  /// Runs [open] unless a banner sheet is already showing, and clears the
  /// guard once that sheet has been dismissed.
  static Future<void> _openOnce(Future<void> Function() open) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      await open();
    } finally {
      _sheetOpen = false;
    }
  }

  /// Tapping the banner is an explicit "check again" gesture, so honour it with
  /// a fresh probe instead of letting the cached verdict stand until its TTL
  /// expires. Fire-and-forget: the banner repaints when the re-run state lands.
  void _recheck(WidgetRef ref) {
    unawaited(
      ref
          .read(connectivityServiceProvider)
          .isOnline(forceProbe: true)
          .then((_) => ref.invalidate(outboxStateProvider)),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return showAppBottomSheet<void>(
      context: context,
      title: l10n.offlineBannerTitle,
      body: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _detailRow(context, Icons.cloud_off,
                l10n.offlineBannerStatusOffline, state.isOffline, colorScheme),
            _detailRow(context, Icons.sync, l10n.offlineBannerStatusPending,
                state.pendingCount, colorScheme),
            _detailRow(context, Icons.sync_problem,
                l10n.offlineBannerStatusFailed, state.failedCount, colorScheme),
            const SizedBox(height: MitlistSpacing.md),
            const _PendingOpsSection(),
            const SizedBox(height: MitlistSpacing.md),
            if (state.hasErrors)
              AppCard(
                variant: AppCardVariant.soft,
                tint: AppCardTint.warning,
                padding: AppCardPadding.md,
                child: Text(
                  l10n.offlineBannerRetryHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (state.isOffline)
              AppCard(
                variant: AppCardVariant.soft,
                tint: AppCardTint.warning,
                padding: AppCardPadding.md,
                child: Text(
                  l10n.offlineBannerOfflineHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label,
      dynamic value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium)),
          if (value is bool)
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: value ? colorScheme.tertiary : colorScheme.error,
            )
          else
            Text(
              '$value',
              style: MitlistTypography.monoBody(
                  color: Theme.of(context).colorScheme.onSurface),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final (color, icon, message) = switch (state.status) {
      OutboxStatus.offline => (
          colorScheme.secondary,
          Icons.cloud_off,
          l10n.offlineBannerBarOffline,
        ),
      OutboxStatus.syncing => (
          colorScheme.primary,
          Icons.sync,
          state.pendingCount > 1
              ? l10n.offlineBannerSyncingCount(state.pendingCount)
              : l10n.offlineBannerSyncing,
        ),
      OutboxStatus.error => (
          colorScheme.error,
          Icons.sync_problem,
          state.failedCount > 1
              ? l10n.offlineBannerFailedCount(state.failedCount)
              : l10n.offlineBannerFailedOne,
        ),
      OutboxStatus.conflict => (
          colorScheme.tertiary,
          Icons.merge_type,
          state.conflictCount > 1
              ? l10n.offlineBannerConflictCount(state.conflictCount)
              : l10n.offlineBannerConflictOne,
        ),
      OutboxStatus.online => (colorScheme.onSurfaceVariant, Icons.check, ''),
    };

    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: color,
      child: InkWell(
        onTap: () {
          // The banner lives in MaterialApp.builder, above the Navigator, so
          // its own context cannot open routes — showModalBottomSheet would
          // throw "no Navigator found" and the tap would silently do nothing.
          // Borrow a context from inside the root navigator instead.
          final sheetContext = rootNavigatorKey.currentContext;
          if (sheetContext == null) return;
          if (state.hasConflicts) {
            unawaited(
                _openOnce(() => showConflictResolutionSheet(sheetContext)));
          } else if (state.hasErrors) {
            unawaited(_openOnce(() => showFailedChangesSheet(sheetContext)));
          } else {
            if (state.isOffline) _recheck(ref);
            unawaited(_openOnce(() => _showDetails(sheetContext)));
          }
        },
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
              vertical: MitlistSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: MitlistColors.textOnPrimary),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MitlistColors.textOnPrimary,
                        ),
                  ),
                ),
                if (state.hasErrors) ...[
                  GestureDetector(
                    onTap: () => _retry(ref),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MitlistSpacing.space3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.offlineBannerRetry,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: MitlistColors.textOnPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: MitlistSpacing.xs),
                          const Icon(Icons.refresh,
                              size: 14, color: MitlistColors.textOnPrimary),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: MitlistSpacing.xs),
                const Icon(Icons.chevron_right,
                    size: 14, color: MitlistColors.textOnPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retry(WidgetRef ref) {
    final coordinator = ref.read(outboxCoordinatorProvider).valueOrNull;
    coordinator?.retryFailed();
  }
}

/// The "what is syncing" list in the sync-status sheet: every still-queued
/// outbox op, oldest first, labelled by what it does ("Check off — Milk").
class _PendingOpsSection extends ConsumerWidget {
  const _PendingOpsSection();

  /// Rows rendered before collapsing the rest into an "and N more" footer.
  static const _maxRows = 50;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ops =
        ref.watch(pendingOutboxOpsProvider).valueOrNull ?? const <OutboxOp>[];
    final shown = ops.take(_maxRows).toList(growable: false);
    final hidden = ops.length - shown.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: Text(
            l10n.offlineBannerQueueHeading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (ops.isEmpty)
          Text(
            l10n.offlineBannerQueueEmpty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.none,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  _PendingOpRow(op: shown[i]),
                ],
              ],
            ),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.sm),
            child: Text(
              l10n.offlineBannerQueueMore(hidden),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _PendingOpRow extends ConsumerWidget {
  const _PendingOpRow({required this.op});

  final OutboxOp op;

  static IconData _icon(OutboxOpDomain domain) => switch (domain) {
        OutboxOpDomain.list => Icons.checklist,
        OutboxOpDomain.money => Icons.payments_outlined,
        OutboxOpDomain.chores => Icons.cleaning_services_outlined,
        OutboxOpDomain.recipes => Icons.restaurant_menu,
        OutboxOpDomain.pinboard => Icons.push_pin_outlined,
        OutboxOpDomain.telemetry => Icons.insights_outlined,
        OutboxOpDomain.other => Icons.sync,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final itemId = outboxOpItemIdForNameLookup(op);
    final itemName = itemId == null
        ? null
        : ref.watch(outboxListItemNameProvider(itemId)).valueOrNull;
    final label = outboxOpLabel(l10n, op, itemName: itemName);

    final meta = [
      featureBoardRelativeTime(l10n, op.createdAt),
      if (op.attemptCount > 0) l10n.offlineBannerQueueAttempt(op.attemptCount),
    ].join(' · ');
    final error = op.lastError?.trim();

    return Semantics(
      container: true,
      label: '$label, $meta',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MitlistSpacing.space11),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.space3,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(_icon(outboxOpDomain(op)), size: 20, color: muted),
              const SizedBox(width: MitlistSpacing.space3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    if (op.attemptCount > 0 &&
                        error != null &&
                        error.isNotEmpty)
                      Text(
                        error,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cold-start refresh bar: a quiet "refreshing" while the initial pull is
/// in flight, and a tappable retry when it failed and the cache may be stale.
class _InitialSyncBanner extends ConsumerWidget {
  const _InitialSyncBanner({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: failed ? colorScheme.error : colorScheme.primary,
      child: InkWell(
        onTap: failed
            ? () => ref.read(initialSyncProvider.notifier).retry()
            : null,
        child: Padding(
          padding: EdgeInsets.only(top: topInset),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
              vertical: MitlistSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(failed ? Icons.sync_problem : Icons.sync,
                    size: 16, color: MitlistColors.textOnPrimary),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    failed
                        ? l10n.initialSyncFailed
                        : l10n.initialSyncRefreshing,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MitlistColors.textOnPrimary,
                        ),
                  ),
                ),
                if (failed)
                  const Icon(Icons.refresh,
                      size: 14, color: MitlistColors.textOnPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
