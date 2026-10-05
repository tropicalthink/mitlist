import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../screens/lists/list_detail_screen.dart' show ListDetailRouteArgs;
import '../../sheets/create_list_sheet.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../theme/spacing.dart';
import '../app_bottom_sheet.dart';
import '../app_icon.dart';

// Create actions shared by the hub's quick-start checklist, Quick add and the
// empty states, so every entry point opens the same sheet and lands in the
// same place.

/// Opens the create sheet and, when a list actually comes back, lands the user
/// in it with the composer focused — the job is "put something on a list", so
/// stopping at a closed sheet left it half done.
///
/// The created list is in the local cache before the sheet closes, so
/// DB-backed watchers (the checklist tick, the hub stats) update on their own.
Future<void> createListAndOpen(
  BuildContext context, {
  String? initialGroupId,
  String? initialName,
  String? initialType,
}) async {
  final created = await CreateListSheet.show(
    context,
    initialGroupId: initialGroupId,
    initialName: initialName,
    initialType: initialType,
  );
  if (created == null || !context.mounted) return;
  await openListComposer(context, created);
}

/// Opens [list] with the item composer focused.
Future<void> openListComposer(BuildContext context, ItemList list) async {
  await context.pushNamed(
    'listDetail',
    pathParameters: {'listId': list.id},
    extra: ListDetailRouteArgs(listName: list.name, autoFocusComposer: true),
  );
}

/// "Add to a list": straight into the household's only list, a picker when
/// there are several, the create sheet when there are none.
Future<void> addToAList(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
}) async {
  final lists = (await ref.read(cachedListsByGroupProvider(groupId).future))
      .where((l) => !l.isArchived)
      .toList();
  if (!context.mounted) return;

  if (lists.isEmpty) {
    await createListAndOpen(context);
    return;
  }
  if (lists.length == 1) {
    await openListComposer(context, lists.single);
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  // Sentinel for the "New list" row; list ids are UUIDs, so it cannot clash.
  const newList = '';
  final picked = await showAppBottomSheet<String>(
    context: context,
    title: l10n.scanReviewAddToWhichList,
    body: Builder(
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final list in lists)
            ListTile(
              leading: const AppIcon(name: 'listBullet'),
              title: Text(
                list.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(sheetContext).pop(list.id),
            ),
          const SizedBox(height: MitlistSpacing.sm),
          ListTile(
            leading: const AppIcon(name: 'plus'),
            title: Text(l10n.hubQuickAddList),
            onTap: () => Navigator.of(sheetContext).pop(newList),
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  if (picked == newList) {
    await createListAndOpen(context);
    return;
  }
  final list = lists.where((l) => l.id == picked).firstOrNull;
  if (list != null) await openListComposer(context, list);
}

/// Opens the expense sheet. One expense from a hub shortcut is a complete
/// entry session, so its household notification goes out right away instead
/// of waiting for the fallback window.
Future<void> addExpenseAndNotify(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
}) async {
  final created = await ExpenseCreationSheet.show(context);
  if (created != true) return;
  final service = await ref.read(financeServiceProviderAsync.future);
  unawaited(service.flushExpenseNotifications(groupId));
}
