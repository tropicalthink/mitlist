import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_widgets_provider.dart';
import '../../providers/widget_discovery_provider.dart';
import '../../screens/you/widgets_screen.dart' show activeHouseholdName;
import '../../services/widgets/home_widget_kind.dart';
import '../../services/widgets/widget_promo.dart';
import '../../theme/spacing.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';
import '../app_icon.dart';
import '../home_widget_preview.dart';

enum WidgetPromoChoice { add, notNow }

/// Offers the home screen widgets from Home when [WidgetPromoDecision]
/// says so, and records the showing. Returns whether it was shown (Home
/// then shows nothing else this visit). [context] is Home's: nothing is shown
/// while another route (a sheet, a dialog, a pushed page) is on top of it.
///
/// [onboardingDone] is the caller's word that the person is past first run:
/// Home passes true once it has loaded a household, which is only possible
/// after sign-up and the household setup are finished.
Future<bool> maybeOfferHomeWidgets(
  BuildContext context,
  WidgetRef ref, {
  required bool onboardingDone,
}) async {
  final bridge = ref.read(widgetBridgeProvider);
  if (!bridge.isSupported || !ref.read(authStateProvider)) return false;
  final lastShownAt = await WidgetPromoStore.lastShownAt();
  List<String>? installed;
  try {
    installed = await ref.read(installedHomeWidgetsProvider.future);
  } catch (_) {
    installed = null;
  }
  final now = ref.read(widgetPromoClockProvider)();
  final show = WidgetPromoDecision.shouldShow(
    now: now,
    lastShownAt: lastShownAt,
    installedKinds: installed,
    supported: bridge.isSupported,
    onboardingDone: onboardingDone,
  );
  if (!show || !context.mounted) return false;
  // Home is on screen and on top: not under a sheet, dialog or pushed page,
  // and not a shell tab left in the background.
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
  if (!TickerMode.valuesOf(context).enabled) return false;
  // Recorded before it opens: an app killed with the sheet up has shown it.
  await WidgetPromoStore.markShown(now);
  if (!context.mounted) return true;
  await showWidgetPromoSheet(context, ref);
  return true;
}

/// The promo sheet itself; "Add" then pins the shopping list widget
/// (Android) or opens the Widgets page.
Future<void> showWidgetPromoSheet(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showAppBottomSheet<WidgetPromoChoice>(
    context: context,
    title: l10n.widgetsPageTitle,
    body: const _WidgetPromoBody(),
  );
  if (choice != WidgetPromoChoice.add || !context.mounted) return;
  await addHomeWidget(context, ref, HomeWidgetKind.shoppingList);
}

/// One tap to put [kind] on the home screen where the launcher can pin it;
/// the Widgets page with its steps everywhere else, or when pinning fails.
Future<void> addHomeWidget(
  BuildContext context,
  WidgetRef ref,
  HomeWidgetKind kind,
) async {
  if (ref.read(homeWidgetPlatformProvider) == TargetPlatform.android) {
    var canPin = false;
    try {
      canPin = await ref.read(pinWidgetSupportedProvider.future);
    } catch (_) {}
    if (canPin && await ref.read(widgetBridgeProvider).pinWidget(kind.id)) {
      return;
    }
  }
  if (context.mounted) await context.pushNamed('widgets');
}

class _WidgetPromoBody extends ConsumerWidget {
  const _WidgetPromoBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPin =
        ref.watch(homeWidgetPlatformProvider) == TargetPlatform.android &&
            (ref.watch(pinWidgetSupportedProvider).valueOrNull ?? false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(MitlistSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            border: Border.all(color: scheme.outline, width: 2),
          ),
          child: HomeWidgetPreview(
            kind: HomeWidgetKind.shoppingList,
            householdName: activeHouseholdName(ref),
          ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        Text(
          l10n.widgetPromoHeadline,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(l10n.widgetPromoBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: MitlistSpacing.lg),
        AppButton(
          key: const ValueKey('widgetPromo-add'),
          text: canPin ? l10n.widgetPromoAdd : l10n.widgetPromoShowMe,
          icon: AppIcon(
            name: canPin ? 'plus' : 'devicePhoneMobile',
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(WidgetPromoChoice.add),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          key: const ValueKey('widgetPromo-notNow'),
          text: l10n.widgetPromoNotNow,
          variant: AppButtonVariant.ghost,
          color: AppButtonColor.neutral,
          onPressed: () => Navigator.of(context).pop(WidgetPromoChoice.notNow),
        ),
        const SizedBox(height: MitlistSpacing.sm),
      ],
    );
  }
}
