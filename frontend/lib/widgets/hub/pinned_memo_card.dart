import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// A pushpin drawn at the top of pinwall items. Scales with [size].
class PinwallPushpin extends StatelessWidget {
  const PinwallPushpin({
    super.key,
    required this.headColor,
    this.size = const Size(22, 28),
  });

  final Color headColor;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: _PushpinPainter(headColor: headColor),
    );
  }
}

class _PushpinPainter extends CustomPainter {
  const _PushpinPainter({required this.headColor});

  final Color headColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final r = size.width * 0.45;
    final cy = r;

    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = headColor);

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.8),
        width: r * 1.4,
        height: r * 0.5,
      ),
      Paint()..color = MitlistColors.neutral950.withValues(alpha: 0.18),
    );

    final needle = Path()
      ..moveTo(cx - size.width * 0.07, cy + r * 0.9)
      ..lineTo(cx + size.width * 0.07, cy + r * 0.9)
      ..lineTo(cx, size.height)
      ..close();
    canvas.drawPath(
      needle,
      Paint()..color = MitlistColors.neutral950.withValues(alpha: 0.72),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = MitlistColors.neutral950.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PushpinPainter old) => old.headColor != headColor;
}
