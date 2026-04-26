import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/activity_models.dart';
import '../../models/auth_models.dart';
import '../../models/group_models.dart';
import '../../providers/activity_provider.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../repositories/hub_repository.dart';
import '../../utils/haptics.dart';
import '../../theme/colors.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/skeleton.dart';
import '../../theme/spacing.dart';
import '../../sheets/invite_household_sheet.dart';

final _currencyFormat = NumberFormat.currency(symbol: '\$');

class _HubSnapshot {
  const _HubSnapshot({
    required this.activities,
    required this.activityError,
  });

  final List<ActivityLogModel> activities;
  final bool activityError;
}

class HouseholdHubScreen extends ConsumerStatefulWidget {
  final String groupId;

  const HouseholdHubScreen({super.key, required this.groupId});

  @override
  ConsumerState<HouseholdHubScreen> createState() => _HouseholdHubScreenState();
}

class _HouseholdHubScreenState extends ConsumerState<HouseholdHubScreen> {
  bool _isLoading = true;
  Object? _error;
  Group? _data;
  _HubSnapshot? _snapshot;
  User? _me;
  StreamSubscription<Group?>? _groupSub;
  StreamSubscription<(List<ActivityLogModel>, bool)>? _activitySub;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _activitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);

      var activities = <ActivityLogModel>[];
      var activityError = false;
      User? me;

      final actF = ref.read(activityServiceProviderAsync.future);
      final authF = ref.read(authServiceProviderAsync.future);

      try {
        final auth = await authF;
        me = await auth.getMe();
      } catch (_) {
        me = null;
      }

      final activityService = await actF;

      final repo = HubRepository(
        db: ref.read(appDatabaseProvider),
        groups: groupService,
        activity: activityService,
      );

      // Cache-first: show cached data immediately, refresh in background.
      final cachedGroup = await repo.getGroupOnce(widget.groupId);
      final cachedActivities = await repo.getActivitiesOnce(widget.groupId);
      if (!mounted) return;
      final hadCache = cachedGroup != null || cachedActivities.$1.isNotEmpty;
      setState(() {
        _data = cachedGroup;
        _snapshot = _HubSnapshot(
          activities: cachedActivities.$1,
          activityError: cachedActivities.$2,
        );
        _me = me;
        _isLoading = !hadCache;
      });

      await _groupSub?.cancel();
      _groupSub = repo.watchGroup(widget.groupId).listen((g) {
        if (!mounted || g == null) return;
        setState(() => _data = g);
      });

      await _activitySub?.cancel();
      _activitySub = repo.watchActivities(widget.groupId).listen((tuple) {
        if (!mounted) return;
        setState(() {
          _snapshot = _HubSnapshot(
            activities: tuple.$1,
            activityError: tuple.$2,
          );
        });
      });

      // Background refresh; if it fails, keep cached view.
      try {
        await repo.refresh(widget.groupId, activityLimit: 10);
        activities = (await repo.getActivitiesOnce(widget.groupId)).$1;
        activityError = (await repo.getActivitiesOnce(widget.groupId)).$2;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _data = _data;
        _snapshot = _snapshot ??
            _HubSnapshot(activities: activities, activityError: activityError);
        _me = me;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isLoading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: () => _openQuickAddSheet(context),
              child: const Icon(Icons.add),
            ),
      body: _isLoading
          ? const _SkeletonDashboard()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.md),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppAlert(
                          type: AppAlertType.error,
                          message:
                              'Couldn’t load this household. Check your connection and try again.',
                        ),
                        const SizedBox(height: MitlistSpacing.md),
                        AppButton(
                          text: 'Retry',
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(cachedFinanceSummaryByGroupProvider(widget.groupId));
                    ref.invalidate(cachedListsByGroupProvider(widget.groupId));
                    ref.invalidate(cachedCurrentChoresByGroupProvider(widget.groupId));
                    ref.invalidate(pinwallPostsByGroupProvider(widget.groupId));
                    await _loadData();

                    // Best-effort background refresh for cached sections.
                    try {
                      final financeRepo =
                          await ref.read(financeRepositoryProvider.future);
                      await financeRepo.refreshGroup(widget.groupId, limit: 50, offset: 0);
                    } catch (_) {}
                    try {
                      final listRepo = await ref.read(listRepositoryProvider.future);
                      await listRepo.refreshLists(widget.groupId, limit: 50, offset: 0);
                    } catch (_) {}
                    try {
                      final choreRepo =
                          await ref.read(choreRepositoryProvider.future);
                      await choreRepo.refreshCurrentChores(widget.groupId);
                    } catch (_) {}
                    try {
                      final pinRepo =
                          await ref.read(pinwallRepositoryProvider.future);
                      await pinRepo.refreshPosts(widget.groupId, limit: 20, offset: 0);
                    } catch (_) {}
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        leading: IconButton(
                          icon: const AppIcon(name: 'userGroup'),
                          tooltip: 'To households',
                          onPressed: () => context.goNamed('groupsList'),
                        ),
                        title: Text(
                          _data?.name ?? 'Home',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        actions: [
                          IconButton(
                            tooltip: 'Invite',
                            icon: const Icon(Icons.group_add_outlined),
                            onPressed: () => InviteHouseholdSheet.show(
                              context,
                              groupId: widget.groupId,
                            ),
                          ),
                          if (!kReleaseMode)
                            IconButton(
                              tooltip: 'Upload test attachment',
                              icon: const Icon(Icons.cloud_upload_outlined),
                              onPressed: () async {
                                try {
                                  final repo = await ref.read(
                                    attachmentRepositoryProvider.future,
                                  );
                                  final bytes = utf8.encode(
                                    'mitlist attachment diagnostic\n'
                                    'group=${widget.groupId}\n'
                                    'ts=${DateTime.now().toIso8601String()}\n',
                                  );
                                  final a = await repo.uploadAttachment(
                                    groupId: widget.groupId,
                                    purpose: 'debug_diagnostic',
                                    filename: 'diagnostic.txt',
                                    contentType: 'text/plain; charset=utf-8',
                                    bytes: Uint8List.fromList(bytes),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Uploaded attachment ${a.id}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Upload failed: $e',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          IconButton(
                            tooltip: 'Notifications',
                            icon: const Icon(Icons.notifications_none_outlined),
                            onPressed: () => context.pushNamed('notifications'),
                          ),
                          IconButton(
                            tooltip: 'Account',
                            icon: const Icon(Icons.person_outline),
                            onPressed: () => context.pushNamed('you'),
                          ),
                          const SizedBox(width: MitlistSpacing.xs),
                        ],
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(MitlistSpacing.md),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              _GreetingHeader(
                                me: _me,
                                householdName: _data?.name,
                              ),
                              const SizedBox(height: MitlistSpacing.lg),
                              _PinwallSection(groupId: widget.groupId, me: _me),
              const SizedBox(height: MitlistSpacing.md),
              _SectionLabel(label: 'At a glance'),
              const SizedBox(height: MitlistSpacing.sm),
              _StatsRow(groupId: widget.groupId, me: _me),
                              const SizedBox(height: MitlistSpacing.lg),
                              _WallSection(
                                activities: _snapshot!.activities,
                                activityError: _snapshot!.activityError,
                              ),
                              const SizedBox(height: MitlistSpacing.xl),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

String _formatActivityLine(ActivityLogModel a) {
  final when = _relativeDay(a.createdAt);
  final kind = a.entityType.toLowerCase();
  if (kind.contains('expense') || kind.contains('split')) {
    return 'Money update · $when';
  }
  if (kind.contains('chore') || kind.contains('assignment')) {
    return 'Chore activity · $when';
  }
  if (kind.contains('list')) {
    return 'List update · $when';
  }
  return 'Activity ${a.action} · $when';
}

String _relativeDay(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(t.year, t.month, t.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  if (diff < 7) return '$diff days ago';
  return DateFormat.MMMd().format(t);
}

String _formatUserLabel(String id, String? currentUserId) {
  if (id == currentUserId) return 'You';
  return 'Member';
}

// Returns a 1–2 letter avatar string from a user label.
String _avatarInitials(String label) {
  final parts = label.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return label.isNotEmpty ? label[0].toUpperCase() : '?';
}

String _formatCurrency(double value) => _currencyFormat.format(value);

String _timeGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Morning';
  if (h < 17) return 'Afternoon';
  return 'Evening';
}

Future<void> _openQuickAddSheet(BuildContext context) async {
  Haptics.light();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick add',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: MitlistSpacing.md),
              AppButton(
                text: 'Add expense',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed('money');
                },
              ),
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                text: 'Add to a list',
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed('lists');
                },
              ),
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                text: 'Add chore',
                variant: AppButtonVariant.outline,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed('chores');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.me,
    required this.householdName,
  });

  final User? me;
  final String? householdName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final greeting = _timeGreeting();
    final name = me?.firstName.trim();
    final who = (name == null || name.isEmpty) ? '' : ', $name';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting$who!',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          householdName ?? 'Your household',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pinwall section – a real corkboard with sticky notes
// ─────────────────────────────────────────────────────────────────────────────

// Per-note colour palette (warm sticky-note hues).
const _kNotePalette = [
  Color(0xFFFFF9C4), // pale yellow
  Color(0xFFFFE0B2), // peach
  Color(0xFFC8E6C9), // mint
  Color(0xFFB3E5FC), // sky
  Color(0xFFF8BBD0), // blush
  Color(0xFFE1BEE7), // lavender
];
const _kNotePaletteDark = [
  Color(0xFF5D5000), // dark yellow
  Color(0xFF6D3000), // dark peach
  Color(0xFF1B5E20), // dark mint
  Color(0xFF01579B), // dark sky
  Color(0xFF880E4F), // dark blush
  Color(0xFF4A148C), // dark lavender
];

class _PinwallSection extends ConsumerStatefulWidget {
  const _PinwallSection({required this.groupId, required this.me});

  final String groupId;
  final User? me;

  @override
  ConsumerState<_PinwallSection> createState() => _PinwallSectionState();
}

class _PinwallSectionState extends ConsumerState<_PinwallSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isPosting) return;

    setState(() => _isPosting = true);
    try {
      final svc = await ref.read(pinwallServiceProviderAsync.future);
      await svc.createPost(widget.groupId, content: content);
      if (!mounted) return;
      _controller.clear();
      ref.invalidate(pinwallPostsByGroupProvider(widget.groupId));
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(pinwallPostsByGroupProvider(widget.groupId));
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Cork board colours
    final boardBg = dark ? const Color(0xFF2A211A) : const Color(0xFFC8A97A);
    final boardBorder = dark ? const Color(0xFF4A3C2E) : const Color(0xFF8B5E3C);
    final boardShadow = Colors.black.withValues(alpha: dark ? 0.5 : 0.22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: Text(
            'Pinwall',
            style: textTheme.titleMedium,
          ),
        ),
        // One big board surface that holds the composer AND the notes
        Container(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          decoration: BoxDecoration(
            color: boardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: boardBorder, width: 3),
            boxShadow: [
              BoxShadow(
                color: boardShadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Composer note (always visible at the top of the board)
              _PinwallComposerNote(
                controller: _controller,
                isPosting: _isPosting,
                onPost: _post,
              ),
              const SizedBox(height: MitlistSpacing.lg),
              posts.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => Container(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF3A2A1A) : const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: boardBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316)),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: Text(
                          "Couldn't load the pinwall.",
                          style: textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(pinwallPostsByGroupProvider(widget.groupId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.md),
                      child: Text(
                        'No notes yet — be the first to post!',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: dark ? const Color(0xFF8B7355) : const Color(0xFF5D4037),
                        ),
                      ),
                    );
                  }
                  final show = rows.take(10).toList();
                  return Wrap(
                    spacing: MitlistSpacing.md,
                    runSpacing: MitlistSpacing.lg,
                    children: [
                      for (var i = 0; i < show.length; i++)
                        _PinwallNoteCard(
                          index: i,
                          groupId: widget.groupId,
                          me: widget.me,
                          post: show[i],
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Composer sticky note (write + post)
class _PinwallComposerNote extends StatelessWidget {
  const _PinwallComposerNote({
    required this.controller,
    required this.isPosting,
    required this.onPost,
  });

  final TextEditingController controller;
  final bool isPosting;
  final Future<void> Function() onPost;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF5D5000) : const Color(0xFFFFF9C4);
    final border = dark ? const Color(0xFF8B7A00) : const Color(0xFFB8A800);
    final pinColor = dark ? MitlistColors.primary300 : MitlistColors.primary600;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.md,
            MitlistSpacing.lg + 4,
            MitlistSpacing.md,
            MitlistSpacing.md,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.5 : 0.2),
                blurRadius: 18,
                offset: const Offset(2, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.25 : 0.07),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                style: textTheme.bodyMedium?.copyWith(
                  color: dark ? Colors.white.withValues(alpha: 0.9) : MitlistColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Post a note to the household\u2026',
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: MitlistSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  text: isPosting ? 'Posting...' : 'Pin it',
                  onPressed: isPosting ? null : onPost,
                  size: AppButtonSize.sm,
                ),
              ),
            ],
          ),
        ),
        // Pushpin centred at top
        Positioned(
          top: -14,
          left: 0,
          right: 0,
          child: Center(
            child: _Pushpin(headColor: pinColor),
          ),
        ),
      ],
    );
  }
}

