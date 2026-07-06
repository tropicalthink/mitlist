import 'package:flutter/material.dart';
import '../theme/animations.dart';

class BobbingIcon extends StatefulWidget {
  const BobbingIcon({
    super.key,
    required this.child,
    this.amplitude = MitlistAnimations.breatheAmplitude,
  });

  final Widget child;
  final double amplitude;

  @override
  State<BobbingIcon> createState() => _BobbingIconState();
}

class _BobbingIconState extends State<BobbingIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.breatheLoop,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller!, curve: MitlistAnimations.easeBreathe),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (!MediaQuery.of(context).disableAnimations && mounted) {
        _controller?.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation!.value * widget.amplitude),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
