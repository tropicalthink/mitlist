import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import 'app_button.dart';

/// How a coach mark ended.
enum CoachMarkResult {
  /// Next (or a tap on the highlighted target).
  next,

  /// Skip: the person wants no more tips now.
  skip,

  /// Back button, back gesture or the route went away.
  dismissed,

  /// The target was not on screen; nothing was shown.
  missing,
}

/// Shows one coach mark: the screen dimmed except for a square cut-out
/// around [target], a short bubble with [message], a drawn arrow from the
/// bubble to the target, step dots, Next and Skip.
///
/// Behaviour, for every feature that uses it:
/// - the target is scrolled into view first when it sits in a scrollable;
/// - a tap on the highlighted target counts as Next; a tap anywhere else on
///   the dimmed backdrop does nothing (it never reaches the screen below,
///   and never ends the tour by accident);
/// - back (button or gesture) dismisses it; Skip is always there;
/// - it follows the target through rotation and resizes;
/// - with reduce motion it appears without animation, and screen readers
///   get a route named "Tip 1 of 3" with the message, Next and Skip.
Future<CoachMarkResult> showCoachMark(
  BuildContext context, {
  required GlobalKey target,
  required String message,
  required int step,
  required int total,
}) async {
  final targetContext = target.currentContext;
  if (targetContext == null) return CoachMarkResult.missing;
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  if (Scrollable.maybeOf(targetContext) != null) {
    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.3,
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
    );
  }
  if (!context.mounted || target.currentContext == null) {
    return CoachMarkResult.missing;
  }
  final result = await Navigator.of(context, rootNavigator: true).push(
    _CoachMarkRoute(
      target: target,
      message: message,
      step: step,
      total: total,
      reduceMotion: reduceMotion,
    ),
  );
  return result ?? CoachMarkResult.dismissed;
}

class _CoachMarkRoute extends PageRoute<CoachMarkResult> {
  _CoachMarkRoute({
    required this.target,
    required this.message,
    required this.step,
    required this.total,
    required this.reduceMotion,
  });

