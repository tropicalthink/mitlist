import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/activity_models.dart';
import '../../models/auth_models.dart';
import '../../models/group_models.dart';
import '../../models/pinwall_media_models.dart';
import '../../models/pinwall_models.dart';
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
import '../../widgets/skeleton.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../sheets/invite_household_sheet.dart';
import '../../sheets/group_settings_sheet.dart';

final _currencyFormat = NumberFormat.currency(symbol: '\$');

final _pinwallMediaByPostProvider = FutureProvider.family<
    List<PinwallMediaItem>, ({String groupId, String postId})>(
  (ref, args) async {
    final svc = await ref.read(pinwallServiceProviderAsync.future);
    return svc.listPostAttachments(groupId: args.groupId, postId: args.postId);
  },
);

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
      } catch (_) {
        debugPrint('[HouseholdHub] Activity refresh failed for ${widget.groupId}');
      }

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
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: () => _openQuickAddSheet(context),
              icon: const Icon(Icons.add),
              text: 'Quick add',
              tooltip: 'Quick add',
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
                    ref.invalidate(
                        cachedFinanceSummaryByGroupProvider(widget.groupId));
                    ref.invalidate(cachedListsByGroupProvider(widget.groupId));
                    ref.invalidate(
                        cachedCurrentChoresByGroupProvider(widget.groupId));
                    ref.invalidate(pinwallPostsByGroupProvider(widget.groupId));
                    await _loadData();

                    // Best-effort background refresh for cached sections.
                    try {
                      final financeRepo =
                          await ref.read(financeRepositoryProvider.future);
                      await financeRepo.refreshGroup(widget.groupId,
                          limit: 50, offset: 0);
                    } catch (_) {
                      debugPrint('[HouseholdHub] Finance repo refresh failed');
                    }
                    try {
                      final listRepo =
                          await ref.read(listRepositoryProvider.future);
                      await listRepo.refreshLists(widget.groupId,
                          limit: 50, offset: 0);
                    } catch (_) {
                      debugPrint('[HouseholdHub] List repo refresh failed');
                    }
                    try {
                      final choreRepo =
                          await ref.read(choreRepositoryProvider.future);
                      await choreRepo.refreshCurrentChores(widget.groupId);
                    } catch (_) {
                      debugPrint('[HouseholdHub] Chore repo refresh failed');
                    }
                    try {
                      final pinRepo =
                          await ref.read(pinwallRepositoryProvider.future);
                      await pinRepo.refreshPosts(widget.groupId,
                          limit: 20, offset: 0);
                    } catch (_) {
                      debugPrint('[HouseholdHub] Pinwall repo refresh failed');
                    }
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        leading: null,
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
                           IconButton(
                            tooltip: 'Settings',
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => GroupSettingsSheet.show(
                              context,
                              groupId: widget.groupId,
                            ),
                          ),
                        IconButton(
                            tooltip: 'Calendar',
                            icon: const Icon(Icons.calendar_month_outlined),
                            onPressed: () => context.pushNamed('calendar'),
                          ),
                          IconButton(
                            tooltip: 'Notifications',
                            icon: const Icon(Icons.notifications_none_outlined),
                            onPressed: () => context.pushNamed('notifications'),
                          ),
                          IconButton(
                            tooltip: 'Scanner',
                            icon: const Icon(Icons.document_scanner_outlined),
                            onPressed: () => context.pushNamed('scanner'),
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
                              const SizedBox(height: MitlistSpacing.md),
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
  switch (a.action) {
    case 'list_item_added':
      return 'Added an item to a list · $when';
    case 'expense_created':
      return 'Logged an expense · $when';
    case 'chore_completed':
      return 'Completed a chore · $when';
    case 'recipe_added':
      return 'Saved a recipe · $when';
    case 'meal_plan_created':
      return 'Updated meal plan · $when';
    default:
      return '${a.action} · $when';
  }
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

// ─────────────────────────────────────────────────────────────────────────────
// Pinwall section – a real corkboard with sticky notes
// ─────────────────────────────────────────────────────────────────────────────

// Per-note colour palette (warm sticky-note hues).
const _kNotePalette = MitlistColors.notePalette;
const _kNotePaletteDark = MitlistColors.notePaletteDark;

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
  bool _isUploadingMedia = false;
  final List<XFile> _pendingMedia = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_isUploadingMedia) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (!mounted || files.isEmpty) return;
    setState(() => _pendingMedia.addAll(files));
  }

  Future<void> _post() async {
    final content = _controller.text.trim();
    if ((content.isEmpty && _pendingMedia.isEmpty) || _isPosting) return;

    setState(() => _isPosting = true);
    try {
      final svc = await ref.read(pinwallServiceProviderAsync.future);
      final post = await svc.createPost(widget.groupId,
          content: content.isEmpty ? ' ' : content);
      if (!mounted) return;

      if (_pendingMedia.isNotEmpty) {
        setState(() => _isUploadingMedia = true);
        try {
          final attachmentRepo =
              await ref.read(attachmentRepositoryProvider.future);
          for (final f in List<XFile>.from(_pendingMedia)) {
            final bytes = await f.readAsBytes();
            final a = await attachmentRepo.uploadAttachment(
              groupId: widget.groupId,
              purpose: 'pinwall_media',
              filename: f.name,
              contentType: 'image/*',
              bytes: bytes,
            );
            await svc.attachPostAttachment(
              groupId: widget.groupId,
              postId: post.id,
              attachmentId: a.id,
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isUploadingMedia = false;
              _pendingMedia.clear();
            });
          }
        }
      }

      _controller.clear();
      ref.invalidate(pinwallPostsByGroupProvider(widget.groupId));
      if (!mounted) return;
      Haptics.light();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pinned to the wall')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(pinwallPostsByGroupProvider(widget.groupId));
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final boardBg = dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final boardBorder =
        dark ? MitlistColors.pinwallBoardBorderDark : MitlistColors.pinwallBoardBorder;
    final boardShadow = Colors.black.withValues(alpha: dark ? 0.38 : 0.16);

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
        Container(
          padding: const EdgeInsets.all(MitlistSpacing.sm),
          decoration: BoxDecoration(
            color: boardBg,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusLg),
            border: Border.all(color: boardBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: boardShadow,
                blurRadius: 10,
                offset: const Offset(4, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PinwallComposerNote(
                controller: _controller,
                isPosting: _isPosting,
                isUploadingMedia: _isUploadingMedia,
                pendingCount: _pendingMedia.length,
                onPickMedia: _pickMedia,
                onPost: _post,
              ),
              const SizedBox(height: MitlistSpacing.lg),
              posts.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => Container(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  decoration: BoxDecoration(
                    color: dark
                        ? MitlistColors.pinwallNoteErrorDark
                        : MitlistColors.noteYellow,
                    borderRadius: BorderRadius.circular(MitlistTheme.radiusLg),
                    border: Border.all(color: boardBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: MitlistColors.primary500),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: Text(
                          "Couldn't load the pinwall.",
                          style: textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(
                            pinwallPostsByGroupProvider(widget.groupId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: MitlistSpacing.md),
                      child: Text(
                        'The wall is clear. Pin a note, photo, or reminder for everyone.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: dark
                              ? MitlistColors.pinwallNoteTextDark
                              : MitlistColors.pinwallNoteTextLight,
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
    required this.isUploadingMedia,
    required this.pendingCount,
    required this.onPickMedia,
    required this.onPost,
  });

  final TextEditingController controller;
  final bool isPosting;
  final bool isUploadingMedia;
  final int pendingCount;
  final Future<void> Function() onPickMedia;
  final Future<void> Function() onPost;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark ? MitlistColors.composerBorderDark : MitlistColors.composerBorderLight;
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
            borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.42 : 0.16),
                blurRadius: 0,
                offset: const Offset(4, 5),
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
                  color: dark
                      ? Colors.white.withValues(alpha: 0.9)
                      : MitlistColors.textPrimary,
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
              Row(
                children: [
                  TextButton.icon(
                    onPressed:
                        (isPosting || isUploadingMedia) ? null : onPickMedia,
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: Text(
                        pendingCount == 0 ? 'Photo' : '$pendingCount added'),
                  ),
                  const Spacer(),
                  AppButton(
                    text: isUploadingMedia
                        ? 'Uploading...'
                        : (isPosting ? 'Posting...' : 'Pin it'),
                    icon: const Icon(Icons.push_pin_outlined),
                    onPressed: (isPosting || isUploadingMedia) ? null : onPost,
                    variant: AppButtonVariant.soft,
                    size: AppButtonSize.sm,
                  ),
                ],
              ),
            ],
          ),
        ),
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
  final PinwallPost post;

  void _showErrorSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openMediaViewer(BuildContext context, PinwallMediaItem m) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 6,
              child: Image.network(
                m.url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(MitlistSpacing.md),
                  child: Text(
                    'Couldn\u2019t load image.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMediaActions(
    BuildContext context,
    WidgetRef ref, {
    required PinwallMediaItem media,
  }) async {
    Haptics.light();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  text: 'View',
                  onPressed: () => Navigator.of(ctx).pop('view'),
                ),
                const SizedBox(height: MitlistSpacing.sm),
                AppButton(
                  text: 'Remove from post',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(ctx).pop('remove'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (action == 'view') {
      _openMediaViewer(context, media);
      return;
    }
    if (action == 'remove') {
      try {
        final svc = await ref.read(pinwallServiceProviderAsync.future);
        await svc.detachPostAttachment(
          groupId: groupId,
          postId: post.id,
          attachmentId: media.attachmentId,
        );
        // Best-effort cleanup: avoid orphaned attachments.
        try {
          final attachSvc =
              await ref.read(attachmentServiceProviderAsync.future);
          await attachSvc.deleteAttachment(
            groupId: groupId,
            attachmentId: media.attachmentId,
          );
        } catch (_) {
          debugPrint('[HouseholdHub] Pinwall media cleanup failed for ${media.attachmentId}');
        }
        ref.invalidate(
          _pinwallMediaByPostProvider(
              (groupId: groupId, postId: post.id)),
        );
      } catch (_) {
        if (context.mounted) {
          _showErrorSnack(context, 'Couldn’t remove photo.');
        }
      }
    }
  }

  Future<void> _addMediaToPost(BuildContext context, WidgetRef ref) async {
    Haptics.light();
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty) return;

    try {
      final attachmentRepo =
          await ref.read(attachmentRepositoryProvider.future);
      final svc = await ref.read(pinwallServiceProviderAsync.future);

      for (final f in files) {
        final bytes = await f.readAsBytes();
        final a = await attachmentRepo.uploadAttachment(
          groupId: groupId,
          purpose: 'pinwall_media',
          filename: f.name,
          contentType: 'image/*',
          bytes: bytes,
        );
        await svc.attachPostAttachment(
          groupId: groupId,
          postId: post.id,
          attachmentId: a.id,
        );
      }

      ref.invalidate(
        _pinwallMediaByPostProvider(
            (groupId: groupId, postId: post.id)),
      );
    } catch (_) {
      if (context.mounted) {
        _showErrorSnack(context, 'Couldn’t add photo.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final userId = post.userId;
    final content = post.content.trim();
    final createdAt = post.createdAt;
    final userLabel = _formatUserLabel(userId, me?.id);
    final when = _relativeDay(createdAt);

    // deterministic but varied rotation: +-4deg
    final idHash = post.id.hashCode;
    final rot = ((idHash % 13) - 6) * 0.012;

    // pick sticky note colour deterministically from palette
    final palette = dark ? _kNotePaletteDark : _kNotePalette;
    final bg = palette[(idHash.abs()) % palette.length];
    final border = bg.withValues(alpha: dark ? 0.3 : 0.6);

    // pin colour cycles through orange/teal/red
    const pinColors = [
      MitlistColors.primary600,
      MitlistColors.teal500,
      MitlistColors.error600,
    ];
    final pinColor = pinColors[index % pinColors.length];

    final media = ref.watch(
      _pinwallMediaByPostProvider(
          (groupId: groupId, postId: post.id)),
    );

    Future<void> onDelete() async {
      Haptics.light();
      final svc = await ref.read(pinwallServiceProviderAsync.future);
      await svc.deletePost(groupId, post.id);
      ref.invalidate(pinwallPostsByGroupProvider(groupId));
    }

    final textColor =
        dark ? Colors.white.withValues(alpha: 0.9) : MitlistColors.textPrimary;
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
                  color: Colors.black.withValues(alpha: dark ? 0.42 : 0.16),
                  blurRadius: 0,
                  offset: const Offset(4, 5),
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
                media.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (items) {
                    if (items.isEmpty) return const SizedBox.shrink();
                    final show =
                        items.length > 5 ? items.take(5).toList() : items;
                    return Padding(
                      padding: const EdgeInsets.only(top: MitlistSpacing.xs),
                      child: SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: show.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final m = show[i];
                            return GestureDetector(
                              onTap: () => _openMediaViewer(context, m),
                              onLongPress: () =>
                                  _showMediaActions(context, ref, media: m),
                              child: Semantics(
                                button: true,
                                label: 'View photo',
                                child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.network(
                                    m.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: MitlistColors.neutral100
                                          .withValues(alpha: 0.25),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$userLabel · $when',
                        style:
                            textTheme.labelSmall?.copyWith(color: mutedColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Post options',
                      onSelected: (v) async {
                        if (v == 'photo') {
                          await _addMediaToPost(context, ref);
                          return;
                        }
                        if (v == 'delete') await onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'photo', child: Text('Add photo')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(MitlistSpacing.sm),
                        child:
                            Icon(Icons.more_horiz, size: MitlistSpacing.space5, color: mutedColor),
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

// Flat pushpin that matches the app's hard-edged illustration style.
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

    final headPaint = Paint()..color = headColor;
    canvas.drawCircle(Offset(cx, 10), 10, headPaint);

    final capPaint = Paint()..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, 18), width: 14, height: 5),
        capPaint);

    final needlePaint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final needlePath = Path()
      ..moveTo(cx - 1.5, 19)
      ..lineTo(cx + 1.5, 19)
      ..lineTo(cx, size.height)
      ..close();
    canvas.drawPath(needlePath, needlePaint);

    final outlinePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
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
        final tileWidth =
            (c.maxWidth - (MitlistSpacing.sm * (count - 1))) / count;

        return Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            SizedBox(
                width: tileWidth,
                child: _BalanceTile(groupId: groupId, me: me)),
            SizedBox(width: tileWidth, child: _ShoppingTile(groupId: groupId)),
            SizedBox(
                width: tileWidth, child: _WeeklyChoresTile(groupId: groupId)),
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
        final meEntry = myId == null
            ? null
            : s.balances.where((b) => b.userId == myId).firstOrNull;
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
          final items =
              shopping.fold<int>(0, (sum, l) => sum + (l.itemCount ?? 0));
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
        final done = rows
            .where((c) =>
                !c.chore.isActive ||
                (c.pendingAssignment?.status.toLowerCase() == 'completed'))
            .length;
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
              borderRadius: BorderRadius.circular(MitlistTheme.radiusFull),
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
    final titleColor = (tint == null
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimaryContainer)
        .withValues(alpha: 0.8);
    final valueColor =
        tint == null ? colorScheme.onSurface : colorScheme.onPrimaryContainer;
    final subtitleColor = (tint == null
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimaryContainer)
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
        semanticLabel: title,
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
      semanticLabel: title,
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
                'Activity',
                style: textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        if (activityError)
          Text(
            'Couldn’t load the wall right now.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else if (activities.isEmpty)
          Text(
            'Nothing posted yet.',
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

  void _onTap(BuildContext context) {
    final groupId = item.groupId;

    switch (item.action) {
      case 'list_item_added':
        context.pushNamed('listDetail',
            pathParameters: {'listId': groupId});
        return;
      case 'expense_created':
        context.pushNamed('money');
        return;
      case 'chore_completed':
        context.pushNamed('chores');
        return;
      case 'recipe_added':
        context.pushNamed('recipes');
        return;
      case 'meal_plan_created':
        context.pushNamed('mealPlan');
        return;
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final userLabel = _formatUserLabel(item.userId ?? '', null);
    final when = _relativeDay(item.createdAt);
    final message = _formatActivityLine(item);
    final isTappable = _isNavigableAction(item.action);

    return InkWell(
      onTap: isTappable ? () => _onTap(context) : null,
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
                _avatarInitials(userLabel),
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
        ),
      ),
    );
  }
}

bool _isNavigableAction(String action) {
  return const {
    'list_item_added',
    'expense_created',
    'chore_completed',
    'recipe_added',
    'meal_plan_created',
  }.contains(action);
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