// A single pinned note card
class _PinwallNoteCard extends ConsumerWidget {
  const _PinwallNoteCard({
    required this.index,
    required this.groupId,
    required this.me,
    required this.post,
  });

  final int index;
  final String groupId;
  final User? me;
  final dynamic post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final userId = (post as dynamic).userId as String;
    final content = post.content as String;
    final createdAt = post.createdAt as DateTime;
    final userLabel = _formatUserLabel(userId, me?.id);
    final when = _relativeDay(createdAt);

    // deterministic but varied rotation: +-4deg
    final idHash = (post.id as String).hashCode;
    final rot = ((idHash % 13) - 6) * 0.012;

    // pick sticky note colour deterministically from palette
    final palette = dark ? _kNotePaletteDark : _kNotePalette;
    final bg = palette[(idHash.abs()) % palette.length];
    final border = bg.withValues(alpha: dark ? 0.3 : 0.6);

    // pin colour cycles through orange/teal/red
    const pinColors = [
      MitlistColors.primary600,
      Color(0xFF0D9488), // teal
      Color(0xFFDC2626), // red
    ];
    final pinColor = pinColors[index % pinColors.length];

    Future<void> onDelete() async {
      Haptics.light();
      final svc = await ref.read(pinwallServiceProviderAsync.future);
      await svc.deletePost(groupId, post.id as String);
      ref.invalidate(pinwallPostsByGroupProvider(groupId));
    }

