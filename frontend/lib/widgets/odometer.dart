import 'package:flutter/material.dart';

import '../theme/animations.dart';

/// A mechanical, rolling-digit counter. Each digit slides vertically to its
/// new value like an odometer wheel, which fits the app's tactile,
/// physical-objects feel. Numerals are monospaced so digits never reflow as
/// the value changes.
///
/// Respects [MediaQueryData.disableAnimations]: with reduced motion the value
/// updates instantly with no roll.
class MitlistOdometer extends StatelessWidget {
  const MitlistOdometer({
    super.key,
    required this.value,
    required this.textStyle,
    this.duration = MitlistAnimations.medium,
    this.curve = MitlistAnimations.easeEnter,
  });

  /// Non-negative integer to display.
  final int value;
  final TextStyle textStyle;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final effectiveDuration = disableAnimations ? Duration.zero : duration;

    // Measure a single digit so each wheel has a stable, identical footprint.
    final painter = TextPainter(
      text: TextSpan(text: '0', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final digitWidth = painter.width;
    final digitHeight = painter.height;

    final digits = value.abs().toString().split('');

    return AnimatedSize(
      duration: effectiveDuration,
      curve: curve,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final d in digits)
            _OdometerWheel(
              digit: int.parse(d),
              width: digitWidth,
              height: digitHeight,
              style: textStyle,
              duration: effectiveDuration,
              curve: curve,
            ),
        ],
      ),
    );
  }
}

class _OdometerWheel extends StatelessWidget {
  const _OdometerWheel({
    required this.digit,
    required this.width,
    required this.height,
    required this.style,
    required this.duration,
    required this.curve,
  });

  final int digit;
  final double width;
  final double height;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: digit.toDouble()),
          duration: duration,
          curve: curve,
          builder: (context, position, _) {
            return Transform.translate(
              offset: Offset(0, -position * height),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 10; i++)
                    SizedBox(
                      width: width,
                      height: height,
                      child: Center(child: Text('$i', style: style)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
