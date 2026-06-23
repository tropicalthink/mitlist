import 'package:flutter/material.dart';

import '../../theme/animations.dart';

/// Collapses its child's height to zero (with a fade) when [collapsed] flips
/// on, then reports completion via [onCollapsed] so the parent can re-section
/// the item without a visible jump. At rest it is a transparent passthrough.
class SettleCollapse extends StatelessWidget {
  const SettleCollapse({
    super.key,
    required this.collapsed,
    required this.onCollapsed,
    required this.child,
  });

  final bool collapsed;
  final VoidCallback onCollapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: collapsed ? 0.0 : 1.0),
      duration: disableAnimations ? Duration.zero : MitlistAnimations.micro,
      curve: MitlistAnimations.easeExit,
      onEnd: () {
        if (collapsed) onCollapsed();
      },
      child: child,
      builder: (context, t, child) {
        if (t >= 1.0) return child!;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
    );
  }
}