    final textColor = dark ? Colors.white.withValues(alpha: 0.9) : MitlistColors.textPrimary;
    final mutedColor = dark
        ? Colors.white.withValues(alpha: 0.5)
        : MitlistColors.textSecondary.withValues(alpha: 0.7);

    return Transform.rotate(
      angle: rot.toDouble(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The note itself
          Container(
            width: 160,
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.sm + 4,
              MitlistSpacing.lg,
              MitlistSpacing.sm,
              MitlistSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.5 : 0.18),
                  blurRadius: 20,
                  offset: const Offset(4, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.2 : 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content,
                  style: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.4,
                  ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$userLabel · $when',
                        style: textTheme.labelSmall?.copyWith(color: mutedColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Post options',
                      onSelected: (v) async {
                        if (v == 'delete') await onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(Icons.more_horiz, size: 16, color: mutedColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Pushpin at top-centre
          Positioned(
            top: -14,
            left: 0,
            right: 0,
            child: Center(
              child: _Pushpin(headColor: pinColor),
            ),
          ),
        ],
      ),
    );
  }
}

// A realistic-looking pushpin drawn with CustomPainter
class _Pushpin extends StatelessWidget {
  const _Pushpin({required this.headColor});

  final Color headColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 28),
      painter: _PushpinPainter(headColor: headColor),
    );
  }
}

