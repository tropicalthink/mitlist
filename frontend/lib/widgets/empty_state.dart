import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import 'bobbing_icon.dart';

enum AppEmptyStatePadding {
  sm,
  md,
  lg,
}

class AppEmptyState extends StatelessWidget {
  final Widget? icon;
  final String? lottieAsset;
  final Color? iconColor;
  final String title;
  final String? description;
  final List<Widget>? actions;
  final bool isError;
  final AppEmptyStatePadding paddingPreset;
  final bool animatedIcon;

  const AppEmptyState({
    super.key,
    this.icon,
    this.lottieAsset,
    this.iconColor,
    required this.title,
    this.description,
    this.actions,
    this.isError = false,
    this.paddingPreset = AppEmptyStatePadding.lg,
    this.animatedIcon = false,
  });

  EdgeInsetsGeometry get _padding {
    switch (paddingPreset) {
      case AppEmptyStatePadding.sm:
        return const EdgeInsets.symmetric(
          vertical: MitlistSpacing.space8,
          horizontal: MitlistSpacing.md,
        );
      case AppEmptyStatePadding.md:
        return const EdgeInsets.symmetric(
          vertical: MitlistSpacing.space12,
          horizontal: MitlistSpacing.md,
        );
      case AppEmptyStatePadding.lg:
        return const EdgeInsets.symmetric(
          vertical: MitlistSpacing.space16,
          horizontal: MitlistSpacing.md,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Future<LottieComposition?> dotLottieDecoder(List<int> bytes) {
      return LottieComposition.decodeZip(
        bytes,
        filePicker: (files) {
          for (final f in files) {
            if (f.name.startsWith('animations/') && f.name.endsWith('.json')) {
              return f;
            }
          }
          return null;
        },
      );
    }

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: isError ? colorScheme.errorContainer : colorScheme.surface,
        border: Border.fromBorderSide(
          BorderSide(color: colorScheme.outline, width: 2),
        ),
        boxShadow: MitlistShadows.shadowSoft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lottieAsset != null)
            Lottie.asset(
              lottieAsset!,
              decoder: lottieAsset!.toLowerCase().endsWith('.lottie')
                  ? dotLottieDecoder
                  : null,
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            )
          else if (icon != null && animatedIcon)
            BobbingIcon(
              child: IconTheme(
                data: IconThemeData(
                  size: 56,
                  color: iconColor ?? colorScheme.onSurfaceVariant,
                ),
                child: icon!,
              ),
            )
          else if (icon != null)
            IconTheme(
              data: IconThemeData(
                size: 56,
                color: iconColor ?? colorScheme.onSurfaceVariant,
              ),
              child: icon!,
            ),
          if ((lottieAsset != null || icon != null) &&
              (title.isNotEmpty || description != null))
            const SizedBox(height: MitlistSpacing.md),
          if (title.isNotEmpty)
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          if (description != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.md),
            Wrap(
              spacing: MitlistSpacing.space3,
              runSpacing: MitlistSpacing.sm,
              alignment: WrapAlignment.center,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}
