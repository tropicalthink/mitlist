import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';

/// The physical language of mitlist's first run: one cork board that every
/// auth screen is staged on. The painter is deterministic (fixed seed), so the
/// board is pixel-identical from screen to screen — a route crossfade reads as
/// paper changing on a wall that never moves.
class CorkBoardBackground extends StatelessWidget {
  const CorkBoardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Boundary keeps the grain from re-rasterizing under foreground animation.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CorkBoardPainter(dark: dark),
        size: Size.infinite,
      ),
    );
  }
}

/// Underdamped spring response as a curve: rises, overshoots ~8%, settles.
/// Expressed as a curve (not a SpringSimulation) so several elements can share
/// one master controller and stagger via [Interval] without pending timers.
class SettleCurve extends Curve {
  const SettleCurve();

  static const double _zeta = 0.62;
  static const double _omega = 5.9;

  @override
  double transformInternal(double t) {
    final omegaD = _omega * math.sqrt(1 - _zeta * _zeta);
    final decay = math.exp(-_zeta * _omega * t);
    return 1 -
        decay *
            (math.cos(omegaD * t) +
                (_zeta * _omega / omegaD) * math.sin(omegaD * t));
  }
}

/// Fade + drop + settle-into-tilt for one board object. The spring curve
/// overshoots past 1.0, which reads as the object dipping past its rest
/// position and tipping past its final tilt before settling: the landing.
class BoardDrop extends StatelessWidget {
  const BoardDrop({
    super.key,
    required this.t,
    required this.tilt,
    required this.child,
    this.dropHeight = 120,
  });

  final Animation<double> t;
  final double tilt;
  final double dropHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) {
        final v = t.value;
        return Opacity(
          opacity: (v * 2.5).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * -dropHeight),
            child: Transform.rotate(angle: tilt * v, child: child),
          ),
        );
      },
    );
  }
}

/// Press affordance shared by board objects: the object presses onto the board
/// under the finger (scale down against its hard shadow), then triggers.
class BoardPressable extends StatefulWidget {
  const BoardPressable({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<BoardPressable> createState() => _BoardPressableState();
}

class _BoardPressableState extends State<BoardPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1.0,
            duration: MitlistAnimations.micro,
            curve: MitlistAnimations.easeExit,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A piece of translucent tape crossing a paper's top edge.
class BoardTape extends StatelessWidget {
  const BoardTape({super.key, this.left, this.right, required this.angle});

  final double? left;
  final double? right;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -8,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 52,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// The pushpin holding a note to the board.
class BoardPushPin extends StatelessWidget {
  const BoardPushPin({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: MitlistColors.primary500,
        border: Border.fromBorderSide(
          BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        boxShadow: MitlistShadows.shadowSoft,
      ),
    );
  }
}

/// White paper taped to the board at two top corners.
class TapedPaper extends StatelessWidget {
  const TapedPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: padding,
          decoration: const BoxDecoration(
            color: MitlistColors.surfacePrimary,
            border: Border.fromBorderSide(
              BorderSide(color: MitlistColors.borderPrimary, width: 2),
            ),
            boxShadow: MitlistShadows.shadowMedium,
          ),
          child: child,
        ),
        const BoardTape(left: 18, angle: -0.35),
        const BoardTape(right: 18, angle: 0.30),
      ],
    );
  }
}

/// Theme-aware paper taped to the board, for functional content (forms,
/// inputs, buttons) that must follow the light/dark component vocabulary.
/// Display objects that stay paper-white in both themes use [TapedPaper].
class TapedPanel extends StatelessWidget {
  const TapedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline, width: 2),
            boxShadow: MitlistShadows.shadowMedium,
          ),
          child: child,
        ),
        const BoardTape(left: 18, angle: -0.35),
        const BoardTape(right: 18, angle: 0.30),
      ],
    );
  }
}

