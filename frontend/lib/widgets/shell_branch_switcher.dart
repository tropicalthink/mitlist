import 'package:flutter/material.dart';

import '../theme/animations.dart';

/// Gives the bottom-nav shell a sense of direction.
///
/// `StatefulShellRoute.indexedStack` swaps branches with a hard cut, so moving
/// between tabs reads as the screen being replaced rather than the user
/// travelling somewhere. This slides the arriving branch in from the side it
/// came from — right-to-left when moving forward through the tabs, the
/// reverse when moving back — so the nav bar's slab and the content agree
/// about which way the user just went.
///
/// The outgoing branch is not animated: [child] is the shell's own
/// [IndexedStack], which has already switched by the time this rebuilds.
/// Animating an incoming-only reveal keeps every branch's scroll position and
/// state intact, which a crossfade of two shell copies would not.
///
/// Respects [MediaQueryData.disableAnimations]: the branch appears instantly.
class ShellBranchSwitcher extends StatefulWidget {
  const ShellBranchSwitcher({
    super.key,
    required this.index,
    required this.child,
    this.animate = true,
  });

  /// Currently selected branch. A change drives the transition.
  final int index;

  final Widget child;

  /// False while the shell restores the tab the user left on at launch. That
  /// branch should already be there when the app appears rather than sliding
  /// in, which would turn a cold start into a performance.
  final bool animate;

  /// How far the arriving branch travels, in logical pixels. Small on purpose:
  /// users are mid-task, not watching a page load.
  static const double travel = 24;

  @override
  State<ShellBranchSwitcher> createState() => _ShellBranchSwitcherState();
}

class _ShellBranchSwitcherState extends State<ShellBranchSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MitlistAnimations.navBranch,
    value: 1,
  );

  /// +1 when moving to a later tab, -1 when moving back.
  int _direction = 1;

  @override
  void didUpdateWidget(ShellBranchSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    if (!widget.animate) {
      _controller.value = 1;
      return;
    }
    _direction = widget.index > oldWidget.index ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No controller mutation here: driving it from build would notify
    // listeners mid-frame. didUpdateWidget already owns every reset.
    if (MediaQuery.of(context).disableAnimations || !widget.animate) {
      return widget.child;
    }

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final sign = (isRtl ? -1 : 1) * _direction;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = MitlistAnimations.easeEnter.transform(_controller.value);
        if (t == 1) return child!;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(sign * ShellBranchSwitcher.travel * (1 - t), 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
