import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/animations.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';

class AnimatedCheckToggle extends StatefulWidget {
  const AnimatedCheckToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 24.0,
    this.semanticLabelOn,
    this.semanticLabelOff,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final String? semanticLabelOn;
  final String? semanticLabelOff;

  @override
  State<AnimatedCheckToggle> createState() => _AnimatedCheckToggleState();
}

class _AnimatedCheckToggleState extends State<AnimatedCheckToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.checkToggle,
    );
    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedCheckToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final colorScheme = Theme.of(context).colorScheme;
    final progress =
        disableAnimations ? (widget.value ? 1.0 : 0.0) : _controller.value;
    final isInteractive = widget.onChanged != null;
    final bgColor =
        _lerpColor(colorScheme.surface, colorScheme.primary, progress);
    final borderColor =
        _lerpColor(colorScheme.outline, colorScheme.primary, progress);

    final label = widget.value
        ? (widget.semanticLabelOn ?? l10n.checkToggleChecked)
        : (widget.semanticLabelOff ?? l10n.checkToggleNotChecked);

    Widget toggle = SizedBox(
      width: MitlistSpacing.space11,
      height: MitlistSpacing.space11,
      child: GestureDetector(
        onTap: isInteractive ? () => widget.onChanged!(!widget.value) : null,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.zero,
              boxShadow: progress > 0.5
                  ? MitlistShadows.shadowSoft
                  : MitlistShadows.shadowNone,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.4 + (t * 0.6).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.check,
                      size: widget.size * 0.62,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    toggle = Semantics(
      checked: widget.value,
      button: isInteractive,
      label: label,
      child: toggle,
    );

    if (isInteractive && label.isNotEmpty) {
      toggle = Tooltip(message: label, child: toggle);
    }

    return toggle;
  }
}