/// A colored sticky note pinned to the board, carrying arbitrary content.
class StickyNoteSurface extends StatelessWidget {
  const StickyNoteSurface({
    super.key,
    required this.child,
    this.color,
    this.pinned = true,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 24),
  });

  final Widget child;

  /// Defaults to the yellow note tone for the current brightness.
  final Color? color;
  final bool pinned;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final noteColor = color ??
        (dark ? MitlistColors.noteYellowDark : MitlistColors.noteYellow);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: padding,
          decoration: BoxDecoration(
            color: noteColor,
            border: Border.all(color: MitlistColors.borderPrimary, width: 2),
            boxShadow: MitlistShadows.shadowStrong,
          ),
          child: child,
        ),
        if (pinned) const Positioned(top: 0, child: BoardPushPin()),
      ],
    );
  }
}

/// Ink color for content sitting on a sticky note surface.
Color stickyNoteInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? MitlistColors.neutral50
        : MitlistColors.textPrimary;

/// A slip of paper with a torn top edge, pinned by one corner so it hangs
/// slightly askew. Paper stays paper-white in both themes so ink contrast is
/// constant.
class TornSlip extends StatelessWidget {
  const TornSlip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 24, 24, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: const TornPaperPainter(),
          child: Padding(padding: padding, child: child),
        ),
        const Positioned(top: -6, right: 26, child: BoardPushPin(size: 18)),
      ],
    );
  }
}

/// Paper with a torn top edge, drawn with the brand's hard offset shadow so
/// the border can follow the tear (a clipped Container's border can't).
class TornPaperPainter extends CustomPainter {
  const TornPaperPainter();

  Path _paperPath(Size size) {
    final path = Path()..moveTo(0, 12);
    // Deterministic tear: fixed jitter heights so the edge never dances
    // between repaints.
    const teeth = [4.0, 13.0, 7.0, 15.0, 5.0, 11.0, 3.0, 14.0, 8.0];
    for (var i = 0; i < teeth.length; i++) {
      final x = size.width * (i + 1) / teeth.length;
      path.lineTo(x, teeth[i]);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paper = _paperPath(size);

    // Hard offset shadow, same idiom as MitlistShadows.
    canvas.save();
    canvas.translate(6, 6);
    canvas.drawPath(paper, Paint()..color = MitlistColors.neutral950);
    canvas.restore();

    canvas.drawPath(paper, Paint()..color = MitlistColors.surfacePrimary);
    canvas.drawPath(
      paper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = MitlistColors.borderPrimary,
    );
  }

  @override
  bool shouldRepaint(TornPaperPainter oldDelegate) => false;
}

/// Full-bleed cork with grain flecks and an edge vignette: the same surface
/// the pinwall board is made of, so the first screens and the household's
/// board are recognizably one material.
class _CorkBoardPainter extends CustomPainter {
  const _CorkBoardPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cork =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final grain = dark
        ? MitlistColors.pinwallBoardBorderDark
        : MitlistColors.pinwallBoardBorder;

    canvas.drawRect(Offset.zero & size, Paint()..color = cork);

    final rng = _LCG(seed: 42);
    final grainPaint = Paint()
      ..color = grain.withValues(alpha: dark ? 0.18 : 0.12)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 500; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = 8 + rng.nextDouble() * 24;
      final drift = (rng.nextDouble() - 0.5) * 0.4;
      canvas.drawLine(
        Offset(x, y),
        Offset(
          x + len * (1 + drift),
          y + len * 0.15 * (rng.nextDouble() - 0.5),
        ),
        grainPaint,
      );
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          (dark ? Colors.black : MitlistColors.pinwallBoardBorder)
              .withValues(alpha: dark ? 0.28 : 0.14),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_CorkBoardPainter oldDelegate) => oldDelegate.dark != dark;
}

// Deterministic pseudo-random (LCG), matching the pinwall's grain generator.
class _LCG {
  _LCG({required int seed}) : _s = seed;
  int _s;
  double nextDouble() {
    _s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_s & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}
