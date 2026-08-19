import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/list_models.dart';
import '../../providers/outbox_provider.dart';
import 'list_item_row.dart';

/// Wraps [ListItemRow] in a [ConsumerWidget] that watches
/// `failedEntityIdsProvider`, so a change to an item's sync state only rebuilds
/// the affected row rather than the entire list screen.
class ListItemRowReactive extends ConsumerWidget {
  const ListItemRowReactive({
    super.key,
    required this.item,
    required this.currencySymbol,
    required this.onToggle,
    required this.onLongPress,
    this.onTap,
    this.photoUrl,
    this.claimedLabel,
    this.onPhotoTap,
    this.reorderIndex,
    this.shoppingVisual = false,
    this.groceryCategory,
  });

  final ListItem item;
  final String? photoUrl;
  final String currencySymbol;
  final String? claimedLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onPhotoTap;
  final VoidCallback onLongPress;
  final int? reorderIndex;
  final bool shoppingVisual;
  final String? groceryCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedToSync = ref.watch(failedEntityIdsProvider).contains(item.id);
    return ListItemRow(
      item: item,
      photoUrl: photoUrl,
      currencySymbol: currencySymbol,
      claimedLabel: claimedLabel,
      onToggle: onToggle,
      onTap: onTap,
      onPhotoTap: onPhotoTap,
      onLongPress: onLongPress,
      reorderIndex: reorderIndex,
      failedToSync: failedToSync,
      shoppingVisual: shoppingVisual,
      groceryCategory: groceryCategory,
    );
  }
}
