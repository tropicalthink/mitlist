import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/theme.dart';

enum AppSkeletonRadius { none, sm }

class AppSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final AppSkeletonRadius borderRadius;

  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppSkeletonRadius.none,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.skeleton,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _radius {
    switch (widget.borderRadius) {
      case AppSkeletonRadius.none:
        return MitlistTheme.radiusNone;
      case AppSkeletonRadius.sm:
        return MitlistTheme.radiusSm;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final colorScheme = Theme.of(context).colorScheme;
    final base = colorScheme.surfaceContainerHighest;
    final highlight = colorScheme.surfaceContainerHigh;

    Widget box(Color color) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
        ),
      );
    }

    if (disableAnimations) {
      return RepaintBoundary(child: box(base));
    }

    // Use a lightweight pulse instead of a shader-based shimmer to avoid
    // "draggy" motion and reduce paint cost when many skeletons are on-screen.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // 0..1..0 triangle wave feels more "breathing" than constant sweep.
          final t = _controller.value;
          final pulse = 1.0 - (t - 0.5).abs() * 2.0;
          final color = Color.lerp(base, highlight, pulse * 0.85)!;
          return box(color);
        },
      ),
    );
  }
}
