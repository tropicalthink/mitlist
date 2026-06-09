import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    final topPadding = MediaQuery.of(context).viewPadding.top;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - topPadding - 16,
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
            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.lg),
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
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Discard changes?',
      body: const Text('You have unsaved changes.'),
      actions: [
        AppButton(
          text: 'Keep editing',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          text: 'Discard',
          color: AppButtonColor.error,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(true),
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
    barrierColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
