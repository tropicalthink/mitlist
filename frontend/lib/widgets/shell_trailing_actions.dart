import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/notification_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import 'app_icon.dart';

/// Trailing [IconButton]s shared across primary shell tabs so the top bar
/// stays predictable next to the bottom navigation.
///
/// Intentionally kept to two icons — screens often add their own actions, so
/// three shell icons quickly crowds the bar. Calendar is available from the
/// Home hub; notifications and account cover the time-sensitive cases.
List<Widget> shellTrailingActions(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    _NotificationAction(tooltip: l10n.shellNotifications),
    IconButton(
      tooltip: l10n.shellAccount,
      icon: const AppIcon(name: 'userCircle'),
      onPressed: () => context.pushNamed('you'),
    ),
  ];
}

class _NotificationAction extends ConsumerWidget {
  const _NotificationAction({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    return IconButton(
      tooltip: count > 0 ? '$tooltip ($count)' : tooltip,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const AppIcon(name: 'bellOutline'),
          if (count > 0)
            Positioned(
              top: -MitlistSpacing.space1,
              right: -MitlistSpacing.space1,
              child: Container(
                constraints: const BoxConstraints(minWidth: MitlistSpacing.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.space0_5,
                ),
                color: MitlistColors.error600,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MitlistColors.textOnError,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
        ],
      ),
      onPressed: () => context.pushNamed('notifications'),
    );
  }
}
