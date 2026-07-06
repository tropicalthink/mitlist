import 'package:flutter/material.dart';
import '../theme/animations.dart';

/// Staggered fade/slide entrance for list items. Skipped when animations are
/// disabled or for items beyond the first [maxAnimatedItems].
class ListEntrance extends StatefulWidget {
  static const int maxAnimatedItems = 12;

  final int index;
  final Widget child;

  const ListEntrance({super.key, required this.index, required this.child});

  @override
  State<ListEntrance> createState() => _ListEntranceState();
}

class _ListEntranceState extends State<ListEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    if (widget.index >= ListEntrance.maxAnimatedItems) return;
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.entrance,
    );
    final start =
        (widget.index * MitlistAnimations.staggerOffset.inMilliseconds) /
            MitlistAnimations.entrance.inMilliseconds;
    final curved = CurvedAnimation(
      parent: _controller!,
      curve: Interval(start.clamp(0.0, 1.0), 1.0,
          curve: MitlistAnimations.easeEnter),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(curved);
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index >= ListEntrance.maxAnimatedItems ||
        MediaQuery.disableAnimationsOf(context) ||
        _controller == null) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fade!,
      child: SlideTransition(
        position: _slide!,
        child: widget.child,
      ),
    );
  }
}