  final GlobalKey target;
  final String message;
  final int step;
  final int total;
  final bool reduceMotion;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return CoachMarkOverlay(
      target: target,
      message: message,
      step: step,
      total: total,
      onResult: (r) => Navigator.of(context).pop(r),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (reduceMotion) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}

/// The overlay itself, public so it can be pumped directly in tests.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.target,
    required this.message,
    required this.step,
    required this.total,
    required this.onResult,
  });

  final GlobalKey target;
  final String message;
  final int step;
  final int total;
  final ValueChanged<CoachMarkResult> onResult;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with WidgetsBindingObserver {
  Rect? _hole;
  final _layout = _BubbleLayoutInfo();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Rotation, split screen, keyboard: measure again once the screen below
  /// has laid out at the new size.
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final next = _targetRect();
    if (next != _hole) setState(() => _hole = next);
  }

  Rect? _targetRect() {
    final box = widget.target.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    final overlay = context.findRenderObject();
    final shift = overlay is RenderBox && overlay.attached
        ? overlay.localToGlobal(Offset.zero)
        : Offset.zero;
    return (origin - shift) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    _hole ??= _targetRect();
    // Keep following the target (it may still be settling after a scroll).
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    // The highlight never leaves the screen, so its outline stays visible
    // for a target at an edge (an app bar button, the bottom bar).
    Rect? hole;
    final raw = _hole;
    if (raw != null) {
      final clamped = Rect.fromLTRB(
        math.max(raw.left - MitlistSpacing.sm, 2),
        math.max(raw.top - MitlistSpacing.sm, 2),
        math.min(raw.right + MitlistSpacing.sm, size.width - 2),
        math.min(raw.bottom + MitlistSpacing.sm, size.height - 2),
      );
      // Off screen (mid-transition): no cut-out until it is back.
      if (clamped.width > 0 && clamped.height > 0) hole = clamped;
    }
    final last = widget.step >= widget.total;

    final bubble = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.coachMarkStepLabel(widget.step, widget.total),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.onSurface, width: 2),
          boxShadow: dark ? null : MitlistShadows.shadowMedium,
        ),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Only the message scrolls (very large text): Next and Skip
            // always stay in reach.
            Flexible(
              child: SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: MitlistSpacing.sm,
              runSpacing: MitlistSpacing.sm,
              children: [
                if (widget.total > 1)
                  ExcludeSemantics(
                    child: _StepDots(step: widget.step, total: widget.total),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!last)
                      AppButton(
                        key: const ValueKey('coachMark-skip'),
                        text: l10n.coachMarkSkip,
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () => widget.onResult(CoachMarkResult.skip),
                      ),
                    const SizedBox(width: MitlistSpacing.xs),
                    AppButton(
                      key: const ValueKey('coachMark-next'),
                      text: last ? l10n.coachMarkDone : l10n.coachMarkNext,
                      size: AppButtonSize.sm,
                      onPressed: () => widget.onResult(CoachMarkResult.next),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // The backdrop swallows every tap: nothing below is triggered.
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(
                  painter: _BackdropPainter(
                    hole: hole,
                    scrim: dark
                        ? MitlistColors.scrimDark
                        : MitlistColors.scrimLight,
                    outline: cs.primary,
                  ),
                ),
              ),
            ),
          ),
          if (hole != null)
            Positioned.fromRect(
              rect: hole,
              child: ExcludeSemantics(
                child: GestureDetector(
                  key: const ValueKey('coachMark-target'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onResult(CoachMarkResult.next),
                ),
              ),
            ),
          Positioned.fill(
            child: CustomMultiChildLayout(
              delegate: _BubbleLayout(
                hole: hole,
                info: _layout,
                safe: padding,
              ),
              children: [
                LayoutId(
                  id: _Slot.arrow,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ArrowPainter(
                        info: _layout,
                        color: cs.primary,
                      ),
                      size: size,
                    ),
                  ),
                ),
                LayoutId(id: _Slot.bubble, child: bubble),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Slot { bubble, arrow }

/// Where the bubble ended up and where the arrow goes, filled during layout
/// and read when painting the same frame.
class _BubbleLayoutInfo {
  Offset? from;
  Offset? to;
}

class _BubbleLayout extends MultiChildLayoutDelegate {
  _BubbleLayout({required this.hole, required this.info, required this.safe});

  final Rect? hole;
  final _BubbleLayoutInfo info;
  final EdgeInsets safe;

  static const _margin = MitlistSpacing.md;
  static const _arrowGap = 56.0;
  static const _maxWidth = 360.0;

  @override
  void performLayout(Size size) {
    final width = math.min(size.width - 2 * _margin, _maxWidth);
    final top = safe.top + _margin;
    final bottom = size.height - safe.bottom - _margin;
    final h = hole;
    if (h == null) {
      final s = layoutChild(_Slot.bubble,
          BoxConstraints(maxWidth: width, maxHeight: bottom - top));
      positionChild(_Slot.bubble,
          Offset((size.width - s.width) / 2, (size.height - s.height) / 2));
      info
        ..from = null
        ..to = null;
    } else {
      final spaceBelow = bottom - h.bottom - _arrowGap;
      final spaceAbove = h.top - _arrowGap - top;
      final below = spaceBelow >= spaceAbove;
      final maxHeight = math.max(120.0, below ? spaceBelow : spaceAbove);
      final s = layoutChild(
          _Slot.bubble,
          BoxConstraints(
              maxWidth: width, minWidth: width, maxHeight: maxHeight));
      final left = (h.center.dx - s.width / 2)
          .clamp(_margin, size.width - _margin - s.width)
          .toDouble();
      final y = below
          ? math.min(h.bottom + _arrowGap, bottom - s.height)
          : math.max(h.top - _arrowGap - s.height, top);
      positionChild(_Slot.bubble, Offset(left, y));
      // The arrow leaves the bubble edge facing the target, above or below
      // the target's centre where possible.
      final fromX = s.width > 48
          ? h.center.dx.clamp(left + 24, left + s.width - 24).toDouble()
          : left + s.width / 2;
      final toX = h.width > 16
          ? h.center.dx.clamp(h.left + 8, h.right - 8).toDouble()
          : h.center.dx;
      info
        ..from = Offset(fromX, below ? y : y + s.height)
        ..to = Offset(toX, below ? h.bottom + 6 : h.top - 6);
    }
    layoutChild(_Slot.arrow, BoxConstraints.tight(size));
    positionChild(_Slot.arrow, Offset.zero);
  }

  @override
  bool shouldRelayout(_BubbleLayout old) =>
      old.hole != hole || old.safe != safe;
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.info, required this.color});

  final _BubbleLayoutInfo info;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final from = info.from;
    final to = info.to;
    if (from == null || to == null) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    // A hand-drawn feel: a gentle bend to one side.
    final mid = Offset.lerp(from, to, 0.5)!;
    final bend = (to.dx - from.dx).abs() < 12 ? 18.0 : 0.0;
    final control = Offset(mid.dx + bend, mid.dy);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
    // Arrowhead along the curve's final direction.
    final dir = (to - control);
    final angle = math.atan2(dir.dy, dir.dx);
    const head = 12.0;
    for (final side in [-1, 1]) {
      final a = angle + math.pi + side * math.pi / 6;
      canvas.drawLine(
          to, to + Offset(math.cos(a) * head, math.sin(a) * head), paint);
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => true;
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.hole,
    required this.scrim,
    required this.outline,
  });

  final Rect? hole;
  final Color scrim;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final h = hole;
    final path = Path()..addRect(full);
    if (h != null) {
      path
        ..addRect(h)
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = scrim);
    if (h != null) {
      canvas.drawRect(
        h,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.hole != hole || old.scrim != scrim || old.outline != outline;
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= total; i++)
          Container(
            width: i == step ? 18 : 8,
            height: 8,
            margin: const EdgeInsets.only(right: MitlistSpacing.xs),
            decoration: BoxDecoration(
              color: i <= step ? cs.primary : cs.surface,
              border: Border.all(color: cs.onSurface, width: 1.5),
            ),
          ),
      ],
    );
  }
}
