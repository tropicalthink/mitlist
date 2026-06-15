import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/meal_plan_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../skeleton.dart';

class TonightCard extends ConsumerWidget {
  const TonightCard({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(todayMealPlansProvider(groupId));

    return async.when(
      loading: () => AppSkeleton(width: double.infinity, height: 80),
      error: (_, __) => _EmptyStateCard(),
      data: (meals) {
        if (meals.isEmpty) return _EmptyStateCard();

        // Prefer dinner; fall back to breakfast then lunch then first.
        TodayMeal? selected;
        final slotOrder = ['dinner', 'breakfast', 'lunch'];
        for (final slot in slotOrder) {
          try {
            selected = meals.firstWhere((m) => m.plan.slot == slot);
            break;
          } catch (_) {}
        }
        selected ??= meals.first;

        final plan = selected.plan;
        final recipe = selected.recipe;
        final title = recipe?.title ?? l10n.tonightRecipe;

        final String header;
        switch (plan.slot) {
          case 'breakfast':
            header = l10n.tonightBreakfast;
            break;
          case 'lunch':
            header = l10n.tonightLunch;
            break;
          default:
            header = l10n.tonightHeader;
        }

        final textTheme = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              header,
              style: textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Semantics(
              button: true,
              label: l10n.tonightOpenRecipe(title),
              child: GestureDetector(
                onTap: () => context.pushNamed(
                  'recipeDetail',
                  pathParameters: {'recipeId': plan.recipeId},
                ),
                child: AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppCardPadding.md,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: MitlistSpacing.xs),
                            Text(
                              'serves ${plan.servings}',
                              style: MitlistTypography.monoBody(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      AppButton(
                        text: l10n.tonightCook,
                        size: AppButtonSize.sm,
                        onPressed: () => context.pushNamed(
                          'recipeCook',
                          pathParameters: {'recipeId': plan.recipeId},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.tonightNothingPlanned,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          AppButton(
            text: l10n.tonightPlanDinner,
            variant: AppButtonVariant.outline,
            size: AppButtonSize.sm,
            onPressed: () => context.pushNamed('mealPlan'),
          ),
        ],
      ),
    );
  }
}
