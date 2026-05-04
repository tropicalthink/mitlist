import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/outbox_provider.dart';
import '../sheets/conflict_resolution_sheet.dart';
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
    showAppBottomSheet(
      context: context,
      title: 'Sync Status',
      body: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _detailRow(Icons.cloud_off, 'Offline', state.isOffline),
            _detailRow(Icons.sync, 'Pending sync', state.pendingCount),
            _detailRow(Icons.sync_problem, 'Failed', state.failedCount),
            const SizedBox(height: MitlistSpacing.md),
            if (state.hasErrors)
              AppCard(
                variant: AppCardVariant.soft,
                tint: AppCardTint.warning,
                padding: AppCardPadding.md,
                child: const Text(
                  'Changes will be retried automatically when connectivity is restored.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            if (state.isOffline)
              AppCard(
                variant: AppCardVariant.soft,
                tint: AppCardTint.warning,
                padding: AppCardPadding.md,
                child: const Text(
                  'You can keep making changes offline. Everything will sync when you reconnect.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: MitlistColors.textSecondary),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (value is bool)
            Icon(
              value ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: value ? MitlistColors.success500 : MitlistColors.error500,
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
    final (color, icon, message) = switch (state.status) {
      OutboxStatus.conflict => (
          MitlistColors.warning500,
          Icons.warning_amber_rounded,
          state.conflictCount > 1
              ? '${state.conflictCount} conflicts need resolution'
              : '1 conflict needs resolution',
        ),
      OutboxStatus.offline => (
          MitlistColors.warning500,
          Icons.cloud_off,
          'Offline \u2014 changes will sync when you reconnect',
        ),
      OutboxStatus.syncing => (
          MitlistColors.primary500,
          Icons.sync,
          state.pendingCount > 1
              ? 'Syncing ${state.pendingCount} changes\u2026'
              : 'Syncing changes\u2026',
        ),
      OutboxStatus.error => (
          MitlistColors.error500,
          Icons.sync_problem,
          state.failedCount > 1
              ? 'Couldn\u2019t sync ${state.failedCount} changes'
              : 'Couldn\u2019t sync a change',
        ),
      OutboxStatus.online => (MitlistColors.neutral500, Icons.check, ''),
    };

    return Material(
      color: color,
      child: InkWell(
        onTap: () {
          if (state.hasConflicts) {
            ConflictResolutionSheet.show(context);
          } else {
            _showDetails(context);
          }
        },
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
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
                if (state.hasErrors) ...[
                  GestureDetector(
                    onTap: () => _retry(ref),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Retry',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: MitlistSpacing.xs),
                        const Icon(Icons.refresh,
                            size: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: MitlistSpacing.xs),
                const Icon(Icons.chevron_right,
                    size: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retry(WidgetRef ref) {
    final coordinator = ref.read(outboxCoordinatorProvider).valueOrNull;
    coordinator?.drain();
  }
}
