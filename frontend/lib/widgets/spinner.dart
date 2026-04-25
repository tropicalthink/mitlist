import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum AppSpinnerSize { sm, md, lg }

class AppSpinner extends StatelessWidget {
  final AppSpinnerSize size;
  final Color? color;

  const AppSpinner({
    super.key,
    this.size = AppSpinnerSize.md,
    this.color,
  });

  double get _dimension {
    switch (size) {
      case AppSpinnerSize.sm:
        return 16;
      case AppSpinnerSize.md:
        return 24;
      case AppSpinnerSize.lg:
        return 32;
    }
  }

  double get _strokeWidth {
    switch (size) {
      case AppSpinnerSize.sm:
        return 2;
      case AppSpinnerSize.md:
        return 2.5;
      case AppSpinnerSize.lg:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _dimension,
      height: _dimension,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? MitlistColors.textPrimary,
        ),
      ),
    );
  }
}
