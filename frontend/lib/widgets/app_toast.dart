import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../utils/haptics.dart';
import 'app_icon.dart';

/// What a toast is telling the user. This is the part Material's SnackBar
/// never had: today a settlement recorded and a settlement that failed produce
/// the same grey pill, so the only way to tell them apart is to read.
enum AppToastTone {
  /// Something the user asked for happened.
  success,

  /// Something the user asked for did not happen.
  error,

  /// Neither — a state change worth mentioning.
  info,
}

/// The app's confirmation layer.
///
/// One place decides what a confirmation looks like, how long it stays, and
/// what it feels like, so the answer is the same on every screen. Toasts are
/// drawn in the same material as everything else — 2px ink border, zero
/// radius, hard ink offset — rather than Material's floating grey pill, and
/// each one carries a bordered swatch that says at a glance whether the thing
/// worked.
///
/// Every toast also fires the haptic for its tone. That is the real reason
/// this is centralised: the app has had a four-tier haptic vocabulary in
/// `utils/haptics.dart` all along and almost nothing called it. Routing
/// confirmations through here gives every one of them the right feel without
/// touching the call site.
class AppToast {
  const AppToast._();

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message, AppToastTone.success,
          actionLabel: actionLabel, onAction: onAction);

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message, AppToastTone.error,
          actionLabel: actionLabel, onAction: onAction);

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      _show(context, message, AppToastTone.info,
          actionLabel: actionLabel, onAction: onAction);

  /// A success the user can take back. Stays roughly three times as long as a
  /// plain confirmation, because an undo nobody has time to reach is a
  /// decoration.
  static void undo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    _show(
      context,
      message,
      AppToastTone.success,
      duration: undoDuration,
      actionLabel: l10n.commonUndo,
      onAction: () {
        messenger.hideCurrentSnackBar();
        onUndo();
      },
    );
  }

  /// An inbound push notification, shown while the app is in the foreground.
  ///
  /// Takes a messenger rather than a context because it fires from a stream
  /// listener with no element of its own. Tone is [AppToastTone.info]: nothing
  /// the user just did succeeded or failed, something arrived.
  static void notification(
    ScaffoldMessengerState messenger, {
    String? title,
    required String body,
  }) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(MitlistSpacing.space4),
          duration: notificationDuration,
          content: _ToastBody(
            message: body,
            title: title,
            tone: AppToastTone.info,
          ),
        ),
      );
  }

  static const Duration successDuration = Duration(seconds: 3);
  static const Duration notificationDuration = Duration(seconds: 5);
  static const Duration infoDuration = Duration(seconds: 4);

  /// Errors linger: the user has to read them, and often act on them.
  static const Duration errorDuration = Duration(seconds: 5);
  static const Duration undoDuration = Duration(seconds: 9);

  static Duration _durationFor(AppToastTone tone) => switch (tone) {
        AppToastTone.success => successDuration,
        AppToastTone.error => errorDuration,
        AppToastTone.info => infoDuration,
      };

  static void _haptic(AppToastTone tone) {
    switch (tone) {
      case AppToastTone.success:
        // Light, not Haptics.success(): these fire dozens of times an errand.
        // A heavy thump on every checked-off item is a nag, not feedback.
        Haptics.light();
      case AppToastTone.error:
        Haptics.failure();
      case AppToastTone.info:
        break;
    }
  }

  static void _show(
    BuildContext context,
    String message,
    AppToastTone tone, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _haptic(tone);
    ScaffoldMessenger.of(context)
      // Without this a burst of confirmations queues up and the user watches
      // them drain one by one, long after the moment has passed.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          behavior: SnackBarBehavior.floating,
          // It has to float clear of the edges or its ink offset is sheared
          // off against them and it stops reading as an object on the screen.
          margin: const EdgeInsets.all(MitlistSpacing.space4),
          duration: duration ?? _durationFor(tone),
          content: _ToastBody(
            message: message,
            tone: tone,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      );
  }
}

class _ToastBody extends StatelessWidget {
  const _ToastBody({
    required this.message,
    required this.tone,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final AppToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Deep enough that the white glyph clears AA against every one of them
  /// (5.5:1, 4.8:1, 5.2:1), in both themes, without swapping per mode.
  Color get _toneColor => switch (tone) {
        AppToastTone.success => MitlistColors.success700,
        AppToastTone.error => MitlistColors.error600,
        AppToastTone.info => MitlistColors.primary700,
      };

  String get _iconName => switch (tone) {
        AppToastTone.success => 'check',
        AppToastTone.error => 'exclamationTriangle',
        AppToastTone.info => 'informationCircle',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // The offset stands in for a shadow, so it is the ink of the current mode.
    // A hardcoded black one disappears against a dark surface.
    final ink = colorScheme.outline;
    final surface =
        isDark ? MitlistColors.neutral900 : MitlistColors.surfacePrimary;

    // No Semantics wrapper here: SnackBar already declares its content a live
    // region and merges the subtree into one node, so the message and any
    // action are announced together. Adding another only duplicated the flag.
    return Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: ink, width: 2),
          boxShadow: [
            BoxShadow(color: ink, offset: const Offset(4, 4)),
          ],
        ),
        padding: const EdgeInsets.all(MitlistSpacing.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ToneSwatch(color: _toneColor, iconName: _iconName, ink: ink),
            const SizedBox(width: MitlistSpacing.space3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurface),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: MitlistSpacing.space3),
              _ToastAction(label: actionLabel!, onPressed: onAction!, ink: ink),
            ],
          ],
        ));
  }
}

/// A bordered square, not a coloured stripe down the edge. The tone reads at a
/// glance and the toast still belongs to the same drawing as the nav badge.
class _ToneSwatch extends StatelessWidget {
  const _ToneSwatch({
    required this.color,
    required this.iconName,
    required this.ink,
  });

  final Color color;
  final String iconName;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MitlistSpacing.space6,
      height: MitlistSpacing.space6,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: ink, width: 2),
      ),
      child: Center(
        child: AppIcon(
          name: iconName,
          size: 14,
          color: MitlistColors.textOnPrimary,
        ),
      ),
    );
  }
}

/// Presses into its shadow like every other button in the app.
///
/// Deliberately not the primary orange: in this system orange means commit,
/// and the only action a toast offers is taking something back. A neutral key
/// with the same physics stays legible without claiming to be the main thing
/// on screen.
class _ToastAction extends StatefulWidget {
  const _ToastAction({
    required this.label,
    required this.onPressed,
    required this.ink,
  });

  final String label;
  final VoidCallback onPressed;
  final Color ink;

  @override
  State<_ToastAction> createState() => _ToastActionState();
}

class _ToastActionState extends State<_ToastAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final shift = _pressed && !disableAnimations ? 2.0 : 0.0;
    final fill =
        isDark ? MitlistColors.neutral800 : MitlistColors.surfaceSecondary;

    return InkWell(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: AnimatedContainer(
        duration: disableAnimations ? Duration.zero : MitlistAnimations.micro,
        curve: MitlistAnimations.easeExit,
        transform: Matrix4.translationValues(shift, shift, 0),
        constraints: const BoxConstraints(minHeight: MitlistSpacing.space11),
        padding: const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.space3,
          vertical: MitlistSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: widget.ink, width: 2),
          boxShadow: _pressed
              ? const []
              : [BoxShadow(color: widget.ink, offset: const Offset(2, 2))],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}
