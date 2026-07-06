import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';

enum AppAlertType { info, success, warning, error }

class AppAlert extends StatefulWidget {
  final AppAlertType type;
  final String message;
  final Widget? icon;

  const AppAlert({
    super.key,
    required this.type,
    required this.message,
    this.icon,
  });

  @override
  State<AppAlert> createState() => _AppAlertState();
}

class _AppAlertState extends State<AppAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.micro,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({Color bg, Color text, Color iconColor}) _resolveColors(
      BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.type) {
      case AppAlertType.info:
        return (
          bg: colorScheme.primaryContainer,
          text: colorScheme.primary,
          iconColor: colorScheme.primary,
        );
      case AppAlertType.success:
        return (
          bg: colorScheme.tertiaryContainer,
          text: colorScheme.tertiary,
          iconColor: colorScheme.tertiary,
        );
      case AppAlertType.warning:
        return (
          bg: colorScheme.secondaryContainer,
          text: colorScheme.secondary,
          iconColor: colorScheme.secondary,
        );
      case AppAlertType.error:
        return (
          bg: colorScheme.errorContainer,
          text: colorScheme.error,
          iconColor: colorScheme.error,
        );
    }
  }

  Widget _defaultIcon(Color color) {
    switch (widget.type) {
      case AppAlertType.info:
        return Icon(Icons.info_outline, size: 20, color: color);
      case AppAlertType.success:
        return Icon(Icons.check_circle_outline, size: 20, color: color);
      case AppAlertType.warning:
        return Icon(Icons.warning_amber_rounded, size: 20, color: color);
      case AppAlertType.error:
        return Icon(Icons.error_outline, size: 20, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context);
    final colorScheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final alert = Container(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border.fromBorderSide(
          BorderSide(color: colorScheme.outline, width: 2),
        ),
        borderRadius: const BorderRadius.all(
          Radius.circular(MitlistTheme.radiusMd),
        ),
        boxShadow: MitlistShadows.shadowSoft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          widget.icon ?? _defaultIcon(colors.iconColor),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              widget.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );

    if (disableAnimations) {
      return alert;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _slide.value,
            child: alert,
          ),
        );
      },
    );
  }
}
