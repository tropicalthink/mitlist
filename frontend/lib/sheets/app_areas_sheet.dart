import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_areas_provider.dart';
import '../router.dart' show forgetLastShellTabIf;
import '../theme/spacing.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';

/// The label for [area] in the bottom bar.
String appAreaLabel(AppLocalizations l10n, AppArea area) => switch (area) {
      AppArea.chores => l10n.navChores,
      AppArea.kitchen => l10n.navKitchen,
      AppArea.money => l10n.navMoney,
      AppArea.lists => l10n.navLists,
    };

/// "Lists, Money": the areas this person chose, for the You row.
String appAreasSummary(AppLocalizations l10n, AppAreasState state) {
  final chosen = state.chosen;
  if (chosen == null || chosen.length == AppArea.values.length) {
    return l10n.appAreasAll;
  }
  return [
    for (final a in AppArea.values)
      if (chosen.contains(a)) appAreaLabel(l10n, a),
  ].join(', ');
}

/// Turns parts of mitlist on and off for this person. Nothing is deleted:
/// a hidden area keeps its data, and it comes back on its own when the
/// household puts something on you there.
Future<void> showAppAreasSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<void>(
    context: context,
    title: l10n.appAreasTitle,
    body: Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(appAreasProvider);
        final chosen = state.chosen ?? AppArea.values.toSet();
        final textTheme = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.appAreasBody,
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            for (final area in AppArea.values)
              MergeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        appAreaLabel(l10n, area),
                        style: textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Switch.adaptive(
                      key: ValueKey('app-area-${area.name}'),
                      value: chosen.contains(area),
                      onChanged: (on) {
                        unawaited(Haptics.light());
                        unawaited(ref
                            .read(appAreasProvider.notifier)
                            .setShown(area, on));
                        if (!on) unawaited(forgetLastShellTabIf(area));
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
