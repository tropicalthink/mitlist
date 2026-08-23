import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/shadows.dart';

/// Opens a camera surface inline, ChatGPT-style: a rounded camera card slides
/// up over the bottom of the current screen while the app stays visible (and
/// undimmed) above it, so the camera reads as part of the screen rather than
/// a page you navigated to. Tapping the area above the card, or the system
/// back gesture, dismisses it.
///
/// Camera screens shown through this route should paint a black background
/// while the camera initializes — the card then reads as a shutter opening,
/// and the live preview can fade in on top once ready.
Future<T?> pushInlineCamera<T extends Object?>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    InlineCameraRoute<T>(builder: builder),
  );
}

class InlineCameraRoute<T> extends PageRoute<T> {
  InlineCameraRoute({required this.builder});

  final WidgetBuilder builder;

  /// Fraction of the screen height the camera card occupies.
  static const double _heightFraction = 0.72;

  /// Corner radius of the card — deliberately rounder than the design
  /// system's cards so the camera reads as a distinct floating surface.
  static const double _cornerRadius = 28;

  static const double _edgeMargin = 10;

  /// Cap on very wide screens (tablets / desktop) so the card stays
  /// camera-shaped instead of stretching edge to edge.
  static const double _maxWidth = 560;

  // The screen behind stays visible and undimmed the whole time.
  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => MitlistAnimations.cameraExpand;

  @override
  Duration get reverseTransitionDuration => MitlistAnimations.medium;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The exposed strip of app above the card: tapping it closes the
        // camera, like tapping outside a sheet.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => Navigator.of(context).pop(),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Container(
              height: media.size.height * _heightFraction,
              margin: EdgeInsets.fromLTRB(
                _edgeMargin,
                0,
                _edgeMargin,
                media.padding.bottom + _edgeMargin,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(_cornerRadius),
                border: Border.all(color: colorScheme.outline, width: 2),
                boxShadow: MitlistShadows.shadowFloating,
              ),
              // The card sits clear of the notch and home indicator, so the
              // camera screen's own SafeArea must not re-apply those insets.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: builder(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: MitlistAnimations.easeEnter,
      reverseCurve: MitlistAnimations.easeExit,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        // Slide the whole layer by a little more than the card's height, so
        // the card starts fully offscreen and settles up into place.
        return FractionalTranslation(
          translation: Offset(0, (_heightFraction + 0.05) * (1 - t)),
          child: child,
        );
      },
    );
  }
}
