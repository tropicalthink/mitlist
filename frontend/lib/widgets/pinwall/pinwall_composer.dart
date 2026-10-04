import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/reminder_picker.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';
import '../app_toast.dart';
import '../hub/pinned_memo_card.dart';

/// The full pinwall note composer: text, reminder, linked entity
/// (chore/list/expense), and photo attachments. Shared between the hub's
/// inline pinwall section and the full-screen board's "Add a note" sheet so
/// both surfaces have the same capabilities.
class PinwallComposer extends ConsumerStatefulWidget {
  const PinwallComposer({
    super.key,
    required this.groupId,
    required this.me,
    this.autofocus = false,
    this.onPosted,
  });

  final String groupId;
  final User? me;

  /// Focus the text field on mount — used inside the board's sheet, where
  /// composing is the only reason the sheet is open.
  final bool autofocus;

  /// Called once a post has been accepted: queued offline-first, or created
  /// on the server with all media uploaded. The board sheet closes on it.
  final VoidCallback? onPosted;

  @override
  ConsumerState<PinwallComposer> createState() => _PinwallComposerState();
}

class _PinwallComposerState extends ConsumerState<PinwallComposer> {
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
    final l10n = AppLocalizations.of(context)!;
    if (_isPosting || _isUploadingMedia) return;
    unawaited(Haptics.light());

    final now = DateTime.now();
    final seed = reminderPickerSeed(_remindAt, now);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: l10n.pinwallChooseReminderDate,
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
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

  /// The offline-first pin, done optimistically: the composer empties on the
  /// tap and the note arrives from the local DB stream a frame or two later.
  /// Flipping [_isPosting] here used to flash a spinner in the post button for
  /// the few milliseconds of local writes — a loading state for work that is
  /// never actually pending. If the enqueue itself fails, the text and the
  /// reminder come back exactly as they were typed.
  Future<void> _postOptimistically(String content) async {
    final l10n = AppLocalizations.of(context)!;
    final restoreText = _controller.text;
    final restoreRemindAt = _remindAt;

    _controller.clear();
    _clearReminder();
    unawaited(Haptics.light());

    try {
      final repo = await ref.read(pinwallRepositoryProvider.future);
      await repo.createPostOfflineFirst(
        widget.groupId,
        content: content.isEmpty ? ' ' : content,
        userId: widget.me?.id ?? '',
        remindAt: restoreRemindAt,
      );
      // Queued for the sync session; offline leaves the queued + synthetic
      // post in place until connectivity returns.
      repo.noteLocalWrite();
      if (mounted) widget.onPosted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _controller.text = restoreText;
        _controller.selection = TextSelection.collapsed(
          offset: restoreText.length,
        );
        _remindAt = restoreRemindAt;
      });
      unawaited(Haptics.failure());
      AppToast.error(context, friendlyErrorMessage(e, l10n));
    }
  }

  Future<void> _post() async {
    final content = _controller.text.trim();
    if ((content.isEmpty && _pendingMedia.isEmpty) || _isPosting) return;

    // Plain-text posts (no media, no linked entity) go through the
    // offline-first path so they pin immediately and work without a
    // connection. Media/linked posts still require the server.
    final canQueueOffline =
        _pendingMedia.isEmpty && (_linkedEntityId?.isEmpty ?? true);
    if (canQueueOffline) {
      await _postOptimistically(content);
      return;
    }

    setState(() => _isPosting = true);
    final l10n = AppLocalizations.of(context)!;
    try {
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
              contentType: f.mimeType ?? '',
              bytes: bytes,
            );
            await svc.attachPostAttachment(
              groupId: widget.groupId,
              postId: post.id,
              attachmentId: a.id,
            );
          }
        } catch (_) {
          // The note itself is already pinned; failing silently here left
          // users thinking the photo saved when it never reached storage.
          if (mounted) {
            unawaited(Haptics.failure());
            AppToast.error(context, l10n.pinwallCouldNotAddPhoto);
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
      widget.onPosted?.call();
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PinwallComposerNote(
      controller: _controller,
      autofocus: widget.autofocus,
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
    );
  }
}

class _PinwallComposerNote extends StatelessWidget {
  const _PinwallComposerNote({
    required this.controller,
    required this.autofocus,
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
  final bool autofocus;
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
        : DateFormat('MMM d · h:mm a').format(remindAt!);

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
                  autofocus: autofocus,
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

class _EntityOption {
  final String id;
  final String label;
  const _EntityOption({required this.id, required this.label});
}
