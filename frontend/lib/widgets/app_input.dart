import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';
import '../theme/typography.dart';

enum AppInputVariant { default$, soft, ghost }

enum AppInputSize { sm, md, lg }

class AppInput extends StatefulWidget {
  final AppInputVariant variant;
  final AppInputSize size;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool success;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool clearable;
  final bool enabled;
  final int? maxLength;
  final bool showCharCount;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final Iterable<String>? autofillHints;
  final int? minLines;
  final int? maxLines;

  const AppInput({
    super.key,
    this.variant = AppInputVariant.default$,
    this.size = AppInputSize.md,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.success = false,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.clearable = false,
    this.enabled = true,
    this.maxLength,
    this.showCharCount = false,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofillHints,
    this.minLines,
    this.maxLines,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsController;
  late bool _ownsFocusNode;
  late final AnimationController _shakeController;
  Animation<Offset>? _shakeAnimation;

  bool _focused = false;
  bool _obscure = false;
  bool _wasError = false;

  static const double _iconSize = 20.0;
  static const double _borderWidth = 2.0;
  static const Cubic _easeMicro = Cubic(0.4, 0.0, 0.2, 1.0);

  bool get _hasError =>
      widget.errorText != null && widget.errorText!.isNotEmpty;

  bool get _showCharCount =>
      widget.maxLength != null && widget.showCharCount && widget.maxLength! > 0;

  bool get _showClear =>
      widget.clearable && _controller.text.isNotEmpty && widget.enabled;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _obscure = widget.obscureText;

    _shakeController = AnimationController(
      duration: MitlistAnimations.medium,
      vsync: this,
    );

    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(-4, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-4, 0), end: const Offset(4, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(4, 0), end: const Offset(-3, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(-3, 0), end: const Offset(3, 0)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(3, 0), end: Offset.zero),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);

    _wasError = _hasError;
    if (_hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerShake();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_handleTextChange);
      if (_ownsController) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TextEditingController();
      _ownsController = widget.controller == null;
      _controller.addListener(_handleTextChange);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode.addListener(_handleFocusChange);
      _focused = _focusNode.hasFocus;
    }

    final hasErrorNow = _hasError;
    if (hasErrorNow && !_wasError) {
      _triggerShake();
    }
    _wasError = hasErrorNow;
  }

  void _triggerShake() {
    if (!mounted) return;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (!disableAnimations) {
      _shakeController.forward(from: 0);
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus != _focused) {
      setState(() {
        _focused = _focusNode.hasFocus;
      });
    }
  }

  void _handleTextChange() {
    if (widget.clearable || widget.showCharCount) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleTextChange);
    _shakeController.dispose();

    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    if (_ownsController) {
      _controller.dispose();
    }

