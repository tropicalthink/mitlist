import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../repositories/pinwall_repository.dart';
import '../../screens/pinwall/pinwall_board_screen.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/haptics.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';
import '../pinwall/pinwall_note_card.dart';
import '../pinwall/pinwall_stat_rows.dart';
import 'pinned_memo_card.dart';

import '../app_toast.dart';
/// Column count and card width for the hub pinwall at [availableWidth].
///
/// The cards are sized so a whole number of columns exactly fills the row. A
/// fixed card width cannot do that: as soon as the viewport is narrower than
/// two cards plus spacing — which happens on ordinary phones once the system
/// display-size setting is raised — the wrap breaks to a single card per row
/// and leaves the rest of the row empty.
@visibleForTesting
({int columns, double cardWidth}) pinwallHubLayout(double availableWidth) {
  const spacing = MitlistSpacing.md;
  // Two per row on phones. Wider surfaces (tablets, landscape) take more
  // columns so notes keep a readable size instead of stretching.
  final columns = (availableWidth / 200).floor().clamp(2, 4);
  return (
    columns: columns,
    cardWidth: (availableWidth - spacing * (columns - 1)) / columns,
  );
}

class PinwallSection extends ConsumerStatefulWidget {
  const PinwallSection({super.key, required this.groupId, required this.me});

  final String groupId;
  final User? me;

  @override
  ConsumerState<PinwallSection> createState() => _PinwallSectionState();
}

