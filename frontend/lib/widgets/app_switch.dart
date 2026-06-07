import 'package:flutter/material.dart';
import '../theme/spacing.dart';

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  const AppSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget switchWidget = SizedBox(
      height: MitlistSpacing.space11,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        activeThumbColor: colorScheme.onPrimary,
        inactiveThumbColor: colorScheme.onSurfaceVariant,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );

    if (label != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              label!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          switchWidget,
        ],
      );
    }

    return switchWidget;
  }
}

class AppSwitchListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: textTheme.bodyMedium),
              if (subtitle != null) ...[
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        AppSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
