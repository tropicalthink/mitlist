import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';

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
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: isError ? MitlistColors.error50 : MitlistColors.surfacePrimary,
        border: const Border.fromBorderSide(
          BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        boxShadow: MitlistShadows.shadowSoft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lottieAsset != null)
            Lottie.asset(
              lottieAsset!,
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            )
          else if (icon != null)
            IconTheme(
              data: IconThemeData(
                size: 56,
                color: iconColor ?? MitlistColors.textTertiary,
              ),
              child: icon!,
            ),
          if ((lottieAsset != null || icon != null) &&
              (title.isNotEmpty || description != null))
            const SizedBox(height: MitlistSpacing.md),
          if (title.isNotEmpty)
            Text(
              title.toUpperCase(),
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
