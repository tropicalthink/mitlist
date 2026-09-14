import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../models/pinwall_media_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/haptics.dart';
import '../../utils/hub_helpers.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';
import '../app_dialog.dart';
import '../mitlist_app_bar.dart';
import '../pinwall_link_chip.dart';
import '../hub/pinned_memo_card.dart';

import '../app_toast.dart';

const _kNotePalette = MitlistColors.notePalette;
const _kNotePaletteDark = MitlistColors.notePaletteDark;

/// Which surface the card is rendered on. The two surfaces share the same
/// note body (content, media, reminder, footer) but differ in chrome and
/// interactivity:
///  - [hub]: the compact hub-wall card. Supports tap/long-press media
///    actions (view, remove) and a footer menu (add photo, delete).
///  - [board]: the full-screen cork board card. Read-only (drag handled by
///    the board's own draggable wrapper) with a fixed card width tuned for
///    the board's grid layout, and uses [PinwallLinkChip] for the linked
///    entity affordance instead of the hub's inline row.
enum PinwallNoteCardVariant { hub, board }

/// The shared body of a pinned note, used by both `PinwallSection` (hub) and
/// `PinwallBoardScreen`. Board-only chrome (cork/drag) stays in the board
/// screen, which wraps this widget in its own draggable container.
class PinwallNoteCard extends ConsumerWidget {
  const PinwallNoteCard({
    super.key,
    required this.variant,
    required this.index,
    required this.groupId,
    required this.me,
    required this.post,
    required this.onOpenLinkedEntity,
    this.onEdit,
    this.width,
  });

  final PinwallNoteCardVariant variant;
  final int index;
  final String groupId;
  final User? me;
  final PinwallPost post;

  /// Opens the note editor (text, color, size). On the board a tap on the
  /// card triggers it; on the hub it appears as an "Edit" menu item. Null
  /// hides the affordance.
  final VoidCallback? onEdit;

  /// Overrides the variant's default card width.
  ///
  /// The hub computes this from the width actually available so a whole number
  /// of cards fills each row. A fixed width can't do that: once the viewport is
  /// narrower than two cards plus spacing — which happens on ordinary phones
  /// once the system display-size setting is raised — the wrap breaks to one
  /// card per row and leaves the rest of the row empty.
  final double? width;

  /// Navigates to the entity this post is linked to. Each surface owns its
  /// own navigation (the hub and the board route slightly differently), so
  /// this is supplied by the caller rather than hard-coded here.
  final void Function(BuildContext context) onOpenLinkedEntity;

  bool get _isHub => variant == PinwallNoteCardVariant.hub;

  void _showErrorSnack(BuildContext context, String message) {
    AppToast.error(context, message);
  }

