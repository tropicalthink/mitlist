import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';

class AppDropdown<T> extends StatefulWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final String? helperText;

  const AppDropdown({
    super.key,
    this.label,
    this.hint,
    this.value,
    this.items,
    this.onChanged,
    this.errorText,
    this.helperText,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  static const double _borderWidth = 2.0;
  static const Cubic _easeMicro = Cubic(0.4, 0.0, 0.2, 1.0);

  bool get _hasError =>
      widget.errorText != null && widget.errorText!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus != _focused) {
      setState(() {
        _focused = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final labelStyle = textTheme.labelMedium?.copyWith(
      color: _hasError ? colorScheme.error : null,
    );

    Color backgroundColor = _hasError
        ? colorScheme.errorContainer
        : colorScheme.surface;

    Color borderColor;
    if (_hasError) {
      borderColor = colorScheme.error;
    } else if (_focused) {
      borderColor = colorScheme.primary;
    } else {
      borderColor = colorScheme.outline;
    }

    final boxShadow =
        _focused ? MitlistShadows.shadowNone : MitlistShadows.shadowSoft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          ExcludeSemantics(
            child: Text(
              widget.label!.toUpperCase(),
              style: labelStyle,
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
            constraints: const BoxConstraints(
              minHeight: MitlistSpacing.space11,
            ),
            child: DropdownButtonFormField<T>(
              focusNode: _focusNode,
              initialValue: widget.value,
              items: widget.items,
              onChanged: widget.onChanged,
              hint: widget.hint != null ? Text(widget.hint!) : null,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: backgroundColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.space4,
                  vertical: MitlistSpacing.space3,
                ),
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
                    color: _hasError ? colorScheme.error : colorScheme.primary,
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
              ),
            ),
          ),
        ),
        if (widget.helperText != null || widget.errorText != null) ...[
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            widget.errorText ?? widget.helperText ?? '',
            style: textTheme.bodySmall?.copyWith(
              color: _hasError
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              fontWeight: _hasError ? FontWeight.w700 : null,
            ),
          ),
        ],
      ],
    );
  }
}
