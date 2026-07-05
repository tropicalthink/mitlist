import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';

enum AppCardVariant { elevated, outlined, filled, soft }

enum AppCardTint { neutral, primary, success, warning, error }

enum AppCardPadding { none, sm, md, lg, xl }

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    this.variant = AppCardVariant.elevated,
    this.tint = AppCardTint.neutral,
    this.padding = AppCardPadding.md,
    this.interactive = false,
    this.animated = false,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.child,
    this.semanticLabel,
  });

  final AppCardVariant variant;
  final AppCardTint tint;
  final AppCardPadding padding;
  final bool interactive;
  final bool animated;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Overrides the variant/tint background (e.g. a seeded [ListTileAccent]
  /// pastel) while keeping the border, shadow and press physics.
  final Color? backgroundColor;
  final Widget? child;
  final String? semanticLabel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  bool _didAnimate = false;

  AnimationController? _controller;
  Animation<double>? _opacityAnimation;
  Animation<double>? _translateAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: MitlistAnimations.medium,
      );
      _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller!, curve: MitlistTheme.easeMicro),
      );
      _translateAnimation = Tween<double>(
        begin: MitlistAnimations.cardEnterOffset,
        end: 0,
      ).animate(
        CurvedAnimation(parent: _controller!, curve: MitlistTheme.easeMicro),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animated && !_didAnimate && _controller != null) {
      _didAnimate = true;
      final disableAnimations = MediaQuery.of(context).disableAnimations;
      if (disableAnimations) {
        _controller!.value = 1.0;
      } else {
        _controller!.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Color _backgroundColor(ColorScheme colorScheme) {
    switch (widget.tint) {
      case AppCardTint.neutral:
        switch (widget.variant) {
          case AppCardVariant.elevated:
          case AppCardVariant.outlined:
            return colorScheme.surface;
          case AppCardVariant.filled:
            return colorScheme.surfaceContainerHighest;
          case AppCardVariant.soft:
            return colorScheme.surfaceContainerLow;
        }
      case AppCardTint.primary:
        return colorScheme.primaryContainer;
      case AppCardTint.success:
        return colorScheme.tertiaryContainer;
      case AppCardTint.warning:
        return colorScheme.errorContainer;
      case AppCardTint.error:
        return colorScheme.errorContainer;
    }
  }

  List<BoxShadow> get _defaultShadow {
    switch (widget.variant) {
      case AppCardVariant.elevated:
      case AppCardVariant.soft:
        return MitlistShadows.shadowSoft;
      case AppCardVariant.outlined:
      case AppCardVariant.filled:
        return MitlistShadows.shadowNone;
    }
  }

  List<BoxShadow> get _hoverShadow {
    switch (widget.variant) {
      case AppCardVariant.elevated:
      case AppCardVariant.soft:
        return MitlistShadows.shadowMedium;
      case AppCardVariant.outlined:
      case AppCardVariant.filled:
        return MitlistShadows.shadowSoft;
    }
  }

  EdgeInsetsGeometry get _padding {
    switch (widget.padding) {
      case AppCardPadding.none:
        return const EdgeInsets.all(MitlistSpacing.space0);
      case AppCardPadding.sm:
        return const EdgeInsets.all(MitlistSpacing.sm);
      case AppCardPadding.md:
        return const EdgeInsets.all(MitlistSpacing.md);
      case AppCardPadding.lg:
        return const EdgeInsets.all(MitlistSpacing.lg);
      case AppCardPadding.xl:
        return const EdgeInsets.all(MitlistSpacing.xl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final colorScheme = Theme.of(context).colorScheme;

    final pressOffset = MitlistShadows.shadowSoft[0].offset;
    final hoverOffset = Offset(-pressOffset.dx, -pressOffset.dy);

    final translation = _pressed
        ? pressOffset
        : (_hovered ? hoverOffset : Offset.zero);

    final currentShadow = _pressed
        ? MitlistShadows.shadowNone
        : (_hovered ? _hoverShadow : _defaultShadow);

    Widget card = AnimatedContainer(
      duration: disableAnimations ? Duration.zero : MitlistAnimations.medium,
      curve: MitlistTheme.easeMicro,
      transform: Matrix4.translationValues(translation.dx, translation.dy, 0),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? _backgroundColor(colorScheme),
        border: Border.all(
          color: colorScheme.outline,
          width: pressOffset.dx,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(MitlistTheme.radiusNone),
        ),
        boxShadow: currentShadow,
      ),
      child: Padding(
        padding: _padding,
        child: widget.child,
      ),
    );

    if (widget.interactive) {
      card = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: card,
          ),
        ),
      );
    }

    if (widget.animated && _controller != null) {
      card = AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation!.value,
            child: Transform.translate(
              offset: Offset(0, _translateAnimation!.value),
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }
}
