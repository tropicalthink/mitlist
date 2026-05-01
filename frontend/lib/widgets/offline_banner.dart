import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/outbox_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// A small banner that appears when the device is offline or has pending sync.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(_onlineProvider);

    return onlineAsync.when(
      data: (online) {
        if (online) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: MitlistColors.warning500,
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 16, color: Colors.white),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  'Offline — changes will sync when you reconnect',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

final _onlineProvider = FutureProvider<bool>((ref) async {
  final svc = ref.watch(connectivityServiceProvider);
  return svc.isOnline();
});
