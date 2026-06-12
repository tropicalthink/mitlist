import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/store_provider.dart';
import '../theme/spacing.dart';
import 'app_bottom_sheet.dart';
import 'app_icon.dart';

/// Lets the household choose which store they're shopping at. The choice drives
/// shopping-path aisle sorting and is persisted on-device.
Future<void> showStorePicker(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Your store',
    body: const _StorePickerBody(),
  );
}

class _StorePickerBody extends ConsumerWidget {
  const _StorePickerBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(storeCatalogProvider);
    final selected = ref.watch(selectedStoreIdProvider);
    final notifier = ref.read(selectedStoreIdProvider.notifier);

    return catalog.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(MitlistSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(MitlistSpacing.lg),
        child: Text('Couldn’t load stores.'),
      ),
      data: (stores) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StoreTile(
              label: 'No store',
              subtitle: 'Sort by category instead of a store layout',
              selected: selected == null,
              onTap: () {
                notifier.select(null);
                Navigator.of(context).maybePop();
              },
            ),
            const Divider(height: 1),
            for (final s in stores)
              _StoreTile(
                label: s.name,
                subtitle: s.country,
                selected: s.id == selected,
                onTap: () {
                  notifier.select(s.id);
                  Navigator.of(context).maybePop();
                },
              ),
          ],
        );
      },
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: selected
          ? AppIcon(name: 'check', color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