class _PushpinPainter extends CustomPainter {
  const _PushpinPainter({required this.headColor});

  final Color headColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Shadow under head
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(cx, 12), 10, shadowPaint);

    // Pin head
    final headPaint = Paint()..color = headColor;
    canvas.drawCircle(Offset(cx, 10), 10, headPaint);

    // Shine highlight
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(cx - 3.5, 6.5), 4, shinePaint);

    // Pin needle
    final needlePaint = Paint()..color = Colors.grey.shade600;
    final needlePath = Path()
      ..moveTo(cx - 2, 18)
      ..lineTo(cx + 2, 18)
      ..lineTo(cx + 0.5, size.height)
      ..lineTo(cx - 0.5, size.height)
      ..close();
    canvas.drawPath(needlePath, needlePaint);

    // Outline on head
    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, 10), 10, outlinePaint);
  }

  @override
  bool shouldRepaint(_PushpinPainter old) => old.headColor != headColor;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(label, style: textTheme.titleMedium);
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.groupId, required this.me});

  final String groupId;
  final User? me;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final minTile = 160.0;
        final count = (c.maxWidth / minTile).floor().clamp(1, 3);
        final tileWidth = (c.maxWidth - (MitlistSpacing.sm * (count - 1))) / count;

        return Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            SizedBox(width: tileWidth, child: _BalanceTile(groupId: groupId, me: me)),
            SizedBox(width: tileWidth, child: _ShoppingTile(groupId: groupId)),
            SizedBox(width: tileWidth, child: _WeeklyChoresTile(groupId: groupId)),
          ],
        );
      },
    );
  }
}