    super.dispose();
  }

  double get _height {
    return switch (widget.size) {
      AppInputSize.sm => MitlistSpacing.space9,
      AppInputSize.md => MitlistSpacing.space11,
      AppInputSize.lg => MitlistSpacing.space12 + MitlistSpacing.space1,
    };
  }

  EdgeInsets get _contentPadding {
    final horizontal = switch (widget.size) {
      AppInputSize.sm => MitlistSpacing.space3,
      AppInputSize.md => MitlistSpacing.space4,
      AppInputSize.lg => MitlistSpacing.space5,
    };
    final vertical = switch (widget.size) {
      AppInputSize.sm => MitlistSpacing.sm,
      AppInputSize.md => MitlistSpacing.space3,
      AppInputSize.lg => MitlistSpacing.space4,
    };
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  void _toggleObscure() {
    setState(() {
      _obscure = !_obscure;
    });
  }

  void _clear() {
    _controller.clear();
    // TextField.onChanged only fires for user edits, not programmatic ones,
    // so owners listening via onChanged would keep the stale value.
    widget.onChanged?.call('');
  }

  Widget? _buildSuffixIcon() {
    final List<Widget> suffixes = [];
    final colorScheme = Theme.of(context).colorScheme;
    final icons = colorScheme.onSurface;

    if (_showClear) {
      suffixes.add(
        _SuffixAction(
          onTap: _clear,
          child: Icon(
            Icons.close,
            size: _iconSize,
            color: icons,
          ),
        ),
      );
    }

    if (widget.obscureText) {
      suffixes.add(
        _SuffixAction(
          onTap: _toggleObscure,
          child: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            size: _iconSize,
            color: icons,
          ),
        ),
      );
    }

    if (widget.suffixIcon != null) {
      suffixes.add(
        _SuffixAction(
          child: IconTheme(
            data: IconThemeData(
              size: _iconSize,
              color: icons,
            ),
            child: widget.suffixIcon!,
          ),
        ),
      );
    }

    if (suffixes.isEmpty) return null;
    if (suffixes.length == 1) return suffixes.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: suffixes,
    );
  }

  Widget _buildCharCount() {
    final length = _controller.text.length;
    final max = widget.maxLength!;
    final ratio = length / max;
    final colorScheme = Theme.of(context).colorScheme;

    Color color = colorScheme.onSurfaceVariant;
    if (ratio > 1.0) {
      color = colorScheme.error;
    } else if (ratio > 0.8) {
      color = colorScheme.tertiary;
    }

    return Text(
      '$length/$max',
      style: MitlistTypography.monoBody(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final labelStyle = textTheme.labelMedium?.copyWith(
      color: _hasError ? colorScheme.error : null,
    );

    Color backgroundColor;
    if (!widget.enabled) {
      backgroundColor = colorScheme.surfaceContainerHighest;
    } else if (_hasError) {
      backgroundColor = colorScheme.errorContainer;
    } else if (widget.success) {
      backgroundColor = colorScheme.tertiaryContainer;
    } else {
      backgroundColor = switch (widget.variant) {
        AppInputVariant.default$ => colorScheme.surface,
        AppInputVariant.soft => colorScheme.surfaceContainerLow,
        AppInputVariant.ghost => Colors.transparent,
      };
    }

    Color borderColor;
    if (!widget.enabled) {
      borderColor = colorScheme.outline;
    } else if (_hasError) {
      borderColor = colorScheme.error;
    } else if (widget.success) {
      borderColor = colorScheme.tertiary;
    } else if (_focused) {
      borderColor = colorScheme.primary;
    } else {
      borderColor = colorScheme.outline;
    }

    List<BoxShadow> boxShadow;
    if (!widget.enabled) {
      boxShadow = MitlistShadows.shadowNone;
    } else if (_focused) {
      boxShadow = MitlistShadows.shadowNone;
    } else {
      boxShadow = switch (widget.variant) {
        AppInputVariant.default$ => MitlistShadows.shadowSoft,
        AppInputVariant.soft => MitlistShadows.shadowSoft,
        AppInputVariant.ghost => MitlistShadows.shadowNone,
      };
    }

    Color textColor =
        widget.enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant;

    Color hintColor = colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        return Transform.translate(
          offset: _shakeAnimation?.value ?? Offset.zero,
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            ExcludeSemantics(
              child: Text(
                widget.label!.toUpperCase(),
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
          ],
          AnimatedContainer(
            duration: MitlistAnimations.medium,
            curve: _easeMicro,
            transform: _focused
                ? Matrix4.translationValues(2, 2, 0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              boxShadow: boxShadow,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: _height,
                maxHeight: widget.minLines != null || widget.maxLines != null
                    ? double.infinity
                    : _height,
              ),
              child: Semantics(
                label: widget.label,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  obscureText: _obscure,
                  enabled: widget.enabled,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  maxLength: widget.maxLength,
                  minLines: widget.minLines,
                  maxLines: (widget.minLines != null || widget.maxLines != null)
                      ? widget.maxLines
                      : 1,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  onEditingComplete: widget.onEditingComplete,
                  autofillHints: widget.autofillHints,
                  style: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusNone),
                      borderSide: BorderSide(
                        color: borderColor,
                        width: _borderWidth,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusNone),
                      borderSide: BorderSide(
                        color: borderColor,
                        width: _borderWidth,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusNone),
                      borderSide: BorderSide(
                        color: _hasError
                            ? colorScheme.error
                            : widget.success
                                ? colorScheme.tertiary
                                : colorScheme.primary,
                        width: _borderWidth,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusNone),
                      borderSide: BorderSide(
                        color: colorScheme.outline,
                        width: _borderWidth,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusNone),
                      borderSide: BorderSide(
                        color: colorScheme.error,
                        width: _borderWidth,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusNone),
                      borderSide: BorderSide(
                        color: colorScheme.error,
                        width: _borderWidth,
                      ),
                    ),
                    contentPadding: _contentPadding,
                    prefixIcon: widget.prefixIcon != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MitlistSpacing.sm,
                            ),
                            child: SizedBox(
                              width: _iconSize,
                              height: _iconSize,
                              child: Center(
                                child: IconTheme(
                                  data: IconThemeData(
                                    size: _iconSize,
                                    color: colorScheme.onSurface,
                                  ),
                                  child: widget.prefixIcon!,
                                ),
                              ),
                            ),
                          )
                        : null,
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    suffixIcon: _buildSuffixIcon(),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    hintText: widget.hint,
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: hintColor,
                    ),
                    counterText: '',
                  ),
                ),
              ),
            ),
          ),
          if (widget.helperText != null ||
              widget.errorText != null ||
              _showCharCount) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: widget.errorText != null || widget.helperText != null
                      ? Text(
                          widget.errorText ?? widget.helperText ?? '',
                          style: textTheme.bodySmall?.copyWith(
                            color: _hasError
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            fontWeight: _hasError ? FontWeight.w700 : null,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_showCharCount) _buildCharCount(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SuffixAction extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _SuffixAction({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: child),
      ),
    );
  }
}
