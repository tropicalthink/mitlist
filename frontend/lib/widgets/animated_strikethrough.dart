import 'package:flutter/material.dart';

import '../theme/animations.dart';

/// Single-line text whose strikethrough draws itself across the glyphs when
/// [struck] flips on, and retracts when it flips off. The line is painted
/// (square-capped, hard-edged) instead of using [TextDecoration.lineThrough]
/// so completion reads as a deliberate pen stroke rather than a style swap.
///
/// The text color cross-fades between [color] and [struckColor] in step with
/// the stroke. Respects [MediaQueryData.disableAnimations]: with reduced
/// motion both the line and the color change instantly.
class AnimatedStrikethrough extends StatelessWidget {
  const AnimatedStrikethrough({
    super.key,
    required this.text,
    required this.struck,
    required this.style,
    this.color,
    this.struckColor,
    this.duration = MitlistAnimations.checkToggle,
  });

  final String text;
  final bool struck;
  final TextStyle? style;

  /// Text color when not struck. Defaults to [style]'s color.
  final Color? color;

  /// Text and stroke color when struck. Defaults to onSurfaceVariant.
  final Color? struckColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = color ?? style?.color ?? colorScheme.onSurface;
    final doneColor = struckColor ?? colorScheme.onSurfaceVariant;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: struck ? 1.0 : 0.0),
      duration: disableAnimations ? Duration.zero : duration,
      curve: MitlistAnimations.easeEnter,
      builder: (context, t, _) {
        final textColor = Color.lerp(baseColor, doneColor, t) ?? baseColor;
        final effectiveStyle = (style ?? const TextStyle()).copyWith(
          color: textColor,
          decoration: TextDecoration.none,
        );
        return CustomPaint(
          foregroundPainter: t > 0
              ? _StrikePainter(
                  text: text,
                  style: effectiveStyle,
                  progress: t,
                  color: doneColor,
                )
              : null,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: effectiveStyle,
          ),
        );
      },
    );
  }
}

class _StrikePainter extends CustomPainter {
  _StrikePainter({
    required this.text,
    required this.style,
    required this.progress,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Measure the rendered (possibly ellipsized) line so the stroke covers
    // the glyphs, not the whole row width.
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final textWidth = painter.width.clamp(0.0, size.width);
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(0, y), Offset(textWidth * progress, y), paint);
  }

  @override
  bool shouldRepaint(_StrikePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.text != text ||
        oldDelegate.color != color ||
        oldDelegate.style != style;
  }
}