  void _openMediaViewer(BuildContext context, PinwallMediaItem m) {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: MitlistColors.neutral950,
          appBar: MitlistAppBar(
            showStandardActions: false,
            title: const SizedBox.shrink(),
            leading: IconButton(
              tooltip: l10n.commonClose,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 6,
              child: Image.network(
                m.url,
                fit: BoxFit.contain,
                cacheWidth: (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context) *
                        1.5)
                    .round(),
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: Text(
                    l10n.pinwallCouldNotLoadImage,
                    style: TextStyle(color: MitlistColors.surfaceSoft),
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
    unawaited(Haptics.light());
    final l10n = AppLocalizations.of(context)!;
    final action = await showAppBottomSheet<String>(
      context: context,
      title: l10n.commonPhoto,
      body: Builder(builder: (ctx) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              text: l10n.commonView,
              onPressed: () => Navigator.of(ctx).pop('view'),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.pinwallRemoveFromPost,
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(ctx).pop('remove'),
            ),
          ],
        );
      }),
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
          _showErrorSnack(context, l10n.pinwallCouldNotRemovePhoto);
        }
      }
    }
  }

  Future<void> _addMediaToPost(BuildContext context, WidgetRef ref) async {
    unawaited(Haptics.light());
    final l10n = AppLocalizations.of(context)!;
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
          contentType: f.mimeType ?? '',
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
        _showErrorSnack(context, l10n.pinwallCouldNotAddPhoto);
      }
    }
  }

  String _entityDisplayLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'list':
        return l10n.pinwallLinkedList;
      case 'chore':
        return l10n.pinwallLinkedChore;
      case 'expense':
        return l10n.pinwallLinkedExpense;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final content = post.content.trim();
    final userLabel = formatUserLabel(post.userId, me?.id, l10n);
    final when = relativeDay(post.createdAt);

    final idHash = post.id.hashCode;
    final rot = ((idHash % 13) - 6) * 0.012;

    // An explicitly chosen color wins; otherwise fall back to the stable
    // id-hash palette pick so legacy notes keep the color they always had.
    final palette = dark ? _kNotePaletteDark : _kNotePalette;
    final paletteByName = dark
        ? MitlistColors.notePaletteByNameDark
        : MitlistColors.notePaletteByName;
    final bg =
        paletteByName[post.color] ?? palette[(idHash.abs()) % palette.length];
    final border = bg.withValues(alpha: dark ? 0.3 : 0.6);

    final pinColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.error,
    ];
    final pinColor = pinColors[index % pinColors.length];

    final media = ref.watch(
      pinwallMediaByPostProvider((groupId: groupId, postId: post.id)),
    );

    final textColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.9)
        : Theme.of(context).colorScheme.onSurface;
    final mutedColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    final remindAt = post.remindAt;
    final reminderSentAt = post.reminderSentAt;
    final reminderText = remindAt == null
        ? null
        : DateFormat('MMM d · h:mm a').format(remindAt.toLocal());

    // ── Variant-tuned card dimensions/chrome ──────────────────────────────
    // On the board a note's chosen size drives its footprint. The hub keeps
    // its uniform row-filling width — size is a spatial property of the board.
    final String sizeKey = post.size ?? 'medium';
    final double boardWidth = switch (sizeKey) {
      'small' => 150,
      'large' => 250,
      _ => 180,
    };
    final double cardWidth = width ?? (_isHub ? 160 : boardWidth);
    // The screen-relative clamp only guards the fixed fallback width; an
    // explicit width is already derived from the available space.
    final BoxConstraints? cardConstraints = (_isHub && width == null)
        ? BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7)
        : null;
    final double borderRadius = _isHub ? 6 : MitlistTheme.radiusSm;
    final int contentMaxLines = _isHub
        ? 8
        : switch (sizeKey) {
            'small' => 6,
            'large' => 16,
            _ => 10,
          };
    final Size pinSize = _isHub ? const Size(22, 28) : const Size(26, 32);
    final int mediaMaxCount = _isHub ? 5 : 4;
    final double mediaThumbSize = _isHub ? 42 : 48;
    // Height of the board's lead photo; scales with the note size so a large
    // note shows a genuinely large picture.
    final double mediaHeroHeight = switch (sizeKey) {
      'small' => 76,
      'large' => 150,
      _ => 100,
    };

    Future<void> onDelete() async {
      unawaited(Haptics.light());
      final repo = await ref.read(pinwallRepositoryProvider.future);
      // Offline-first: removes the note from the cache immediately (the Drift
      // stream re-paints) and queues the server delete for the next drain.
      await repo.deletePostOfflineFirst(groupId, post.id);
      unawaited(repo.drainOutboxOnce().catchError((_) {}));
    }

    Widget mediaRow() {
      return media.when(
        loading: () => _isHub
            ? Padding(
                padding: const EdgeInsets.only(top: MitlistSpacing.xs),
                child: SizedBox(
                  height: 42,
                  child: Row(
                    children: [
                      Container(
                        width: mediaThumbSize,
                        height: mediaThumbSize,
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox(height: 42),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          if (!_isHub) {
            // Board: the first photo renders large so pictures actually read
            // from the cork; the rest line up as tappable thumbnails below.
            final primary = items.first;
            final rest = items.skip(1).take(mediaMaxCount - 1).toList();
            Widget photo(PinwallMediaItem m, Widget child) {
              return Semantics(
                button: true,
                label: l10n.listItemViewPhoto,
                child: GestureDetector(
                  onTap: () => _openMediaViewer(context, m),
                  onLongPress: () => _showMediaActions(context, ref, media: m),
                  child: child,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(top: MitlistSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  photo(
                    primary,
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusSm),
                      child: SizedBox(
                        height: mediaHeroHeight,
                        child: Image.network(
                          primary.url,
                          fit: BoxFit.cover,
                          cacheWidth: (cardWidth *
                                  MediaQuery.devicePixelRatioOf(context) *
                                  1.5)
                              .round(),
                          errorBuilder: (_, __, ___) => Container(
                            color: border.withValues(alpha: 0.3),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (rest.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: MitlistSpacing.xs),
                      child: SizedBox(
                        height: mediaThumbSize,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rest.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: MitlistSpacing.xs),
                          itemBuilder: (context, i) {
                            final m = rest[i];
                            return photo(
                              m,
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    MitlistTheme.radiusSm),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Image.network(
                                    m.url,
                                    fit: BoxFit.cover,
                                    cacheWidth: (mediaThumbSize *
                                            MediaQuery.devicePixelRatioOf(
                                                context) *
                                            1.5)
                                        .round(),
                                    errorBuilder: (_, __, ___) => Container(
                                      color: border.withValues(alpha: 0.3),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
          final show = items.length > mediaMaxCount
              ? items.take(mediaMaxCount).toList()
              : items;
          return Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.xs),
            child: SizedBox(
              height: mediaThumbSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: _isHub ? null : const NeverScrollableScrollPhysics(),
                itemCount: show.length,
                separatorBuilder: (_, __) => SizedBox(
                  width: _isHub ? 6 : MitlistSpacing.xs,
                ),
                itemBuilder: (context, i) {
                  final m = show[i];
                  final thumb = ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _isHub ? 0 : MitlistTheme.radiusSm,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        m.url,
                        fit: BoxFit.cover,
                        cacheWidth: (mediaThumbSize *
                                MediaQuery.devicePixelRatioOf(context) *
                                1.5)
                            .round(),
                        errorBuilder: (_, __, ___) => Container(
                          color: _isHub
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow
                                  .withValues(alpha: 0.25)
                              : border.withValues(alpha: 0.3),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: _isHub ? 16 : 14,
                          ),
                        ),
                      ),
                    ),
                  );
                  return GestureDetector(
                    onTap: () => _openMediaViewer(context, m),
                    onLongPress: () =>
                        _showMediaActions(context, ref, media: m),
                    child: Semantics(
                      button: true,
                      label: l10n.listItemViewPhoto,
                      child: ClipRect(child: thumb),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    Widget linkedEntityRow() {
      if (post.linkedEntityType == null) return const SizedBox.shrink();
      final type = post.linkedEntityType!;
      if (!_isHub) {
        return Padding(
          padding: const EdgeInsets.only(top: MitlistSpacing.xs),
          child: PinwallLinkChip(
            entityType: type,
            color: mutedColor,
            onTap: () => onOpenLinkedEntity(context),
          ),
        );
      }
      final label = _entityDisplayLabel(type, l10n);
      return Semantics(
        button: true,
        label: l10n.pinwallOpenLinkedEntity(label),
        child: Tooltip(
          message: l10n.pinwallOpenLinkedEntity(label),
          child: GestureDetector(
            onTap: () => onOpenLinkedEntity(context),
            child: Padding(
              padding: const EdgeInsets.only(top: MitlistSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.link, size: 12, color: mutedColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Open $label',
                      style: textTheme.labelSmall?.copyWith(color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 12, color: mutedColor),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget footerRow() {
      if (!_isHub) {
        return Text(
          '$userLabel · $when',
          style: textTheme.labelSmall?.copyWith(color: mutedColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
      return Row(
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
            tooltip: l10n.pinwallPostOptions,
            onSelected: (v) async {
              if (v == 'edit') {
                onEdit?.call();
                return;
              }
              if (v == 'photo') {
                await _addMediaToPost(context, ref);
                return;
              }
              if (v == 'delete') {
                if (!context.mounted) return;
                final confirmed = await showAppDialog<bool>(
                  context: context,
                  title: l10n.pinwallDeletePin,
                  body: Text(l10n.pinwallDeletePinBody),
                  // The dialog is pushed on the root navigator, but the hub
                  // sits inside a shell branch with its own — popping the
                  // nearest one would tear the hub off its branch and leave
                  // the dialog stranded instead of answering it.
                  actions: [
                    AppButton(
                      text: l10n.commonCancel,
                      variant: AppButtonVariant.outline,
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
                    ),
                    const SizedBox(width: MitlistSpacing.sm),
                    AppButton(
                      text: l10n.commonDelete,
                      color: AppButtonColor.error,
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(true),
                    ),
                  ],
                );
                if (confirmed == true) await onDelete();
              }
            },
            itemBuilder: (_) => [
              if (onEdit != null)
                PopupMenuItem(value: 'edit', child: Text(l10n.pinwallEditNote)),
              PopupMenuItem(
                  value: 'photo', child: Text(l10n.pinwallAddPhotoMenu)),
              PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
            ],
            child: Padding(
              padding: const EdgeInsets.all(MitlistSpacing.sm),
              child: Icon(Icons.more_horiz,
                  size: MitlistSpacing.space5, color: mutedColor),
            ),
          ),
        ],
      );
    }

    final card = Transform.rotate(
      angle: rot.toDouble(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: cardWidth,
            constraints: cardConstraints,
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.sm + 4,
              MitlistSpacing.lg,
              MitlistSpacing.sm,
              MitlistSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: MitlistColors.neutral950.withValues(
                      alpha:
                          dark ? (_isHub ? 0.42 : 0.5) : (_isHub ? 0.16 : 0.2)),
                  blurRadius: _isHub ? 0 : 12,
                  offset: _isHub ? const Offset(4, 5) : const Offset(4, 6),
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
                  maxLines: contentMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isHub) ...[
                  linkedEntityRow(),
                  mediaRow(),
                  const SizedBox(height: MitlistSpacing.xs),
                  if (reminderText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
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
                                  ? l10n.pinwallReminderLabel(reminderText)
                                  : l10n.pinwallRemindedLabel(reminderText),
                              style: textTheme.labelSmall
                                  ?.copyWith(color: mutedColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  footerRow(),
                ] else ...[
                  mediaRow(),
                  if (reminderText != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          top: MitlistSpacing.xs, bottom: MitlistSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.alarm_on_outlined,
                              size: 12, color: mutedColor),
                          const SizedBox(width: MitlistSpacing.xs),
                          Expanded(
                            child: Text(
                              reminderText,
                              style: textTheme.labelSmall
                                  ?.copyWith(color: mutedColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: MitlistSpacing.xs),
                  footerRow(),
                  linkedEntityRow(),
                ],
              ],
            ),
          ),
          Positioned(
            top: -14,
            left: 0,
            right: 0,
            child: Center(
              child: PinwallPushpin(headColor: pinColor, size: pinSize),
            ),
          ),
        ],
      ),
    );

    if (_isHub) return card;
    // On the board a plain tap opens the editor. Child gestures (photos,
    // linked-entity chip) still win their own taps; the board's drag wrapper
    // keeps handling pans.
    final Widget boardCard =
        onEdit == null ? card : GestureDetector(onTap: onEdit, child: card);
    return Semantics(
      label: l10n.pinwallNoteSemantics(userLabel, content),
      button: onEdit != null,
      hint: onEdit != null ? l10n.pinwallEditNote : null,
      child: boardCard,
    );
  }
}
