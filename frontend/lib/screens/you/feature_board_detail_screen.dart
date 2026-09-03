import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/feature_board_models.dart';
import '../../services/feedback_service.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import 'feature_board_widgets.dart';

/// One board request: what it is, where it stands, and the conversation
/// underneath it. Team replies are how "we're working on it" reaches people.
class FeatureBoardDetailScreen extends ConsumerStatefulWidget {
  const FeatureBoardDetailScreen({
    super.key,
    required this.requestId,
    this.initialItem,
  });

  final String requestId;

  /// The list entry, when we came from the board, so the header renders
  /// instantly while the thread loads.
  final FeatureBoardItem? initialItem;

  @override
  ConsumerState<FeatureBoardDetailScreen> createState() =>
      _FeatureBoardDetailScreenState();
}

class _FeatureBoardDetailScreenState
    extends ConsumerState<FeatureBoardDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  FeatureBoardDetail? _detail;
  bool _isLoading = true;
  bool _isVoting = false;
  bool _isPosting = false;
  bool _loadFailed = false;

  FeatureBoardItem? get _item => _detail?.item ?? widget.initialItem;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onComposerChanged);
    _load();
  }

  @override
  void dispose() {
    _commentController.removeListener(_onComposerChanged);
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onComposerChanged() => setState(() {});

  Future<void> _load() async {
    try {
      final detail = await ref
          .read(feedbackServiceProvider)
          .getFeatureBoardItem(widget.requestId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _upvote() async {
    final item = _item;
    if (item == null || item.hasVoted || _isVoting) return;
    setState(() => _isVoting = true);
    try {
      final vote =
          await ref.read(feedbackServiceProvider).upvoteBoardFeature(item.id);
      if (!mounted) return;
      final updated = item.copyWith(
        voteCount: vote.voteCount,
        hasVoted: vote.hasVoted,
      );
      setState(() {
        _detail = _detail?.copyWith(item: updated) ??
            FeatureBoardDetail(item: updated, comments: const []);
      });
    } catch (_) {
      if (mounted) {
        AppToast.error(
            context, AppLocalizations.of(context)!.featureBoardFailed);
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _postComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _isPosting) return;
    setState(() => _isPosting = true);
    try {
      final comment = await ref.read(feedbackServiceProvider).addBoardComment(
            requestId: widget.requestId,
            body: body,
          );
      if (!mounted) return;
      final current = _detail;
      setState(() {
        _commentController.clear();
        if (current != null) {
          _detail = current.copyWith(
            item: current.item
                .copyWith(commentCount: current.item.commentCount + 1),
            comments: [...current.comments, comment],
          );
        }
      });
      if (current == null) await _load();
    } catch (_) {
      if (mounted) {
        AppToast.error(
            context, AppLocalizations.of(context)!.featureBoardCommentFailed);
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = _item;
    final canCompose = item != null && !_loadFailed;

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.featureBoardTitle,
        showStandardActions: false,
      ),
      body: _loadFailed && item == null
          ? AppEmptyState(
              icon: const AppIcon(name: 'alertCircleOutline'),
              title: l10n.featureBoardDetailLoadFailed,
              description: l10n.featureBoardTryAgain,
              isError: true,
              actions: [
                AppButton(text: l10n.commonRetry, onPressed: _load),
              ],
            )
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(MitlistSpacing.md),
                children: [
                  if (item != null)
                    _RequestHeader(
                      item: item,
                      isVoting: _isVoting,
                      onUpvote: _upvote,
                    ),
                  const SizedBox(height: MitlistSpacing.lg),
                  Text(
                    l10n.featureBoardCommentsHeading.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: MitlistSpacing.sm),
                  if (_isLoading)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: MitlistSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_loadFailed)
                    AppEmptyState(
                      icon: const AppIcon(name: 'alertCircleOutline'),
                      title: l10n.featureBoardDetailLoadFailed,
                      description: l10n.featureBoardTryAgain,
                      isError: true,
                      paddingPreset: AppEmptyStatePadding.sm,
                      actions: [
                        AppButton(text: l10n.commonRetry, onPressed: _load),
                      ],
                    )
                  else if (_detail?.comments.isEmpty ?? true)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: MitlistSpacing.md,
                      ),
                      child: Text(
                        l10n.featureBoardNoComments,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    for (final comment in _detail!.comments) ...[
                      _CommentCard(comment: comment),
                      const SizedBox(height: MitlistSpacing.sm),
                    ],
                  // Keep the last comment clear of the composer.
                  const SizedBox(height: MitlistSpacing.xl),
                ],
              ),
            ),
      bottomNavigationBar: canCompose
          ? _Composer(
              controller: _commentController,
              focusNode: _commentFocus,
              isPosting: _isPosting,
              canSend: _commentController.text.trim().isNotEmpty,
              onSend: _postComment,
            )
          : null,
    );
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({
    required this.item,
    required this.isVoting,
    required this.onUpvote,
  });

  final FeatureBoardItem item;
  final bool isVoting;
  final VoidCallback onUpvote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: MitlistSpacing.space2,
            runSpacing: MitlistSpacing.space1,
            children: [
              FeatureBoardStatusChip(status: item.status),
              FeatureBoardKindChip(kind: item.kind),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(item.title, style: theme.textTheme.titleLarge),
          if (item.description case final description?) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: MitlistSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FeatureBoardVoteButton(
                voteCount: item.voteCount,
                hasVoted: item.hasVoted,
                isVoting: isVoting,
                onPressed: onUpvote,
              ),
              const SizedBox(width: MitlistSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featureBoardStatusHint(l10n, item.status),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: MitlistSpacing.xs),
                    Text(
                      '${l10n.featureBoardVotes(item.voteCount)} · '
                      '${l10n.featureBoardComments(item.commentCount)} · '
                      '${featureBoardRelativeTime(l10n, item.createdAt)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final FeatureBoardComment comment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final author = comment.isFromTeam
        ? (comment.authorName ?? l10n.featureBoardTeamBadge)
        : comment.isMine
            ? l10n.featureBoardYou
            : (comment.authorName ?? l10n.featureBoardAnonymous);

    return AppCard(
      variant:
          comment.isFromTeam ? AppCardVariant.soft : AppCardVariant.outlined,
      tint: comment.isFromTeam ? AppCardTint.primary : AppCardTint.neutral,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (comment.isFromTeam) ...[
                AppIcon(
                  name: 'verified',
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: MitlistSpacing.space1),
              ],
              Flexible(
                child: Text(
                  author,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: comment.isFromTeam ? colorScheme.primary : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (comment.isFromTeam && comment.authorName != null) ...[
                const SizedBox(width: MitlistSpacing.space2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.space2,
                    vertical: MitlistSpacing.space0_5,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(MitlistTheme.radiusSm),
                    ),
                  ),
                  child: Text(
                    l10n.featureBoardTeamBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                featureBoardRelativeTime(l10n, comment.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(comment.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isPosting,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isPosting;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MitlistSpacing.md,
            MitlistSpacing.sm,
            MitlistSpacing.md,
            MitlistSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppInput(
                  controller: controller,
                  focusNode: focusNode,
                  hint: l10n.featureBoardCommentHint,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  enabled: !isPosting,
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AppButton(
                icon: const AppIcon(name: 'send'),
                size: AppButtonSize.md,
                isLoading: isPosting,
                onPressed: canSend && !isPosting ? onSend : null,
                semanticLabel: l10n.featureBoardCommentSend,
                tooltip: l10n.featureBoardCommentSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