class _BalanceTile extends ConsumerWidget {
  const _BalanceTile({required this.groupId, required this.me});

  final String groupId;
  final User? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(cachedFinanceSummaryByGroupProvider(groupId));

    return summary.when(
      loading: () => const _StatTileSkeleton(),
      error: (_, __) => _StatTile(
        title: 'Current balance',
        value: '—',
        subtitle: 'Unavailable',
        tint: AppCardTint.primary,
        onTap: () => context.pushNamed('money'),
      ),
      data: (s) {
        if (s == null) {
          return _StatTile(
            title: 'Current balance',
            value: '—',
            subtitle: 'No data yet',
            tint: AppCardTint.primary,
            onTap: () => context.pushNamed('money'),
          );
        }
        final myId = me?.id;
        final meEntry = myId == null ? null : s.balances.where((b) => b.userId == myId).firstOrNull;
        final totalCents = meEntry?.total ?? 0;
        final amount = totalCents / 100.0;
        final abs = amount.abs();
        final value = _formatCurrency(abs);
        final subtitle = amount == 0
            ? 'Settled up'
            : amount < 0
                ? 'You owe'
                : 'You’re owed';

        return _StatTile(
          title: 'Current balance',
          value: value,
          subtitle: subtitle,
          tint: AppCardTint.primary,
          onTap: () => context.pushNamed('money'),
        );
      },
    );
  }
}

class _ShoppingTile extends ConsumerWidget {
  const _ShoppingTile({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(cachedListsByGroupProvider(groupId));
    return lists.when(
      loading: () => const _StatTileSkeleton(),
      error: (_, __) => _StatTile(
        title: 'Shopping',
        value: '—',
        subtitle: 'Unavailable',
        onTap: () => context.pushNamed('lists'),
      ),
      data: (all) {
        final shopping = all.where((l) => l.type == 'shopping').toList();
        if (shopping.isEmpty) {
          return _StatTile(
            title: 'Shopping',
            value: '0',
            subtitle: 'Items',
            onTap: () => context.pushNamed('lists'),
          );
        }

        final anyCount = shopping.any((l) => l.itemCount != null);
        if (anyCount) {
          final items = shopping.fold<int>(0, (sum, l) => sum + (l.itemCount ?? 0));
          return _StatTile(
            title: 'Shopping',
            value: '$items',
            subtitle: 'Items',
            onTap: () => context.pushNamed('lists'),
          );
        }

        shopping.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final listId = shopping.first.id;
        final items = ref.watch(cachedListItemsProvider(listId));
        return items.when(
          loading: () => _StatTile(
            title: 'Shopping',
            value: '—',
            subtitle: 'Items',
            onTap: () => context.pushNamed('lists'),
          ),
          error: (_, __) => _StatTile(
            title: 'Shopping',
            value: '—',
            subtitle: 'Items',
            onTap: () => context.pushNamed('lists'),
          ),
          data: (rows) {
            final unchecked = rows.where((i) => !i.checked).length;
            return _StatTile(
              title: 'Shopping',
              value: '$unchecked',
              subtitle: 'Items',
              onTap: () => context.pushNamed('lists'),
            );
          },
        );
      },
    );
  }
}

class _WeeklyChoresTile extends ConsumerWidget {
  const _WeeklyChoresTile({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(cachedCurrentChoresByGroupProvider(groupId));
    return current.when(
      loading: () => const _StatTileSkeleton(),
      error: (_, __) => _StatTile(
        title: 'Weekly chores',
        value: '—',
        subtitle: 'Unavailable',
        onTap: () => context.pushNamed('chores'),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return _StatTile(
            title: 'Weekly chores',
            value: '0%',
            subtitle: 'No chores yet',
            onTap: () => context.pushNamed('chores'),
          );
        }
        final done = rows.where((c) => !c.chore.isActive || (c.pendingAssignment?.status.toLowerCase() == 'completed')).length;
        final total = rows.length;
        final progress = total == 0 ? 0.0 : done / total;
        final pct = (progress * 100).round().clamp(0, 100);
        final sub = '$done of $total';
        return _StatTile(
          title: 'Weekly chores',
          value: '$pct%',
          subtitle: sub,
          trailing: Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.sm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 6,
              ),
            ),
          ),
          onTap: () => context.pushNamed('chores'),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    this.trailing,
    this.tint,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Widget? trailing;
  final AppCardTint? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = (tint == null ? colorScheme.onSurfaceVariant : colorScheme.onPrimaryContainer)
        .withValues(alpha: 0.8);
    final valueColor = tint == null ? colorScheme.onSurface : colorScheme.onPrimaryContainer;
    final subtitleColor =
        (tint == null ? colorScheme.onSurfaceVariant : colorScheme.onPrimaryContainer)
            .withValues(alpha: 0.85);

    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: titleColor,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(color: valueColor),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(color: subtitleColor),
        ),
        if (trailing != null) trailing!,
      ],
    );

    if (tint == null) {
      return AppCard(
        variant: AppCardVariant.soft,
        padding: AppCardPadding.md,
        interactive: true,
        onTap: () {
          Haptics.light();
          onTap();
        },
        child: child,
      );
    }

    return AppCard(
      variant: AppCardVariant.filled,
      tint: tint!,
      padding: AppCardPadding.md,
      interactive: true,
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: child,
    );
  }
}

