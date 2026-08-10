import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../skeleton.dart';

/// Loading placeholder for the list detail screen — eight shimmer rows that
/// echo the checkbox + label layout of [ListItemRow].
///
/// Scrolling is owned by the screen's refresh wrapper. Keeping this widget
/// non-scrollable avoids nesting a vertical viewport in an unbounded
/// [SingleChildScrollView] during initial loading.
class ListDetailSkeleton extends StatelessWidget {
  const ListDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Column(
        children: List.generate(
          8,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
              vertical: MitlistSpacing.sm,
            ),
            child: Row(
              children: [
                const AppSkeleton(width: 24, height: 24),
                const SizedBox(width: MitlistSpacing.md),
                const Expanded(
                  child: AppSkeleton(
                    width: double.infinity,
                    height: MitlistSpacing.space4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
