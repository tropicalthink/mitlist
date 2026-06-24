import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../skeleton.dart';

/// Loading placeholder for the list detail screen — eight shimmer rows that
/// echo the checkbox + label layout of [ListItemRow].
class ListDetailSkeleton extends StatelessWidget {
  const ListDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              const AppSkeleton(width: 24, height: 24),
              const SizedBox(width: MitlistSpacing.md),
              Expanded(
                child: AppSkeleton(
                  width: double.infinity,
                  height: MitlistSpacing.space4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
