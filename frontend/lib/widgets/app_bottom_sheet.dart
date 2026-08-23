import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/animations.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';
import 'app_button.dart';
import 'app_dialog.dart';

/// A custom bottom sheet matching the mitlist design system.
///
/// Use [showAppBottomSheet] to display with the correct shape and animation.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    // Flutter's macOS embedder reports no top safe-area inset, so in
    // fullscreen on notched MacBooks a tall sheet slides up behind the camera
    // housing (NSScreen reports a ~38pt top inset there). Enforce a minimum
    // top gap on macOS that clears the notch / menu-bar row.
    final minTopPadding = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS
        ? 40.0
        : 0.0;
    final topPadding = math.max(mediaQuery.viewPadding.top, minTopPadding);
    // The on-screen keyboard inset. `showModalBottomSheet` (even with
    // isScrollControlled) does not resize for the keyboard, so without this the
    // keyboard covers the sheet's input + primary button. Tracks the keyboard
    // animation frame-by-frame since MediaQuery rebuilds on each metrics change.
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Padding(
      // Lift the whole sheet above the keyboard.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // Subtract the keyboard inset too, so the lifted sheet still fits on
          // screen and its scrollable body gets the correct max height.
          maxHeight: mediaQuery.size.height - topPadding - bottomInset - 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MitlistTheme.radiusLg),
            ),
            border: Border(
              top: BorderSide(color: colorScheme.outline, width: 2),
              left: BorderSide(color: colorScheme.outline, width: 2),
              right: BorderSide(color: colorScheme.outline, width: 2),
            ),
            boxShadow: MitlistShadows.shadowFloating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: MitlistSpacing.sm),
              Center(
                child: Container(
                  width: MitlistSpacing.space10,
                  height: MitlistSpacing.space1,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(MitlistTheme.radiusFull),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MitlistSpacing.sm),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: MitlistSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MitlistSpacing.md),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    MitlistSpacing.lg,
                    MitlistSpacing.space0,
                    MitlistSpacing.lg,
                    MitlistSpacing.lg,
                  ),
                  child: SingleChildScrollView(
                    child: body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows an [AppBottomSheet] with a slide-up animation and scrim backdrop.
///
/// Pass [isDirtyListenable] for forms whose dirty state changes while the sheet
/// is open: dismissal is then guarded by a "Discard changes?" dialog only while
/// the value is `true`. The static [isDirty] flag remains for sheets that are
/// dirty for their whole lifetime.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  bool isDirty = false,
  ValueListenable<bool>? isDirtyListenable,
}) {
  Future<void> confirmDismiss(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.appBottomSheetDiscardTitle,
      body: Text(l10n.appBottomSheetDiscardBody),
      actions: [
        AppButton(
          text: l10n.appBottomSheetKeepEditing,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        AppButton(
          text: l10n.recipeCreationDiscard,
          color: AppButtonColor.error,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor:
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    isScrollControlled: true,
    // When dirtiness is dynamic, route every dismissal through the barrier so
    // the PopScope guard below can intercept it; drag-to-dismiss bypasses it.
    isDismissible: isDirtyListenable != null ? true : !isDirty,
    enableDrag: isDirtyListenable != null ? false : !isDirty,
    sheetAnimationStyle: AnimationStyle(duration: MitlistAnimations.medium),
    builder: (context) {
      if (isDirtyListenable != null) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDirtyListenable,
          builder: (context, dirty, _) => PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              await confirmDismiss(context);
            },
            child: AppBottomSheet(title: title, body: body),
          ),
        );
      }
      return PopScope(
        canPop: !isDirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await confirmDismiss(context);
        },
        child: AppBottomSheet(title: title, body: body),
      );
    },
  );
}
