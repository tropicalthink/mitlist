import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/activity_models.dart';
import '../../theme/spacing.dart';
import '../../utils/hub_helpers.dart';
import '../alert.dart';

class ActivityWall extends StatelessWidget {
  const ActivityWall({
    super.key,
    required this.activities,
    required this.activityError,
    this.currentUserId,
  });

  final List<ActivityLogModel> activities;
  final bool activityError;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.hubActivityTitle,
                style: textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        if (activityError)
          AppAlert(
            type: AppAlertType.error,
            message: l10n.hubActivityError,
          )
        else if (activities.isEmpty)
          Text(
            l10n.hubActivityEmpty,
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outline, width: 2),
            ),
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              children: [
                for (var i = 0; i < activities.take(5).length; i++) ...[
                  if (i > 0) const SizedBox(height: MitlistSpacing.sm),
                  _WallItem(item: activities[i], currentUserId: currentUserId),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _WallItem extends StatelessWidget {
  const _WallItem({required this.item, this.currentUserId});

  final ActivityLogModel item;
  final String? currentUserId;

  void _onTap(BuildContext context) {
    final entityType = item.entityType;
    final entityId = item.entityId;

    switch (entityType) {
      case 'list':
        context.pushNamed('listDetail',
            pathParameters: {'listId': entityId});
      case 'expense':
        context.pushNamed('money');
      case 'chore':
        context.pushNamed('chores');
      case 'recipe':
        context.pushNamed('recipes');
      case 'meal_plan':
        context.pushNamed('mealPlan', extra: item.groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final userLabel = formatUserLabel(item.userId ?? '', currentUserId, l10n,
        name: item.userName);
    final when = relativeDay(item.createdAt);
    final message = formatActivityLine(item, l10n);
    final tappable = isNavigableAction(item.entityType);

    return InkWell(
      onTap: tappable ? () => _onTap(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              alignment: Alignment.center,
              child: Text(
                avatarInitials(userLabel),
                style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$userLabel \u00b7 $when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.xs),
                  Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
