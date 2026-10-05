import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../providers/list_provider.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';
import '../pinwall/pinwall_composer.dart';
import 'hub_create_actions.dart';

/// Quick add from Home. Every option creates something on the spot (its
/// creation sheet, the list composer, the note composer) instead of only
/// switching tabs.
///
/// [context] and [ref] belong to the hub, not the sheet: each action runs
/// after the sheet has closed.
Future<void> showQuickAddSheet(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
  required User? me,
}) async {
  final l10n = AppLocalizations.of(context)!;
  unawaited(Haptics.light());

  await showAppBottomSheet<void>(
    context: context,
    title: l10n.hubQuickAddTitle,
    body: Consumer(
      builder: (sheetContext, sheetRef, _) {
        void run(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          unawaited(action());
        }

        // A trip with no lists would only say there is nothing to shop for.
        final hasLists = sheetRef
                .watch(cachedListsByGroupProvider(groupId))
                .valueOrNull
                ?.any((l) => !l.isArchived) ??
            false;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              text: l10n.hubQuickAddExpense,
              onPressed: () => run(
                () => addExpenseAndNotify(context, ref, groupId: groupId),
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.hubQuickAddToList,
              variant: AppButtonVariant.outline,
              onPressed: () =>
                  run(() => addToAList(context, ref, groupId: groupId)),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.hubQuickAddChore,
              variant: AppButtonVariant.outline,
              onPressed: () => run(() => ChoreCreationSheet.show(context)),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.hubQuickAddNote,
              variant: AppButtonVariant.outline,
              onPressed: () => run(
                () => PinwallComposer.show(context, groupId: groupId, me: me),
              ),
            ),
            // On-device OCR ships on iOS and Android only.
            if (!kIsWeb) ...[
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                text: l10n.hubQuickAddScan,
                variant: AppButtonVariant.outline,
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: () => run(() => context.pushNamed('scanner')),
              ),
            ],
            if (hasLists) ...[
              Divider(
                height: MitlistSpacing.lg,
                color: Theme.of(sheetContext).colorScheme.outlineVariant,
              ),
              AppButton(
                text: l10n.hubQuickAddShoppingTrip,
                variant: AppButtonVariant.outline,
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => run(() => context.pushNamed('shoppingTrip')),
              ),
            ],
          ],
        );
      },
    ),
  );
}
