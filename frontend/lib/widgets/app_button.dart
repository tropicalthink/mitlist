import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';
import 'app_icon.dart';

enum AppButtonVariant { solid, outline, ghost, soft }

enum AppButtonColor { primary, success, warning, error, neutral }

enum AppButtonSize { xs, sm, md, lg, xl }

class AppButton extends StatefulWidget {
  final AppButtonVariant variant;
  final AppButtonColor color;
  final AppButtonSize size;
  final String? text;
  final Widget? icon;
  final Widget? suffixIcon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSuccess;
  final String? tooltip;
  final String? semanticLabel;

  const AppButton({
    super.key,
    this.variant = AppButtonVariant.solid,
    this.color = AppButtonColor.primary,
    this.size = AppButtonSize.md,
    this.text,
    this.icon,
    this.suffixIcon,
    this.onPressed,
    this.isLoading = false,
    this.isSuccess = false,
    this.tooltip,
    this.semanticLabel,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _isDisabled => widget.onPressed == null;

  bool get _isInteractive =>
      widget.onPressed != null && !widget.isLoading && !widget.isSuccess;

  static final Matrix4 _identity = Matrix4.identity();
  static final Matrix4 _pressedTransform = Matrix4.translationValues(
    MitlistSpacing.space1 / 2,
    MitlistSpacing.space1 / 2,
    0,
  );

  Color _backgroundColor(ColorScheme colorScheme) {
    switch (widget.variant) {
      case AppButtonVariant.solid:
        if (widget.isSuccess) return MitlistColors.success500;
        switch (widget.color) {
          case AppButtonColor.primary:
            return colorScheme.primary;
          case AppButtonColor.success:
            return colorScheme.tertiary;
          case AppButtonColor.warning:
            return colorScheme.error;
          case AppButtonColor.error:
            return colorScheme.error;
          case AppButtonColor.neutral:
            return colorScheme.surfaceContainerHighest;
        }
      case AppButtonVariant.outline:
        return colorScheme.surface;
      case AppButtonVariant.ghost:
        return Colors.transparent;
      case AppButtonVariant.soft:
        switch (widget.color) {
          case AppButtonColor.primary:
            return colorScheme.primaryContainer;
          case AppButtonColor.success:
            return colorScheme.tertiaryContainer;
          case AppButtonColor.warning:
            return colorScheme.errorContainer;
          case AppButtonColor.error:
            return colorScheme.errorContainer;
          case AppButtonColor.neutral:
            return colorScheme.surfaceContainerHigh;
        }
    }
  }

  Color _foregroundColor(ColorScheme colorScheme) {
    switch (widget.variant) {
      case AppButtonVariant.solid:
        return colorScheme
            .onPrimary; // white works for both primary and success500
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        switch (widget.color) {
          case AppButtonColor.primary:
            return colorScheme.primary;
          case AppButtonColor.success:
            return colorScheme.tertiary;
          case AppButtonColor.warning:
            return colorScheme.error;
          case AppButtonColor.error:
            return colorScheme.error;
          case AppButtonColor.neutral:
            return colorScheme.onSurfaceVariant;
        }
      case AppButtonVariant.soft:
        switch (widget.color) {
          case AppButtonColor.primary:
            return colorScheme.onPrimaryContainer;
          case AppButtonColor.success:
            return colorScheme.onTertiaryContainer;
          case AppButtonColor.warning:
            return colorScheme.onErrorContainer;
          case AppButtonColor.error:
            return colorScheme.onErrorContainer;
          case AppButtonColor.neutral:
            return colorScheme.onSurfaceVariant;
        }
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case AppButtonSize.xs:
        return const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.space2,
          vertical: MitlistSpacing.space1,
        );
      case AppButtonSize.sm:
        return const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.space3,
          vertical: MitlistSpacing.space2,
        );
      case AppButtonSize.md:
        return const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.space4,
          vertical: MitlistSpacing.space2,
        );
      case AppButtonSize.lg:
        return const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.space6,
          vertical: MitlistSpacing.space3,
        );
      case AppButtonSize.xl:
        return const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.space8,
          vertical: MitlistSpacing.space4,
        );
    }
  }

  String? get _displayText {
    if (widget.text == null) return null;
    if (widget.variant == AppButtonVariant.solid ||
        widget.variant == AppButtonVariant.outline) {
      return widget.text!.toUpperCase();
    }
    return widget.text;
  }

  List<BoxShadow> get _shadow {
    if (_isDisabled || _pressed) {
      return MitlistShadows.shadowNone;
    }
    if (widget.variant == AppButtonVariant.ghost) {
      return MitlistShadows.shadowNone;
    }
    return MitlistShadows.shadowSoft;
  }

  BoxBorder? _border(ColorScheme colorScheme) {
    if (widget.variant == AppButtonVariant.ghost) {
      return null;
    }
    return Border.all(
      color: colorScheme.outline,
      width: MitlistSpacing.space1 / 2,
    );
  }

  Widget _buildLeading(Color foreground, Duration duration) {
    Widget current;
    if (widget.isLoading) {
      current = SizedBox(
        key: const ValueKey('loading'),
        width: MitlistSpacing.space4,
        height: MitlistSpacing.space4,
        child: CircularProgressIndicator(
          strokeWidth: MitlistSpacing.space1 / 2,
          valueColor: AlwaysStoppedAnimation<Color>(foreground),
        ),
      );
    } else if (widget.isSuccess) {
      current = AppIcon(
        key: const ValueKey('success'),
        name: 'check',
        size: MitlistSpacing.space5,
        color: foreground,
      );
    } else if (widget.icon != null) {
      current = IconTheme(
        key: const ValueKey('icon'),
        data: IconThemeData(color: foreground, size: MitlistSpacing.space5),
        child: widget.icon!,
      );
    } else {
      current = const SizedBox.shrink(key: ValueKey('empty'));
    }

    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        if (child.key == const ValueKey('loading')) {
          return FadeTransition(opacity: animation, child: child);
        }
        if (child.key == const ValueKey('success')) {
          // Gentle settle with a slight overshoot — feels satisfying, not bouncy.
          final curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.34, 1.15, 0.64, 1.0),
          );
          return ScaleTransition(scale: curved, child: child);
        }
        return ScaleTransition(scale: animation, child: child);
      },
      child: current,
    );
  }

  Widget _buildLeadingWithGap(Color foreground, Duration duration) {
    final bool hasVisible =
        widget.isLoading || widget.isSuccess || widget.icon != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLeading(foreground, duration),
        if (hasVisible && (widget.text != null || widget.suffixIcon != null))
          const SizedBox(width: MitlistSpacing.space2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = _foregroundColor(colorScheme);
    final background = _backgroundColor(colorScheme);
    final padding = _padding;
    final border = _border(colorScheme);
    final shadow = _shadow;
    final transform = _pressed ? _pressedTransform : _identity;

    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final animationDuration =
        disableAnimations ? Duration.zero : MitlistAnimations.micro;
    // Slower color transition when success fires so the green reads clearly.
    final containerDuration = disableAnimations
        ? Duration.zero
        : widget.isSuccess
            ? MitlistAnimations.medium
            : MitlistAnimations.micro;

    final textStyle =
        Theme.of(context).textTheme.labelLarge!.copyWith(color: foreground);

    // Use a longer switcher duration for the success check entrance.
    final switcherDuration = disableAnimations
        ? Duration.zero
        : widget.isSuccess
            ? MitlistAnimations.medium
            : animationDuration;

    final List<Widget> rowChildren = [
      _buildLeadingWithGap(foreground, switcherDuration),
    ];

    if (widget.text != null) {
      // Flexible so a long label (translations, large system fonts) wraps
      // inside the border instead of spilling past it. Two lines keep the
      // whole label readable; an ellipsis only appears beyond that.
      rowChildren.add(
        Flexible(
          child: Text(
            _displayText!,
            style: textStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      if (widget.suffixIcon != null) {
        rowChildren.add(const SizedBox(width: MitlistSpacing.space2));
      }
    }

    if (widget.suffixIcon != null) {
      rowChildren.add(
        IconTheme(
          data: IconThemeData(color: foreground, size: MitlistSpacing.space5),
          child: widget.suffixIcon!,
        ),
      );
    }

    Widget button = AnimatedContainer(
      duration: containerDuration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: background,
        border: border,
        borderRadius: BorderRadius.circular(MitlistTheme.radiusNone),
        boxShadow: shadow,
      ),
      transform: transform,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: MitlistSpacing.space11,
          minHeight: MitlistSpacing.space11,
        ),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowChildren,
          ),
        ),
      ),
    );

    if (_isDisabled) {
      button = Opacity(
        opacity: 0.5,
        child: button,
      );
    }

    Widget result = Listener(
      onPointerDown:
          _isInteractive ? (_) => setState(() => _pressed = true) : null,
      onPointerUp:
          _isInteractive ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel:
          _isInteractive ? (_) => setState(() => _pressed = false) : null,
      child: GestureDetector(
        onTap: _isInteractive ? widget.onPressed : null,
        behavior: HitTestBehavior.translucent,
        child: button,
      ),
    );

    final bool isIconOnly = widget.text == null;
    final effectiveTooltip =
        widget.tooltip ?? (isIconOnly ? widget.semanticLabel : null);

    if (isIconOnly) {
      result = Semantics(
        button: true,
        label: effectiveTooltip,
        child: result,
      );
    }

    if (effectiveTooltip != null && effectiveTooltip.isNotEmpty) {
      result = Tooltip(
        message: effectiveTooltip,
        child: result,
      );
    }

    return result;
  }
}
