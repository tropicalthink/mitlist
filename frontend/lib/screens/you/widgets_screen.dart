import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/group_provider.dart' show cachedGroupsProvider;
import '../../providers/home_widgets_provider.dart';
import '../../providers/widget_discovery_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/widgets/home_widget_kind.dart';
import '../../theme/spacing.dart';
import '../../utils/active_group_context.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/home_widget_preview.dart';
import '../../widgets/mitlist_app_bar.dart';

/// The household name widget previews show: the active household when the
/// cache knows it, otherwise null (the preview then uses a sample name).
String? activeHouseholdName(WidgetRef ref) {
  final groups = ref.watch(cachedGroupsProvider).valueOrNull;
  if (groups == null || groups.isEmpty) return null;
  final id = resolveActiveGroupId(groups, ref.watch(currentGroupIdProvider));
  for (final group in groups) {
    if (group.id == id) return group.name;
  }
  return null;
}

/// You > Home screen widgets (`/you/widgets`): what each widget looks like,
/// whether it is on the home screen already, and how to add it. On Android
/// launchers that support it, one tap pins a widget; otherwise, and always on
/// iOS, numbered steps explain the home screen's own flow.
class WidgetsScreen extends ConsumerStatefulWidget {
  const WidgetsScreen({super.key});

  @override
  ConsumerState<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends ConsumerState<WidgetsScreen> {
  /// A one-tap pin the launcher refused: show the written steps after all.
  bool _pinFailed = false;
  HomeWidgetKind? _pinning;

  Future<void> _pin(HomeWidgetKind kind) async {
    if (_pinning != null) return;
    setState(() => _pinning = kind);
    final shown = await ref.read(widgetBridgeProvider).pinWidget(kind.id);
    if (!mounted) return;
    setState(() {
      _pinning = null;
      if (!shown) _pinFailed = true;
    });
    if (!shown) {
      AppToast.info(
          context, AppLocalizations.of(context)!.widgetsPagePinFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final supported = ref.watch(widgetBridgeProvider).isSupported;
    final platform = ref.watch(homeWidgetPlatformProvider);
    final isIos = platform == TargetPlatform.iOS;
    final installed = ref.watch(installedHomeWidgetsProvider).valueOrNull;
    final canPin =
        !isIos && (ref.watch(pinWidgetSupportedProvider).valueOrNull ?? false);
    final showSteps = isIos || !canPin || _pinFailed;
    final household = activeHouseholdName(ref);

    final steps = isIos
        ? [
            l10n.widgetsPageIosStep1,
            l10n.widgetsPageIosStep2,
            l10n.widgetsPageIosStep3,
            l10n.widgetsPageIosStep4,
          ]
        : [
            l10n.widgetsPageAndroidStep1,
            l10n.widgetsPageAndroidStep2,
            l10n.widgetsPageAndroidStep3,
          ];

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.widgetsPageTitle,
        showStandardActions: false,
      ),
      // The route redirects away where there are no widgets; this only
      // covers a frame of that.
      body: !supported
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              children: [
                Text(
                  l10n.widgetsPageIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: MitlistSpacing.lg),
                if (showSteps) ...[
                  _StepsCard(title: l10n.widgetsPageStepsTitle, steps: steps),
                  const SizedBox(height: MitlistSpacing.lg),
                ],
                for (final kind in HomeWidgetKind.availableOn(platform)) ...[
                  _WidgetCard(
                    kind: kind,
                    householdName: household,
                    platform: platform,
                    added: installed?.contains(kind.id) ?? false,
                    onAdd: canPin ? () => _pin(kind) : null,
                    pinning: _pinning == kind,
                  ),
                  const SizedBox(height: MitlistSpacing.md),
                ],
              ],
            ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.md),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == steps.length - 1 ? 0 : MitlistSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: MitlistSpacing.space6,
                    height: MitlistSpacing.space6,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      border: Border.all(color: scheme.outline, width: 2),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: MitlistSpacing.space0_5,
                      ),
                      child: Text(steps[i], style: theme.textTheme.bodyMedium),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({
    required this.kind,
    required this.householdName,
    required this.platform,
    required this.added,
    required this.onAdd,
    required this.pinning,
  });

  final HomeWidgetKind kind;
  final String? householdName;
  final TargetPlatform platform;
  final bool added;

  /// Pins the widget; null where the launcher cannot.
  final VoidCallback? onAdd;
  final bool pinning;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      key: ValueKey('widgetsPage-${kind.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            color: scheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: HomeWidgetPreview(
              kind: kind,
              householdName: householdName,
              platform: platform,
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  homeWidgetName(l10n, kind),
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (added) _AddedBadge(label: l10n.widgetsPageAdded),
            ],
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            homeWidgetDescription(l10n, kind),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (onAdd != null && !added) ...[
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: l10n.widgetsPageAdd,
              icon: const AppIcon(name: 'plus', size: 18),
              isLoading: pinning,
              onPressed: onAdd,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddedBadge extends StatelessWidget {
  const _AddedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.sm,
        vertical: MitlistSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        border: Border.all(color: scheme.outline, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(name: 'check', size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: MitlistSpacing.xs),
          Text(
            label,
            maxLines: 1,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
