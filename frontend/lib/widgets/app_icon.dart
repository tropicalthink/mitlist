import 'package:flutter/material.dart';
import 'icons.dart';

/// A widget that renders an icon by semantic name.
///
/// Currently uses Material [IconData] placeholders via [AppIcons].
/// When SVG assets are added, this widget can be updated to render
/// [SvgPicture] without changing the public API.
class AppIcon extends StatelessWidget {
  /// Semantic icon name (e.g. `'plus'`, `'trash'`).
  final String name;

  /// Icon size in logical pixels. Defaults to `20`.
  final double size;

  /// Icon color. Defaults to [Theme.of(context).colorScheme.onSurface].
  final Color? color;

  const AppIcon({
    super.key,
    required this.name,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = AppIcons.resolve(name);

    if (iconData == null) {
      // Return an empty box so layouts don't break for unknown names.
      return SizedBox(width: size, height: size);
    }

    return Icon(
      iconData,
      size: size,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}
