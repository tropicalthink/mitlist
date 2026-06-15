import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';

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

/// A pinned "memo sheet" that sits on the pinwall cork. Visually a step apart
/// from the colored sticky notes — it's a clean paper card held by a pushpin —
/// so richer hub summaries (stats, tonight) can live on the board itself
/// instead of floating above or overlaying it.
///
/// Pass [width] for a fixed-size card (board canvas); leave it null to stretch
/// to the incoming constraints (in-column closed mode).
class PinnedMemoCard extends StatelessWidget {
  const PinnedMemoCard({
    super.key,
    required this.child,
    required this.pinColor,
    this.width,
    this.rotation = 0,
  });

  final Widget child;
  final Color pinColor;
  final double? width;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark
        ? MitlistColors.composerBorderDark
        : MitlistColors.composerBorderLight;

    return Transform.rotate(
      angle: rotation,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              MitlistSpacing.lg,
              MitlistSpacing.md,
              MitlistSpacing.md,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
              border: Border.all(color: border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: MitlistColors.neutral950
                      .withValues(alpha: dark ? 0.42 : 0.16),
                  blurRadius: 0,
                  offset: const Offset(4, 5),
                ),
              ],
            ),
            child: child,
          ),
          Positioned(
            top: -14,
            left: 0,
            right: 0,
            child: Center(child: PinwallPushpin(headColor: pinColor)),
          ),
        ],
      ),
    );
  }
}
