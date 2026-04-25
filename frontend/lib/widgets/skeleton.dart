import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
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

    final baseWidget = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: MitlistColors.neutral200,
        borderRadius: BorderRadius.all(Radius.circular(_radius)),
      ),
    );

    if (disableAnimations) {
      return baseWidget;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                MitlistColors.neutral200,
                MitlistColors.neutral100,
                MitlistColors.neutral200,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + _controller.value * 2, 0.0),
              end: Alignment(1.0 + _controller.value * 2, 0.0),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: baseWidget,
        );
      },
    );
  }
}
