import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../theme/spacing.dart';
import '../app_bottom_sheet.dart';
import '../app_icon.dart';

/// Long-press item actions: view/replace photo, remove photo, price, delete.
enum ListItemAction { viewPhoto, photo, removePhoto, price, delete }

class ListItemActionsSheet {
  ListItemActionsSheet._();

  static Future<ListItemAction?> show(
    BuildContext context, {
    required ListItem item,
    required bool hasPhoto,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<ListItemAction>(
      context: context,
      title: item.name,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPhoto)
            ListTile(
              leading: const AppIcon(name: 'eye'),
              title: Text(l10n.listItemViewPhoto),
              onTap: () =>
                  Navigator.of(context).pop(ListItemAction.viewPhoto),
            ),
          ListTile(
            leading: const AppIcon(name: 'camera'),
            title: Text(hasPhoto ? l10n.listItemReplacePhoto : l10n.listItemAddPhoto),
            onTap: () => Navigator.of(context).pop(ListItemAction.photo),
          ),
          if (hasPhoto)
            ListTile(
              leading: const AppIcon(name: 'imageNotSupportedOutline'),
              title: Text(l10n.listItemRemovePhoto),
              onTap: () =>
                  Navigator.of(context).pop(ListItemAction.removePhoto),
            ),
          ListTile(
            leading: const AppIcon(name: 'banknotes'),
            title: Text(l10n.listItemSetPrice),
            onTap: () => Navigator.of(context).pop(ListItemAction.price),
          ),
          ListTile(
            leading: AppIcon(
              name: 'trash',
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.listItemDeleteAction,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            onTap: () => Navigator.of(context).pop(ListItemAction.delete),
          ),
          const SizedBox(height: MitlistSpacing.sm),
        ],
      ),
    );
  }
}
