import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../app_card.dart';
import '../skeleton.dart';

class HubSkeleton extends StatelessWidget {
  const HubSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const AppSkeleton(width: 140, height: 16),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              const [
                SizedBox(height: MitlistSpacing.md),
                AppCard(
                  variant: AppCardVariant.filled,
                  tint: AppCardTint.primary,
                  padding: AppCardPadding.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 200, height: 14),
                      SizedBox(height: MitlistSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppSkeleton(width: 60, height: 40),
                          ),
                          SizedBox(width: MitlistSpacing.sm),
                          Expanded(
                            child: AppSkeleton(width: 60, height: 40),
                          ),
                          SizedBox(width: MitlistSpacing.sm),
                          Expanded(
                            child: AppSkeleton(width: 60, height: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: MitlistSpacing.lg),
                AppSkeleton(width: 120, height: 16),
                SizedBox(height: MitlistSpacing.sm),
                AppSkeleton(width: double.infinity, height: 200),
                SizedBox(height: MitlistSpacing.lg),
                AppSkeleton(width: 120, height: 16),
                SizedBox(height: MitlistSpacing.sm),
                AppCard(
                  padding: AppCardPadding.md,
                  child: Column(
                    children: [
                      AppSkeleton(width: double.infinity, height: 44),
                      SizedBox(height: MitlistSpacing.sm),
                      AppSkeleton(width: double.infinity, height: 44),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
