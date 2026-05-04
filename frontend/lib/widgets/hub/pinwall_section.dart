import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/auth_models.dart';
import '../../models/pinwall_media_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/haptics.dart';
import '../../utils/hub_helpers.dart';
import '../app_button.dart';

final pinwallMediaByPostProvider = FutureProvider.family<
    List<PinwallMediaItem>, ({String groupId, String postId})>(
  (ref, args) async {
    final svc = await ref.read(pinwallServiceProviderAsync.future);
    return svc.listPostAttachments(groupId: args.groupId, postId: args.postId);
  },
);

const _kNotePalette = MitlistColors.notePalette;
const _kNotePaletteDark = MitlistColors.notePaletteDark;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime() async {
    if (_isPosting || _isUploadingMedia) return;
    Haptics.light();

    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _remindAt?.isAfter(now) == true ? _remindAt! : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Choose reminder date',
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindAt ?? now),
      helpText: 'Choose reminder time',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a time in the future.')),
      );
      return;
    }
    setState(() => _remindAt = combined);
  }

  void _clearReminder() {
    if (_remindAt == null) return;
    setState(() => _remindAt = null);
  }

  Future<void> _pickLinkedEntity() async {
    if (_isPosting || _isUploadingMedia) return;
    Haptics.light();

    final typeAction = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Link to\u2026',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: MitlistSpacing.md),
              AppButton(
                text: 'A chore',
                onPressed: () => Navigator.of(ctx).pop('chore'),
              ),
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                text: 'A list',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(ctx).pop('list'),
              ),
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                text: 'An expense',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(ctx).pop('expense'),
              ),
              if (_linkedEntityType != null) ...[
                const SizedBox(height: MitlistSpacing.sm),
                AppButton(
                  text: 'Remove link',
                  variant: AppButtonVariant.ghost,
                  color: AppButtonColor.error,
                  onPressed: () => Navigator.of(ctx).pop('remove'),
                ),
              ],
            ],
          ),
        ),
      ),
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
          options = chores.take(50).map((c) => _EntityOption(
                id: c.chore.id,
                label: c.chore.name,
              )).toList();
        case 'list':
          final svc = await ref.read(listServiceProviderAsync.future);
          final lists = await svc.listLists(groupId, limit: 50);
          options = lists.map((l) => _EntityOption(
                id: l.id,
                label: l.name,
              )).toList();
        case 'expense':
          final svc = await ref.read(financeServiceProviderAsync.future);
          final expenses = await svc.listExpenses(groupId, limit: 50);
          options = expenses.map((e) => _EntityOption(
                id: e.id,
                label: e.description,
              )).toList();
        default:
          return;
      }

      if (!mounted || options.isEmpty) return;

      final picked = await showModalBottomSheet<_EntityOption>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Select a ${typeAction}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MitlistSpacing.md),
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
            ),
          ),
        ),
      );

      if (!mounted || picked == null) return;
      setState(() {
        _linkedEntityType = typeAction;
        _linkedEntityId = picked.id;
        _linkedEntityLabel = picked.label;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t load entities.')),
      );
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
    try {
      final svc = await ref.read(pinwallServiceProviderAsync.future);
      final post = await svc.createPost(widget.groupId,
          content: content.isEmpty ? ' ' : content,
          remindAt: _remindAt,
          linkedEntityType: _linkedEntityType,
          linkedEntityId: _linkedEntityId?.isNotEmpty == true
              ? _linkedEntityId
              : null);
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

    final boardBg =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final boardBorder = dark
        ? MitlistColors.pinwallBoardBorderDark
        : MitlistColors.pinwallBoardBorder;
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
                remindAt: _remindAt,
                linkedEntityType: _linkedEntityType,
                linkedEntityLabel: _linkedEntityLabel,
                onPickReminder: _pickReminderTime,
                onClearReminder: _clearReminder,
                onPickMedia: _pickMedia,
                onPost: _post,
                onPickLinkedEntity: _pickLinkedEntity,
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
                    borderRadius:
                        BorderRadius.circular(MitlistTheme.radiusLg),
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
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark
        ? MitlistColors.composerBorderDark
        : MitlistColors.composerBorderLight;
    final pinColor = dark ? MitlistColors.primary300 : MitlistColors.primary600;
    final textColor = dark
        ? Colors.white.withValues(alpha: 0.9)
        : MitlistColors.pinwallNoteTextLight;
    final hintColor = dark
        ? Colors.white.withValues(alpha: 0.38)
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
                color: Colors.black.withValues(alpha: dark ? 0.42 : 0.16),
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
                    hintText:
                        'Post a note to the household\u2026',
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
                          ? 'Add reminder'
                          : 'Reminder set for $reminderLabel. Tap to change.',
                      icon: Icon(
                        remindAt == null
                            ? Icons.alarm_add_outlined
                            : Icons.alarm_on_outlined,
                        size: 20,
                        color: remindAt == null
                            ? textColor.withValues(alpha: 0.55)
                            : pinColor,
                      ),
                      onPressed:
                          (isPosting || isUploadingMedia) ? null : onPickReminder,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (remindAt != null)
                      IconButton(
                        tooltip: 'Clear reminder',
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: textColor.withValues(alpha: 0.55),
                        ),
                        onPressed:
                            (isPosting || isUploadingMedia) ? null : onClearReminder,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (reminderLabel != null)
                      Padding(
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
                    IconButton(
                      tooltip: linkedEntityLabel != null
                          ? 'Linked to $linkedEntityLabel'
                          : 'Link to a chore, list\u2026',
                      icon: Icon(
                        linkedEntityType != null
                            ? Icons.link
                            : Icons.link_outlined,
                        size: 20,
                        color: linkedEntityType != null
                            ? pinColor
                            : textColor.withValues(alpha: 0.55),
                      ),
                      onPressed:
                          (isPosting || isUploadingMedia) ? null : onPickLinkedEntity,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: pendingCount == 0
                          ? 'Attach photo'
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
                      visualDensity: VisualDensity.compact,
                    ),
                    if (pendingCount > 0)
                      Text(
                        '$pendingCount',
                        style: textTheme.labelSmall?.copyWith(color: pinColor),
                      ),
                    const Spacer(),
                    AppButton(
                      text: isUploadingMedia
                          ? 'Uploading\u2026'
                          : (isPosting ? 'Posting\u2026' : 'Pin it'),
                      icon: const Icon(Icons.push_pin_outlined),
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
            child: _Pushpin(headColor: pinColor),
          ),
        ),
      ],
    );
  }
}

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
        try {
          final attachSvc =
              await ref.read(attachmentServiceProviderAsync.future);
          await attachSvc.deleteAttachment(
            groupId: groupId,
            attachmentId: media.attachmentId,
          );
        } catch (_) {
          debugPrint(
              '[Pinwall] Media cleanup failed for ${media.attachmentId}');
        }
        ref.invalidate(
          pinwallMediaByPostProvider((groupId: groupId, postId: post.id)),
        );
      } catch (_) {
        if (context.mounted) {
          _showErrorSnack(context, 'Couldn\u2019t remove photo.');
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
        pinwallMediaByPostProvider((groupId: groupId, postId: post.id)),
      );
    } catch (_) {
      if (context.mounted) {
        _showErrorSnack(context, 'Couldn\u2019t add photo.');
      }
    }
  }

  void _navigateToLinkedEntity(BuildContext context) {
    final type = post.linkedEntityType;
    final id = post.linkedEntityId;
    if (type == null) return;
    switch (type) {
      case 'list':
        if (id != null && id.isNotEmpty) {
          context.pushNamed('listDetail', pathParameters: {'listId': id});
        }
      case 'chore':
        context.pushNamed('chores');
      case 'expense':
        context.pushNamed('money');
    }
  }

  String _entityDisplayLabel(String type) {
    switch (type) {
      case 'list':
        return 'Linked list';
      case 'chore':
        return 'Linked chore';
      case 'expense':
        return 'Linked expense';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final userId = post.userId;
    final content = post.content.trim();
    final createdAt = post.createdAt;
    final userLabel = formatUserLabel(userId, me?.id);
    final when = relativeDay(createdAt);

    final idHash = post.id.hashCode;
    final rot = ((idHash % 13) - 6) * 0.012;

    final palette = dark ? _kNotePaletteDark : _kNotePalette;
    final bg = palette[(idHash.abs()) % palette.length];
    final border = bg.withValues(alpha: dark ? 0.3 : 0.6);

    const pinColors = [
      MitlistColors.primary600,
      MitlistColors.teal500,
      MitlistColors.error600,
    ];
    final pinColor = pinColors[index % pinColors.length];

    final media = ref.watch(
      pinwallMediaByPostProvider((groupId: groupId, postId: post.id)),
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

    final remindAt = post.remindAt;
    final reminderSentAt = post.reminderSentAt;
    final reminderText = remindAt == null
        ? null
        : DateFormat('MMM d \u00b7 h:mm a').format(remindAt.toLocal());

    return Transform.rotate(
      angle: rot.toDouble(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                if (post.linkedEntityType != null)
                  GestureDetector(
                    onTap: () => _navigateToLinkedEntity(context),
                    child: Padding(
                      padding: const EdgeInsets.only(top: MitlistSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.link, size: 12, color: mutedColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _entityDisplayLabel(post.linkedEntityType!),
                              style: textTheme.labelSmall?.copyWith(
                                color: mutedColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 12, color: mutedColor),
                        ],
                      ),
                    ),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 6),
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
                if (reminderText != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: MitlistSpacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          reminderSentAt == null
                              ? Icons.alarm_on_outlined
                              : Icons.check_circle_outline,
                          size: 14,
                          color: mutedColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reminderSentAt == null
                                ? 'Reminder \u00b7 $reminderText'
                                : 'Reminded \u00b7 $reminderText',
                            style: textTheme.labelSmall
                                ?.copyWith(color: mutedColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$userLabel \u00b7 $when',
                        style: textTheme.labelSmall
                            ?.copyWith(color: mutedColor),
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
                        PopupMenuItem(
                            value: 'photo', child: Text('Add photo')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(MitlistSpacing.sm),
                        child: Icon(Icons.more_horiz,
                            size: MitlistSpacing.space5, color: mutedColor),
                      ),
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
      ),
    );
  }
}

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

class _EntityOption {
  final String id;
  final String label;
  const _EntityOption({required this.id, required this.label});
}
