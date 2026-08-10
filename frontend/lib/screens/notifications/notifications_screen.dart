import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/group_models.dart';
import '../../models/notification_models.dart';
import '../../providers/notification_provider.dart';
import '../../providers/list_provider.dart' show sseServiceProvider;
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../services/sse_service.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/latest_request_guard.dart';
import '../../utils/notification_navigation.dart';
import '../../providers/group_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';
import '../../l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

/// A flattened feed row: either a day-section header or a notification.
class _FeedEntry {
  const _FeedEntry.header(this.header) : notification = null;
  const _FeedEntry.item(this.notification) : header = null;
  final String? header;
  final NotificationModel? notification;
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const int _pageLimit = 50;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasHousehold = true;
  bool _isMutating = false;
  String? _error;
  final List<NotificationModel> _items = [];
  final ScrollController _scrollController = ScrollController();
  final LatestRequestGuard _loadGuard = LatestRequestGuard();
  final LatestRequestGuard _pageGuard = LatestRequestGuard();
  StreamSubscription<SseEvent>? _sseSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Schedule _load after the first frame so inherited widgets (localizations)
    // are available. Calling AppLocalizations.of(context) inside initState
    // synchronously violates the inherited-widget dependency rule.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _loadGuard.dispose();
    _pageGuard.dispose();
    _sseSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureLiveUpdates(List<Group> groups) {
    if (_sseSub != null) return; // already wired
    final gid = resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    if (!isValidGroupId(gid)) return;
    final sse = ref.read(sseServiceProvider);
    sse.connect(gid!); // idempotent; no-op if already connected to this group
    _sseSub = sse.events.listen((event) {
      if (event.type == 'notification:created') {
        _load(); // untrusted body: refetch our canonical feed
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoadingMore ||
        !_hasMore ||
        _isLoading) {
      return;
    }
    if (_scrollController.position.extentAfter < 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final request = _loadGuard.begin();
    _pageGuard.invalidate();
    final hadContent = _items.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = !hadContent;
      _isLoadingMore = false;
      _error = null;
      _hasMore = true;
    });

    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      if (groups.isEmpty) {
        setState(() {
          _hasHousehold = false;
          _items.clear();
          _isLoading = false;
        });
        return;
      }
      _ensureLiveUpdates(groups);
      final service = await ref.read(notificationServiceProviderAsync.future);
      final data =
          await service.listNotifications(limit: _pageLimit, offset: 0);
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _hasHousehold = true;
        _items
          ..clear()
          ..addAll(data);
        _hasMore = data.length == _pageLimit;
        _isLoading = false;
      });
      ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      if (hadContent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notificationsFailedLoad)),
        );
      } else {
        setState(() {
          _error = l10n.notificationsFailedLoad;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    final request = _pageGuard.begin();
    final cursor = _items.last;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      final data = await service.listNotifications(
        limit: _pageLimit,
        beforeCreatedAt: cursor.createdAt,
        beforeId: cursor.id,
      );
      if (!mounted || !_pageGuard.isCurrent(request)) return;
      setState(() {
        final existingIds = _items.map((item) => item.id).toSet();
        _items.addAll(data.where((item) => existingIds.add(item.id)));
        _hasMore = data.length == _pageLimit;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || !_pageGuard.isCurrent(request)) return;
      setState(() {
        _error = l10n.notificationsFailedLoadMore;
        _isLoadingMore = false;
      });
    }
  }

  NotificationModel _asRead(NotificationModel n) => NotificationModel(
        id: n.id,
        userId: n.userId,
        groupId: n.groupId,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        isRead: true,
        readAt: DateTime.now(),
        createdAt: n.createdAt,
      );

  Future<void> _markAllRead() async {
    if (_isMutating) return;
    _isMutating = true;
    final l10n = AppLocalizations.of(context)!;
    unawaited(Haptics.light());
    // Optimistic: dots clear immediately; a failed call reloads the truth.
    final before = List<NotificationModel>.from(_items);
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (!_items[i].isRead) _items[i] = _asRead(_items[i]);
      }
    });
    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      await service.markAllAsRead();
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(before);
        _error = l10n.notificationsFailedMarkAllRead;
      });
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.isRead) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      await service.markAsRead(n.id);
      setState(() {
        final idx = _items.indexWhere((x) => x.id == n.id);
        if (idx >= 0) _items[idx] = _asRead(n);
      });
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.notificationsFailedMarkRead);
    }
  }

  /// Optimistic delete: the row is already gone from the list when the
  /// Dismissible finishes animating; on failure it is restored in place.
  Future<void> _delete(NotificationModel n) async {
    final idx = _items.indexWhere((x) => x.id == n.id);
    if (idx < 0) return;
    unawaited(Haptics.medium());
    setState(() => _items.removeAt(idx));
    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      await service.deleteNotification(n.id);
      if (!n.isRead) ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      setState(() {
        if (!_items.any((item) => item.id == n.id)) {
          _items.insert(idx.clamp(0, _items.length), n);
        }
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      });
    }
  }

  Future<void> _handleNotificationTap(NotificationModel n) async {
    unawaited(Haptics.light());
    unawaited(_markRead(n));

    if (n.data == null) return;
    final payload = _parsePayload(n.data);
    if (payload == null) return;
    if (n.groupId != null && !payload.containsKey('group_id')) {
      payload['group_id'] = n.groupId;
    }

    await navigateNotificationPayload(
      GoRouter.of(context),
      payload,
      preserveInbox: true,
      switchGroup: (groupId) =>
          ref.read(currentGroupIdProvider.notifier).set(groupId),
    );
  }

  Map<String, dynamic>? _parsePayload(dynamic data) {
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _sectionFor(DateTime t, AppLocalizations l10n) {
    t = t.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return l10n.notificationsSectionToday;
    if (diff == 1) return l10n.notificationsSectionYesterday;
    return l10n.notificationsSectionEarlier;
  }

  String _relativeTime(DateTime t, AppLocalizations l10n) {
    t = t.toLocal();
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return l10n.notificationsTimeNow;
    if (diff.inHours < 1) return l10n.notificationsTimeMinutes(diff.inMinutes);
    if (diff.inDays < 1) return l10n.notificationsTimeHours(diff.inHours);
    if (diff.inDays < 7) return l10n.notificationsTimeDays(diff.inDays);
    return DateFormat.MMMd(l10n.localeName).format(t);
  }

  List<_FeedEntry> _buildEntries(AppLocalizations l10n) {
    final entries = <_FeedEntry>[];
    String? section;
    for (final n in _items) {
      final s = _sectionFor(n.createdAt, l10n);
      if (s != section) {
        section = s;
        entries.add(_FeedEntry.header(s));
      }
      entries.add(_FeedEntry.item(n));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final loadedUnreadCount = _items.where((n) => !n.isRead).length;
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).valueOrNull ??
            loadedUnreadCount;

    return Scaffold(
      appBar: MitlistAppBar(
        showStandardActions: false,
        centerTitle: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.notificationsAppBarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: MitlistSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.xs + 2,
                  vertical: 2,
                ),
                color: colorScheme.primary,
                child: Text(
                  l10n.notificationsUnreadCount(unreadCount),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            AppButton(
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.neutral,
              text: l10n.notificationsMarkAllRead,
              onPressed: _isLoading ? null : _markAllRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_isLoading)
                    ...List.generate(
                      5,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
                        child: _NotificationSkeleton(),
                      ),
                    ),
                  if (_error != null) ...[
                    AppAlert(type: AppAlertType.error, message: _error!),
                    const SizedBox(height: MitlistSpacing.md),
                    AppButton(
                      text: l10n.commonRetry,
                      onPressed: _load,
                    ),
                    const SizedBox(height: MitlistSpacing.md),
                  ],
                  if (!_hasHousehold)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: MitlistSpacing.xl),
                      child: AppEmptyState(
                        lottieAsset: 'assets/animations/lottie/House.lottie',
                        icon: const AppIcon(name: 'homeOutline', size: 56),
                        title: l10n.commonNoHousehold,
                        description: l10n.notificationsNoHouseholdDesc,
                        actions: [
                          AppButton(
                            text: l10n.commonGoToHouseholds,
                            onPressed: () => context.goNamed('groupsList'),
                          ),
                        ],
                      ),
                    )
                  else if (_items.isEmpty && _error == null && !_isLoading)
                    AppEmptyState(
                      lottieAsset:
                          'assets/animations/lottie/Notifications.lottie',
                      icon: AppIcon(name: 'bellOutline', size: 56),
                      title: l10n.notificationsNoNotifications,
                      description: l10n.notificationsNoNotificationsDesc,
                    ),
                ]),
              ),
            ),
            if (_hasHousehold && _items.isNotEmpty && !_isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.md,
                ),
                sliver: _buildFeed(l10n),
              ),
            if (_isLoadingMore)
              const SliverPadding(
                padding: EdgeInsets.all(MitlistSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(AppLocalizations l10n) {
    final entries = _buildEntries(l10n);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = entries[index];
          if (entry.header != null) {
            return Padding(
              padding: const EdgeInsets.only(
                top: MitlistSpacing.sm,
                bottom: MitlistSpacing.sm,
              ),
              child: Text(
                entry.header!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          final n = entry.notification!;
          return Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              background: Semantics(
                label: l10n.commonDelete,
                child: Container(
                  alignment: Alignment.centerRight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
                  color: Theme.of(context).colorScheme.error,
                  child: AppIcon(
                    name: 'trashOutline',
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
              onDismissed: (_) => _delete(n),
              child: _NotificationTile(
                notification: n,
                timeLabel: _relativeTime(n.createdAt, l10n),
                semanticLabel:
                    n.isRead ? n.title : l10n.notificationsUnreadLabel(n.title),
                onTap: () => _handleNotificationTap(n),
              ),
            ),
          );
        },
        childCount: entries.length,
      ),
    );
  }
}

/// Icon + tint pair for a notification type, resolved against brightness so
/// plates stay legible in both themes.
({String icon, Color background, Color foreground}) _typeVisual(
  String type,
  Brightness brightness,
) {
  final light = brightness == Brightness.light;
  switch (type) {
    case 'chore_due':
    case 'chore_due_day_of':
      return (
        icon: 'cleaningServices',
        background: light ? MitlistColors.success100 : MitlistColors.success900,
        foreground: light ? MitlistColors.success700 : MitlistColors.success300,
      );
    case 'list_item_added':
      return (
        icon: 'shoppingCartOutline',
        background: light ? MitlistColors.primary100 : MitlistColors.primary900,
        foreground: light ? MitlistColors.primary700 : MitlistColors.primary300,
      );
    case 'expense_created':
      return (
        icon: 'banknotes',
        background: light ? MitlistColors.warning100 : MitlistColors.warning900,
        foreground: light ? MitlistColors.warning700 : MitlistColors.warning300,
      );
    case 'meal_plan_changed':
      return (
        icon: 'restaurantOutline',
        background:
            light ? MitlistColors.noteLavender : MitlistColors.noteLavenderDark,
        foreground:
            light ? MitlistColors.noteLavenderDark : MitlistColors.noteLavender,
      );
    case 'weekly_digest':
      return (
        icon: 'chartBar',
        background: light ? MitlistColors.noteSky : MitlistColors.noteSkyDark,
        foreground: light ? MitlistColors.noteSkyDark : MitlistColors.noteSky,
      );
    case 'pinwall_reminder':
      return (
        icon: 'pushPinOutline',
        background:
            light ? MitlistColors.noteBlush : MitlistColors.noteBlushDark,
        foreground:
            light ? MitlistColors.noteBlushDark : MitlistColors.noteBlush,
      );
    default:
      return (
        icon: 'bellOutline',
        background: light ? MitlistColors.neutral200 : MitlistColors.neutral800,
        foreground: light ? MitlistColors.neutral700 : MitlistColors.neutral300,
      );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.timeLabel,
    required this.semanticLabel,
    required this.onTap,
  });

  final NotificationModel notification;
  final String timeLabel;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visual = _typeVisual(n.type, theme.brightness);
    final subtitle = n.body.isNotEmpty ? n.body : n.type;

    return AppCard(
      interactive: true,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              color: visual.background,
              alignment: Alignment.center,
              child: AppIcon(
                name: visual.icon,
                size: 20,
                color: visual.foreground,
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm + MitlistSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                n.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(width: MitlistSpacing.sm),
                        // Square, not round: the app's hard-edged vocabulary.
                        Container(
                          width: 8,
                          height: 8,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MitlistSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 40, height: 40),
          SizedBox(width: MitlistSpacing.sm + MitlistSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 160, height: 14),
                SizedBox(height: MitlistSpacing.sm),
                AppSkeleton(width: double.infinity, height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
