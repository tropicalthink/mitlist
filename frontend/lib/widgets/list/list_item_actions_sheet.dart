import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../theme/spacing.dart';
import '../app_bottom_sheet.dart';
import '../app_icon.dart';

/// Long-press item actions. Editing (rename, quantity, note) lives here so a
/// row is fully editable without gestures; delete is duplicated from the
/// swipe-to-dismiss gesture so screen-reader and keyboard users have a
/// non-gesture path to it (swipe stays as the fast path).
enum ListItemAction {
  rename,
  quantity,
  note,
  viewPhoto,
  photo,
  removePhoto,
  price,
  delete,
}

class ListItemActionsSheet {
  ListItemActionsSheet._();

  static Future<ListItemAction?> show(
    BuildContext context, {
    required ListItem item,
    required bool hasPhoto,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return showAppBottomSheet<ListItemAction>(
      context: context,
      title: item.name,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const AppIcon(name: 'pencil'),
            title: Text(l10n.commonRename),
            onTap: () => Navigator.of(context).pop(ListItemAction.rename),
          ),
          ListTile(
            leading: const AppIcon(name: 'tune'),
            title: Text(l10n.listItemChangeQuantity),
            onTap: () => Navigator.of(context).pop(ListItemAction.quantity),
          ),
          ListTile(
            leading: const AppIcon(name: 'editNote'),
            title: Text(
              item.note.isEmpty ? l10n.listItemAddNote : l10n.listItemEditNote,
            ),
            onTap: () => Navigator.of(context).pop(ListItemAction.note),
          ),
          ListTile(
            leading: const AppIcon(name: 'banknotes'),
            title: Text(l10n.listItemSetPrice),
            onTap: () => Navigator.of(context).pop(ListItemAction.price),
          ),
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
          const Divider(),
          ListTile(
            leading: AppIcon(name: 'trash', color: colorScheme.error),
            title: Text(
              l10n.commonDelete,
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop(ListItemAction.delete),
          ),
          const SizedBox(height: MitlistSpacing.sm),
        ],
      ),
    );
  }
}
