import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/accent.dart';
import '../theme/spacing.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import 'supporter_sheet.dart';

/// Opens the accent colour picker. Accents beyond the default are part of the
/// supporter pack; a locked swatch explains that and leads to the pack.
Future<void> showAccentPickerSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<void>(
    context: context,
    title: l10n.accountAccent,
    body: const AccentPickerBody(),
  );
}

/// The localized display name of an accent.
String accentDisplayName(AppLocalizations l10n, MitlistAccent accent) {
  switch (accent) {
    case MitlistAccent.clementine:
      return l10n.accentClementine;
    case MitlistAccent.moss:
      return l10n.accentMoss;
    case MitlistAccent.sky:
      return l10n.accentSky;
    case MitlistAccent.berry:
      return l10n.accentBerry;
    case MitlistAccent.violet:
      return l10n.accentViolet;
  }
}

class AccentPickerBody extends ConsumerWidget {
  const AccentPickerBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chosen = ref.watch(accentProvider);
    final unlocked = ref.watch(supporterPerksProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: MitlistSpacing.md,
          runSpacing: MitlistSpacing.md,
          alignment: WrapAlignment.center,
          children: [
            for (final accent in MitlistAccent.values)
              _Swatch(
                accent: accent,
                label: accentDisplayName(l10n, accent),
                selected: accent == chosen,
                locked: !unlocked && !accent.isFree,
                // Match the shade the theme uses as primary in each mode so
                // the swatch previews what the person will actually see.
                color: isDark ? accent.palette.s400 : accent.palette.s500,
                onTap: () async {
                  await Haptics.light();
                  if (!unlocked && !accent.isFree) {
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    await showSupporterSheet(context);
                    return;
                  }
                  await ref.read(accentProvider.notifier).set(accent);
                },
              ),
          ],
        ),
        if (!unlocked) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Text(
            l10n.accentLockedHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            text: l10n.accentUnlock,
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            onPressed: () async {
              Navigator.of(context).pop();
              await showSupporterSheet(context);
            },
          ),
        ],
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.label,
    required this.selected,
    required this.locked,
    required this.color,
    required this.onTap,
  });

  final MitlistAccent accent;
  final String label;
  final bool selected;
  final bool locked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticsLabel = locked
        ? '$label, ${AppLocalizations.of(context)!.accentUnlock}'
        : label;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outlineVariant,
                    width: selected ? 3 : 2,
                  ),
                ),
                alignment: Alignment.center,
                child: locked
                    ? AppIcon(
                        name: 'lockClosed',
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      )
                    : selected
                        ? AppIcon(
                            name: 'check',
                            size: 22,
                            color: theme.colorScheme.onSurface,
                          )
                        : null,
              ),
              const SizedBox(height: MitlistSpacing.xs),
              Text(
                label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
