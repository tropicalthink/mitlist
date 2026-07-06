import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/store_provider.dart';
import '../theme/spacing.dart';
import 'app_bottom_sheet.dart';
import 'app_icon.dart';

/// Lets the household choose which store they're shopping at. The choice drives
/// shopping-path aisle sorting and is persisted on-device.
Future<void> showStorePicker(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<void>(
    context: context,
    title: l10n.storePickerTitle,
    body: const _StorePickerBody(),
  );
}

class _StorePickerBody extends ConsumerWidget {
  const _StorePickerBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(storeCatalogProvider);
    final selected = ref.watch(selectedStoreIdProvider);
    final notifier = ref.read(selectedStoreIdProvider.notifier);

    return catalog.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(MitlistSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(MitlistSpacing.lg),
        child: Text(l10n.storePickerLoadError),
      ),
      data: (stores) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StoreTile(
              label: l10n.storePickerNoStore,
              subtitle: l10n.storePickerNoStoreDesc,
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
      trailing:
          selected ? AppIcon(name: 'check', color: colorScheme.primary) : null,
      onTap: onTap,
    );
  }
}
