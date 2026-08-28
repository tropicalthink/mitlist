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
class AppBottomSheet extends StatefulWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.body,
    this.onDragDismissRequested,
  });

  final String title;
  final Widget body;
  final Future<void> Function()? onDragDismissRequested;

  @override
  State<AppBottomSheet> createState() => _AppBottomSheetState();
}

class _AppBottomSheetState extends State<AppBottomSheet> {
  static const double _dismissDragDistance = MitlistSpacing.xxl;

  double _dragDistance = 0;
  bool _dismissRequested = false;

  void _resetDrag() {
    _dragDistance = 0;
    _dismissRequested = false;
  }

  void _trackDrag(double delta) {
    if (widget.onDragDismissRequested == null || _dismissRequested) return;
    _dragDistance = math.max(0, _dragDistance + delta);
    if (_dragDistance < _dismissDragDistance) return;
    _dismissRequested = true;
    widget.onDragDismissRequested!();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _resetDrag();
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0) {
      _trackDrag(-notification.overscroll);
    } else if (notification is ScrollEndNotification) {
      _resetDrag();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    // Flutter's macOS embedder reports no top safe-area inset, so in
    // fullscreen on notched MacBooks a tall sheet slides up behind the camera
    // housing (NSScreen reports a ~38pt top inset there). Enforce a minimum
    // top gap on macOS that clears the notch / menu-bar row.
    final minTopPadding =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS ? 40.0 : 0.0;
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
          // Transparent Material, not decoration: a ListTile paints its
          // background and ink on the nearest Material ancestor, and without
          // one here that is the sheet's own Material — below the decoration
          // above, so splashes were painted behind it and never showed.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: widget.onDragDismissRequested == null
                      ? null
                      : (_) => _resetDrag(),
                  onVerticalDragUpdate: widget.onDragDismissRequested == null
                      ? null
                      : (details) => _trackDrag(details.delta.dy),
                  onVerticalDragEnd: widget.onDragDismissRequested == null
                      ? null
                      : (_) => _resetDrag(),
                  child: Column(
                    children: [
                      const SizedBox(height: MitlistSpacing.sm),
                      Center(
                        child: Container(
                          width: MitlistSpacing.space10,
                          height: MitlistSpacing.space1,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(MitlistTheme.radiusFull),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: MitlistSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: MitlistSpacing.md),
                    ],
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MitlistSpacing.lg,
                      MitlistSpacing.space0,
                      MitlistSpacing.lg,
                      MitlistSpacing.lg,
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: SingleChildScrollView(
                        physics: widget.onDragDismissRequested == null
                            ? null
                            : const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                        child: widget.body,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  Future<void> handleGuardedDragDismiss(BuildContext context) async {
    final dirty = isDirtyListenable?.value ?? isDirty;
    if (dirty) {
      await confirmDismiss(context);
    } else if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  final usesGuardedDrag = isDirty || isDirtyListenable != null;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MitlistTheme.radiusLg),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    barrierColor:
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    isScrollControlled: true,
    // Without this the route wraps the sheet in MediaQuery.removePadding
    // (removeTop), which zeroes viewPadding.top too — AppBottomSheet then
    // sees no top inset and a tall sheet stretches under the status bar /
    // camera cutout. With useSafeArea the route itself keeps the sheet below
    // the top inset.
    useSafeArea: true,
    // Guarded sheets handle dragging inside AppBottomSheet so an edited form
    // can ask for confirmation before it is dismissed.
    isDismissible: isDirtyListenable != null ? true : !isDirty,
    enableDrag: !usesGuardedDrag,
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
            child: AppBottomSheet(
              title: title,
              body: body,
              onDragDismissRequested: () => handleGuardedDragDismiss(context),
            ),
          ),
        );
      }
      return PopScope(
        canPop: !isDirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await confirmDismiss(context);
        },
        child: AppBottomSheet(
          title: title,
          body: body,
          onDragDismissRequested:
              usesGuardedDrag ? () => handleGuardedDragDismiss(context) : null,
        ),
      );
    },
  );
}
