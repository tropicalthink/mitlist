import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/outbox_provider.dart';
import '../sheets/conflict_resolution_sheet.dart';
import '../sheets/failed_changes_sheet.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'app_bottom_sheet.dart';

/// A small banner that shows offline, syncing, or sync-error states.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(outboxStateProvider);

    return stateAsync.when(
      data: (state) {
        if (state.status == OutboxStatus.online) {
          return const SizedBox.shrink();
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

  void _showDetails(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showAppBottomSheet(
      context: context,
      title: 'Sync Status',
      body: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _detailRow(context, Icons.cloud_off, 'Offline', state.isOffline, colorScheme),
            _detailRow(context, Icons.sync, 'Pending sync', state.pendingCount, colorScheme),
            _detailRow(context, Icons.sync_problem, 'Failed', state.failedCount, colorScheme),
            const SizedBox(height: MitlistSpacing.md),
            if (state.hasErrors)
              AppCard(
                variant: AppCardVariant.soft,
                tint: AppCardTint.warning,
                padding: AppCardPadding.md,
                child: Text(
                  'Changes will be retried automatically when connectivity is restored.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (state.isOffline)
              AppCard(
                variant: AppCardVariant.soft,
                tint: AppCardTint.warning,
                padding: AppCardPadding.md,
                child: Text(
                  'You can keep making changes offline. Everything will sync when you reconnect.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String label, dynamic value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium)),
          if (value is bool)
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: value ? colorScheme.tertiary : colorScheme.error,
            )
          else
            Text(
              '$value',
              style: MitlistTypography.monoBody(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final (color, icon, message) = switch (state.status) {
      OutboxStatus.offline => (
          colorScheme.secondary,
          Icons.cloud_off,
          'Offline \u2014 changes will sync when you reconnect',
        ),
      OutboxStatus.syncing => (
          colorScheme.primary,
          Icons.sync,
          state.pendingCount > 1
              ? 'Syncing ${state.pendingCount} changes\u2026'
              : 'Syncing changes\u2026',
        ),
      OutboxStatus.error => (
          colorScheme.error,
          Icons.sync_problem,
          state.failedCount > 1
              ? 'Couldn\u2019t sync ${state.failedCount} changes'
              : 'Couldn\u2019t sync a change',
        ),
      OutboxStatus.conflict => (
          colorScheme.tertiary,
          Icons.merge_type,
          state.conflictCount > 1
              ? '${state.conflictCount} changes need your review'
              : 'A change needs your review',
        ),
      OutboxStatus.online => (colorScheme.onSurfaceVariant, Icons.check, ''),
    };

    return Material(
      color: color,
      child: InkWell(
        onTap: () => state.hasConflicts
            ? showConflictResolutionSheet(context)
            : state.hasErrors
                ? showFailedChangesSheet(context)
                : _showDetails(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: SafeArea(
            top: false,
            bottom: false,
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
                            'Retry',
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