class _PinwallSectionState extends ConsumerState<PinwallSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isPosting = false;
  bool _isUploadingMedia = false;
  final List<XFile> _pendingMedia = [];
  DateTime? _remindAt;
  String? _linkedEntityType;
  String? _linkedEntityId;
  String? _linkedEntityLabel;

  PinwallRepository? _repo;

  @override
  void initState() {
    super.initState();
    // Open the realtime stream for the household so pins from flatmates land
    // live on the hub wall (and, by extension, the full-screen board).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = await ref.read(pinwallRepositoryProvider.future);
      if (!mounted) return;
      _repo = repo;
      repo.attachSse(ref.read(sseServiceProvider), widget.groupId);
    });
  }

  @override
  void dispose() {
    _repo?.detachSse();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isPosting || _isUploadingMedia) return;
    unawaited(Haptics.light());

    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _remindAt?.isAfter(now) == true ? _remindAt! : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: l10n.pinwallChooseReminderDate,
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindAt ?? now),
      helpText: l10n.pinwallChooseReminderTime,
    );
    if (!mounted || pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (combined.isBefore(DateTime.now().add(const Duration(minutes: 1)))) {
      AppToast.info(context, l10n.pinwallPickFutureTime);
      return;
    }
    setState(() => _remindAt = combined);
  }

  void _clearReminder() {
    if (_remindAt == null) return;
    setState(() => _remindAt = null);
  }

  Future<void> _pickLinkedEntity() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isPosting || _isUploadingMedia) return;
    unawaited(Haptics.light());

    final typeAction = await showAppBottomSheet<String>(
      context: context,
      title: l10n.pinwallLinkTo,
      body: Builder(builder: (ctx) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              text: l10n.pinwallLinkChore,
              onPressed: () => Navigator.of(ctx).pop('chore'),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.pinwallLinkList,
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(ctx).pop('list'),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.pinwallLinkExpense,
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(ctx).pop('expense'),
            ),
            if (_linkedEntityType != null) ...[
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                text: l10n.pinwallRemoveLink,
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.error,
                onPressed: () => Navigator.of(ctx).pop('remove'),
              ),
            ],
          ],
        );
      }),
    );

    if (!mounted || typeAction == null) return;
    if (typeAction == 'remove') {
      setState(() {
        _linkedEntityType = null;
        _linkedEntityId = null;
        _linkedEntityLabel = null;
      });
      return;
    }

    // Fetch entities of the selected type and show a picker.
    try {
      final groupId = widget.groupId;

      List<_EntityOption> options;
      switch (typeAction) {
        case 'chore':
          final svc = await ref.read(choreServiceProviderAsync.future);
          final chores = await svc.listCurrentChores(groupId);
          options = chores
              .take(50)
              .map((c) => _EntityOption(
                    id: c.chore.id,
                    label: c.chore.name,
                  ))
              .toList();
        case 'list':
          final svc = await ref.read(listServiceProviderAsync.future);
          final lists = await svc.listLists(groupId, limit: 50);
          options = lists
              .map((l) => _EntityOption(
                    id: l.id,
                    label: l.name,
                  ))
              .toList();
        case 'expense':
          final svc = await ref.read(financeServiceProviderAsync.future);
          final expenses = await svc.listExpenses(groupId, limit: 50);
          options = expenses
              .map((e) => _EntityOption(
                    id: e.id,
                    label: e.description,
                  ))
              .toList();
        default:
          return;
      }

      if (!mounted || options.isEmpty) return;

      final picked = await showAppBottomSheet<_EntityOption>(
        context: context,
        title: l10n.pinwallSelectEntity(typeAction),
        body: Builder(builder: (ctx) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final opt in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                  child: AppButton(
                    text: opt.label,
                    variant: AppButtonVariant.outline,
                    onPressed: () => Navigator.of(ctx).pop(opt),
                  ),
                ),
            ],
          );
        }),
      );

      if (!mounted || picked == null) return;
      setState(() {
        _linkedEntityType = typeAction;
        _linkedEntityId = picked.id;
        _linkedEntityLabel = picked.label;
      });
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, l10n.pinwallCouldNotLoadEntities);
    }
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
    final l10n = AppLocalizations.of(context)!;
    try {
      // Plain-text posts (no media, no linked entity) go through the
      // offline-first path so they pin immediately and work without a
      // connection. Media/linked posts still require the server.
      final canQueueOffline =
          _pendingMedia.isEmpty && (_linkedEntityId?.isEmpty ?? true);
      if (canQueueOffline) {
        final repo = await ref.read(pinwallRepositoryProvider.future);
        await repo.createPostOfflineFirst(
          widget.groupId,
          content: content.isEmpty ? ' ' : content,
          userId: widget.me?.id ?? '',
          remindAt: _remindAt,
        );
        _controller.clear();
        _clearReminder();
        // Best-effort immediate sync; offline leaves the queued + synthetic
        // post in place until connectivity returns.
        unawaited(repo.drainOutboxOnce().catchError((_) {}));
        if (!mounted) return;
        unawaited(Haptics.light());
        AppToast.success(context, l10n.pinwallPinned);
        return;
      }

      final svc = await ref.read(pinwallServiceProviderAsync.future);
      final post = await svc.createPost(widget.groupId,
          content: content.isEmpty ? ' ' : content,
          remindAt: _remindAt,
          linkedEntityType: _linkedEntityType,
          linkedEntityId:
              _linkedEntityId?.isNotEmpty == true ? _linkedEntityId : null);
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
      _clearReminder();
      setState(() {
        _linkedEntityType = null;
        _linkedEntityId = null;
        _linkedEntityLabel = null;
      });
      final repo = await ref.read(pinwallRepositoryProvider.future);
      await repo.refreshPosts(widget.groupId).catchError((_) {});
      ref.invalidate(pinwallPostsByGroupProvider(widget.groupId));
      if (!mounted) return;
      unawaited(Haptics.light());
      AppToast.success(context, l10n.pinwallPinned);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final boardBg =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final boardBorder = dark
        ? MitlistColors.pinwallBoardBorderDark
        : MitlistColors.pinwallBoardBorder;
    final boardShadow =
        MitlistColors.neutral950.withValues(alpha: dark ? 0.38 : 0.16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child:
                    Text(l10n.pinwallBoardLabel, style: textTheme.titleMedium),
              ),
              _PinwallOpenBoardButton(
                groupId: widget.groupId,
                me: widget.me,
                boardBg: boardBg,
                boardBorder: boardBorder,
                dark: dark,
                textTheme: textTheme,
              ),
            ],
          ),
        ),
        Hero(
          tag: 'pinwall_board_${widget.groupId}',
          flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
            return AnimatedBuilder(
              animation: anim,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: boardBg,
                  borderRadius: BorderRadius.circular(
                    MitlistTheme.radiusLg * (1 - anim.value),
                  ),
                  border: Border.all(color: boardBorder, width: 2),
                ),
              ),
            );
          },
          child: Container(
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
                const SizedBox(height: MitlistSpacing.sm),
                _PinwallComposerNote(
                  controller: _controller,
                  isPosting: _isPosting,
                  isUploadingMedia: _isUploadingMedia,
                  pendingCount: _pendingMedia.length,
                  remindAt: _remindAt,
                  linkedEntityType: _linkedEntityType,
                  linkedEntityLabel: _linkedEntityLabel,
                  onPickReminder: _pickReminderTime,
                  onClearReminder: _clearReminder,
                  onPickMedia: _pickMedia,
                  onPost: _post,
                  onPickLinkedEntity: _pickLinkedEntity,
                ),
                const SizedBox(height: MitlistSpacing.sm),
                _PinwallQuickStats(groupId: widget.groupId),
                const SizedBox(height: MitlistSpacing.lg),
                RepaintBoundary(
                  child: _PinwallPostsList(
                    groupId: widget.groupId,
                    me: widget.me,
                    boardBorder: boardBorder,
                    dark: dark,
                    textTheme: textTheme,
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

class _PinwallOpenBoardButton extends ConsumerWidget {
  const _PinwallOpenBoardButton({
    required this.groupId,
    required this.me,
    required this.boardBg,
    required this.boardBorder,
    required this.dark,
    required this.textTheme,
  });

  final String groupId;
  final User? me;
  final Color boardBg;
  final Color boardBorder;
  final bool dark;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final posts = ref.watch(pinwallPostsByGroupProvider(groupId));

    return Semantics(
      label: l10n.pinwallOpenBoard,
      child: GestureDetector(
        onTap: () {
          Haptics.light();
          PinwallBoardScreen.show(
            context,
            groupId: groupId,
            me: me,
            posts: posts.value!,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.sm,
            vertical: MitlistSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: boardBg,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusFull),
            border: Border.all(color: boardBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_full_rounded,
                size: 13,
                color: dark
                    ? MitlistColors.pinwallNoteTextDark
                    : MitlistColors.pinwallNoteTextLight,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.pinwallOpenBoardBtn,
                style: textTheme.labelSmall?.copyWith(
                  color: dark
                      ? MitlistColors.pinwallNoteTextDark
                      : MitlistColors.pinwallNoteTextLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinwallPostsList extends ConsumerWidget {
  const _PinwallPostsList({
    required this.groupId,
    required this.me,
    required this.boardBorder,
    required this.dark,
    required this.textTheme,
  });

  final String groupId;
  final User? me;
  final Color boardBorder;
  final bool dark;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final posts = ref.watch(pinwallPostsByGroupProvider(groupId));

    return posts.when(
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
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Text(
                l10n.pinwallCouldNotLoad,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ),
            AppButton(
              text: l10n.commonRetry,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: () =>
                  ref.invalidate(pinwallPostsByGroupProvider(groupId)),
            ),
          ],
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.md),
            child: Text(
              l10n.pinwallEmptyBoard,
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final layout = pinwallHubLayout(constraints.maxWidth);

            return Wrap(
              spacing: MitlistSpacing.md,
              runSpacing: MitlistSpacing.lg,
              children: [
                for (var i = 0; i < show.length; i++)
                  PinwallNoteCard(
                    variant: PinwallNoteCardVariant.hub,
                    index: i,
                    groupId: groupId,
                    me: me,
                    post: show[i],
                    width: layout.cardWidth,
                    onOpenLinkedEntity: (ctx) =>
                        _navigateToLinkedEntity(ctx, show[i]),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PinwallComposerNote extends StatelessWidget {
  const _PinwallComposerNote({
    required this.controller,
    required this.isPosting,
    required this.isUploadingMedia,
    required this.pendingCount,
    required this.remindAt,
    this.linkedEntityType,
    this.linkedEntityLabel,
    required this.onPickReminder,
    required this.onClearReminder,
    required this.onPickMedia,
    required this.onPost,
    required this.onPickLinkedEntity,
  });

  final TextEditingController controller;
  final bool isPosting;
  final bool isUploadingMedia;
  final int pendingCount;
  final DateTime? remindAt;
  final String? linkedEntityType;
  final String? linkedEntityLabel;
  final Future<void> Function() onPickReminder;
  final VoidCallback onClearReminder;
  final Future<void> Function() onPickMedia;
  final Future<void> Function() onPost;
  final Future<void> Function() onPickLinkedEntity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark
        ? MitlistColors.composerBorderDark
        : MitlistColors.composerBorderLight;
    final pinColor = dark
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.primary;
    final textColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.9)
        : MitlistColors.pinwallNoteTextLight;
    final hintColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.38)
        : MitlistColors.pinwallNoteTextLight.withValues(alpha: 0.45);
    final dividerColor = border.withValues(alpha: dark ? 0.5 : 0.4);
    final reminderLabel = remindAt == null
        ? null
        : DateFormat('MMM d \u00b7 h:mm a').format(remindAt!);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: MitlistColors.neutral950
                    .withValues(alpha: dark ? 0.42 : 0.16),
                blurRadius: 0,
                offset: const Offset(4, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.lg + 6,
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                ),
                child: TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  style: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.pinwallPostHint,
                    hintStyle: textTheme.bodyMedium?.copyWith(
                      color: hintColor,
                      height: 1.5,
                    ),
                    filled: true,
                    fillColor: bg,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.sm,
                  vertical: MitlistSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: remindAt == null
                          ? l10n.pinwallAddReminder
                          : l10n.pinwallReminderSet(reminderLabel!),
                      icon: Icon(
                        remindAt == null
                            ? Icons.alarm_add_outlined
                            : Icons.alarm_on_outlined,
                        size: 20,
                        color: remindAt == null
                            ? textColor.withValues(alpha: 0.55)
                            : pinColor,
                      ),
                      onPressed: (isPosting || isUploadingMedia)
                          ? null
                          : onPickReminder,
                    ),
                    if (remindAt != null)
                      IconButton(
                        tooltip: l10n.pinwallClearReminder,
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: textColor.withValues(alpha: 0.55),
                        ),
                        onPressed: (isPosting || isUploadingMedia)
                            ? null
                            : onClearReminder,
                      ),
                    if (reminderLabel != null)
                      Flexible(
                        child: Padding(
                          padding:
                              const EdgeInsets.only(right: MitlistSpacing.xs),
                          child: Text(
                            reminderLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: pinColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: linkedEntityLabel != null
                          ? 'Linked to $linkedEntityLabel'
                          : l10n.pinwallLinkToChore,
                      icon: Icon(
                        linkedEntityType != null
                            ? Icons.link
                            : Icons.link_outlined,
                        size: 20,
                        color: linkedEntityType != null
                            ? pinColor
                            : textColor.withValues(alpha: 0.55),
                      ),
                      onPressed: (isPosting || isUploadingMedia)
                          ? null
                          : onPickLinkedEntity,
                    ),
                    IconButton(
                      tooltip: pendingCount == 0
                          ? l10n.pinwallAttachPhoto
                          : '$pendingCount photo${pendingCount == 1 ? '' : 's'} added',
                      icon: Icon(
                        pendingCount > 0
                            ? Icons.photo_library_outlined
                            : Icons.photo_outlined,
                        size: 20,
                        color: pendingCount > 0
                            ? pinColor
                            : textColor.withValues(alpha: 0.55),
                      ),
                      onPressed:
                          (isPosting || isUploadingMedia) ? null : onPickMedia,
                    ),
                    if (pendingCount > 0)
                      Text(
                        '$pendingCount',
                        style: textTheme.labelSmall?.copyWith(color: pinColor),
                      ),
                    Spacer(),
                    AppButton(
                      text: isUploadingMedia
                          ? l10n.pinwallUploading
                          : (isPosting
                              ? l10n.pinwallPosting
                              : l10n.pinwallPinIt),
                      icon: Icon(Icons.push_pin_outlined),
                      onPressed:
                          (isPosting || isUploadingMedia) ? null : onPost,
                      variant: AppButtonVariant.ghost,
                      color: AppButtonColor.primary,
                      size: AppButtonSize.sm,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -14,
          left: 0,
          right: 0,
          child: Center(
            child: PinwallPushpin(headColor: pinColor),
          ),
        ),
      ],
    );
  }
}

/// Compact, inline "torn paper" list of household stats that sits directly
/// under the composer note — Chores / Balance / Lists / Tonight, each a
/// tappable row that jumps to its tab.
///
/// Collapsed by default so the pinned notes surface sooner; tapping the header
/// expands the detail rows.
class _PinwallQuickStats extends StatefulWidget {
  const _PinwallQuickStats({required this.groupId});

  final String groupId;

  @override
  State<_PinwallQuickStats> createState() => _PinwallQuickStatsState();
}

class _PinwallQuickStatsState extends State<_PinwallQuickStats> {
  bool _expanded = false;

  void _toggle() {
    unawaited(Haptics.light());
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark
        ? MitlistColors.composerBorderDark
        : MitlistColors.composerBorderLight;
    final textColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.9)
        : MitlistColors.pinwallNoteTextLight;
    final mutedColor = textColor.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color:
                MitlistColors.neutral950.withValues(alpha: dark ? 0.42 : 0.16),
            blurRadius: 0,
            offset: const Offset(4, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: l10n.pinwallSnapshot,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.md,
                  vertical: MitlistSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights_outlined, size: 18, color: mutedColor),
                    const SizedBox(width: MitlistSpacing.sm),
                    Text(
                      l10n.pinwallSnapshot,
                      style: textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child:
                          Icon(Icons.expand_more, size: 20, color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatRowDivider(color: border),
                      PinwallChoresStatRow(
                        groupId: widget.groupId,
                        style: PinwallStatRowStyle.inline,
                        ink: textColor,
                        muted: mutedColor,
                      ),
                      _StatRowDivider(color: border),
                      PinwallFinanceStatRow(
                        groupId: widget.groupId,
                        style: PinwallStatRowStyle.inline,
                        ink: textColor,
                        muted: mutedColor,
                      ),
                      _StatRowDivider(color: border),
                      PinwallListsStatRow(
                        groupId: widget.groupId,
                        style: PinwallStatRowStyle.inline,
                        ink: textColor,
                        muted: mutedColor,
                      ),
                      _StatRowDivider(color: border),
                      _TonightStatRow(groupId: widget.groupId),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StatRowDivider extends StatelessWidget {
  const _StatRowDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: MitlistSpacing.md,
      endIndent: MitlistSpacing.md,
      color: color.withValues(alpha: 0.5),
    );
  }
}

class _TonightStatRow extends ConsumerWidget {
  const _TonightStatRow({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(todayMealPlansProvider(groupId));
    final theme = Theme.of(context).colorScheme;

    final meals = async.valueOrNull;
    String value;
    if (meals == null || meals.isEmpty) {
      value = l10n.tonightNothingPlanned;
    } else {
      TodayMeal? selected;
      for (final slot in const ['dinner', 'breakfast', 'lunch']) {
        selected = meals.firstWhereOrNull((m) => m.plan.slot == slot);
        if (selected != null) {
          break;
        }
      }
      selected ??= meals.first;
      value = selected.recipe?.title ?? l10n.tonightRecipe;
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.9)
        : MitlistColors.pinwallNoteTextLight;
    final muted = ink.withValues(alpha: 0.6);

    return PinwallStatRow(
      style: PinwallStatRowStyle.inline,
      icon: Icons.restaurant_outlined,
      label: l10n.tonightHeader,
      value: value,
      accent: theme.tertiary,
      ink: ink,
      muted: muted,
      onTap: () => context.pushNamed('mealPlan'),
    );
  }
}

void _navigateToLinkedEntity(BuildContext context, PinwallPost post) {
  final type = post.linkedEntityType;
  final id = post.linkedEntityId;
  if (type == null) return;
  switch (type) {
    case 'list':
      if (id != null && id.isNotEmpty) {
        context.go('/lists/$id');
      } else {
        context.go('/lists');
      }
    case 'chore':
      // Chores live in a shell tab branch; go() switches to the tab.
      context.go('/chores');
    case 'expense':
      // Money lives in a shell tab branch; go() switches to the tab.
      context.go('/money');
  }
}

class _EntityOption {
  final String id;
  final String label;
  const _EntityOption({required this.id, required this.label});
}
