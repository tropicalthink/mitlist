import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/notification_models.dart';
import '../../providers/notification_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const int _pageLimit = 50;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  final List<NotificationModel> _items = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore || _isLoading) return;
    if (_scrollController.position.extentAfter < 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _hasMore = true;
    });

    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      final data = await service.listNotifications(limit: _pageLimit, offset: 0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(data);
        _hasMore = data.length == _pageLimit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load notifications.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      final data = await service.listNotifications(limit: _pageLimit, offset: _items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        _hasMore = data.length == _pageLimit;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load more notifications.';
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      await service.markAllAsRead();
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to mark all as read.');
    }
  }

  Future<void> _markRead(NotificationModel n) async {
    if (n.isRead) return;
    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      await service.markAsRead(n.id);
      setState(() {
        final idx = _items.indexWhere((x) => x.id == n.id);
        if (idx >= 0) {
          _items[idx] = NotificationModel(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: n.createdAt,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to mark as read.');
    }
  }

  Future<void> _delete(NotificationModel n) async {
    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      await service.deleteNotification(n.id);
      setState(() => _items.removeWhere((x) => x.id == n.id));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to delete notification.');
    }
  }

  void _handleNotificationTap(NotificationModel n) {
    _markRead(n);

    if (n.data == null) return;
    final payload = _parsePayload(n.data);
    if (payload == null) return;

    final screen = payload['screen'] as String?;
    final id = payload['id'] as String?;
    final groupId = payload['group_id'] as String?;

    switch (screen) {
      case 'choreDetail':
        context.pushNamed('chores');
      case 'expenseDetail':
        context.pushNamed('money');
      case 'listDetail':
        if (id != null && id.isNotEmpty) {
          context.goNamed('listDetail', pathParameters: {'listId': id});
        }
      case 'recipeDetail':
        context.pushNamed('recipes');
      case 'mealPlan':
        context.pushNamed('mealPlan');
      case 'householdHub':
        if (groupId != null && groupId.isNotEmpty) {
          context.goNamed('householdHub', pathParameters: {'groupId': groupId});
        }
      case 'recurringExpenses':
        context.pushNamed('recurringExpenses');
    }
  }

  Map<String, dynamic>? _parsePayload(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Notifications',
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(MitlistSpacing.md),
                children: [
                  if (_isLoading) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: MitlistSpacing.md),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation(MitlistColors.primary500),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    AppAlert(type: AppAlertType.error, message: _error!),
                    const SizedBox(height: MitlistSpacing.md),
                  ],
                  if (_items.isEmpty && _error == null)
                    AppEmptyState(
                      icon: const Icon(Icons.notifications_none_outlined, size: 56),
                      title: 'No notifications yet',
                      description:
                          'When someone adds a chore, splits a bill, or mentions you, it will show up here.',
                    )
                  else
                    ..._items.map((n) {
                      final subtitle = n.body.isNotEmpty ? n.body : n.type;
                      final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800,
                          );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                        child: Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
                            decoration: BoxDecoration(
                              color: MitlistColors.error500.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(MitlistTheme.radiusLg),
                            ),
                            child: const Icon(Icons.delete_outline, color: MitlistColors.error500),
                          ),
                          confirmDismiss: (_) async {
                            await _delete(n);
                            return false;
                          },
                          child: AppCard(
                            interactive: true,
                            onTap: () => _handleNotificationTap(n),
                            child: Padding(
                              padding: const EdgeInsets.all(MitlistSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: titleStyle),
                                  const SizedBox(height: MitlistSpacing.xs),
                                  Text(
                                    subtitle,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  if (_isLoadingMore) ...[
                    const SizedBox(height: MitlistSpacing.sm),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
    );
  }
}