class _StatTileSkeleton extends StatelessWidget {
  const _StatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      variant: AppCardVariant.soft,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 110, height: 12),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(width: 120, height: 20),
          SizedBox(height: MitlistSpacing.xs),
          AppSkeleton(width: 80, height: 12),
        ],
      ),
    );
  }
}

class _WallSection extends StatelessWidget {
  const _WallSection({required this.activities, required this.activityError});

  final List<ActivityLogModel> activities;
  final bool activityError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Flat Wall',
                style: textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wall details coming soon')),
                );
              },
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        if (activityError)
          Text(
            'Couldn’t load the wall right now.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else if (activities.isEmpty)
          Text(
            'Nothing posted yet.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else
          AppCard(
            padding: AppCardPadding.md,
            child: Column(
              children: [
                for (var i = 0; i < activities.take(5).length; i++) ...[
                  if (i > 0) const SizedBox(height: MitlistSpacing.sm),
                  _WallItem(item: activities[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _WallItem extends StatelessWidget {
  const _WallItem({required this.item});

  final ActivityLogModel item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final userLabel = _formatUserLabel(item.userId, null);
    final when = _relativeDay(item.createdAt);
    final message = _formatActivityLine(item);

    return Row(
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
            _avatarInitials(userLabel),
            style: textTheme.labelMedium?.copyWith(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$userLabel · $when',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: MitlistSpacing.xs),
              Text(
                message,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
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
                AppSkeleton(width: 240, height: 22),
                SizedBox(height: MitlistSpacing.xs),
                AppSkeleton(width: 180, height: 14),
                SizedBox(height: MitlistSpacing.lg),
                AppCard(
                  variant: AppCardVariant.filled,
                  tint: AppCardTint.primary,
                  padding: AppCardPadding.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 120, height: 12),
                      SizedBox(height: MitlistSpacing.md),
                      AppSkeleton(width: 240, height: 22),
                      SizedBox(height: MitlistSpacing.sm),
                      AppSkeleton(width: 280, height: 16),
                      SizedBox(height: MitlistSpacing.lg),
                      AppSkeleton(width: 240, height: 40),
                    ],
                  ),
                ),
                SizedBox(height: MitlistSpacing.md),
                Row(
                  children: [
                    Expanded(child: _StatTileSkeleton()),
                    SizedBox(width: MitlistSpacing.sm),
                    Expanded(child: _StatTileSkeleton()),
                  ],
                ),
                SizedBox(height: MitlistSpacing.sm),
                _StatTileSkeleton(),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
