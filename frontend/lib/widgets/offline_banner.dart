import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/outbox_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon, message) = switch (state.status) {
      OutboxStatus.offline => (
          MitlistColors.warning500,
          Icons.cloud_off,
          'Offline — changes will sync when you reconnect',
        ),
      OutboxStatus.syncing => (
          MitlistColors.primary500,
          Icons.sync,
          state.pendingCount > 1
              ? 'Syncing ${state.pendingCount} changes…'
              : 'Syncing changes…',
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
        onTap: state.hasErrors ? () => _retry(ref) : null,
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
                  Text(
                    'Retry',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: MitlistSpacing.xs),
                  const Icon(Icons.refresh, size: 14, color: Colors.white),
                ],
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
