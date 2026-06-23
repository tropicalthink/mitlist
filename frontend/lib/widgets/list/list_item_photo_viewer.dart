import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_icon.dart';

/// Fullscreen, pinch-to-zoom viewer for a list item photo.
class ListItemPhotoViewer {
  const ListItemPhotoViewer._();

  static Future<void> show(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Semantics(
                  label: AppLocalizations.of(ctx)!.listDetailListImage,
                  child: Image.network(url,
                      fit: BoxFit.contain,
                      cacheWidth: (MediaQuery.sizeOf(ctx).width *
                              MediaQuery.devicePixelRatioOf(ctx) *
                              1.5)
                          .round(),
                      errorBuilder: (_, __, ___) => Center(
                            child: AppIcon(
                                name: 'brokenImage',
                                color: Theme.of(ctx).colorScheme.onSurface,
                                size: 48),
                          )),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: AppIcon(
                      name: 'xMark',
                      color: Theme.of(ctx).colorScheme.onSurface),
                  tooltip: AppLocalizations.of(ctx)!.commonClose,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
