import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/feature_board_models.dart';
import '../../services/feedback_service.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';

class FeatureBoardScreen extends ConsumerStatefulWidget {
  const FeatureBoardScreen({super.key});

  @override
  ConsumerState<FeatureBoardScreen> createState() => _FeatureBoardScreenState();
}

class _FeatureBoardScreenState extends ConsumerState<FeatureBoardScreen> {
  List<FeatureBoardItem> _items = const [];
  final Set<String> _votingIds = {};
  final ValueNotifier<bool> _createSheetDirty = ValueNotifier(false);
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _createSheetDirty.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_items.isEmpty && mounted) setState(() => _isLoading = true);
    try {
      final items = await ref.read(feedbackServiceProvider).listFeatureBoard();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.featureBoardLoadFailed;
        _isLoading = false;
      });
    }
  }

  Future<void> _upvote(FeatureBoardItem item) async {
    if (item.hasVoted || _votingIds.contains(item.id)) return;
    setState(() => _votingIds.add(item.id));
    try {
      final vote =
          await ref.read(feedbackServiceProvider).upvoteBoardFeature(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((entry) => entry.id == vote.requestId
                ? entry.copyWith(
                    voteCount: vote.voteCount,
                    hasVoted: vote.hasVoted,
                  )
                : entry)
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) {
        AppToast.error(
            context, AppLocalizations.of(context)!.featureBoardFailed);
      }
    } finally {
      if (mounted) setState(() => _votingIds.remove(item.id));
    }
  }

  Future<void> _openCreateSheet() async {
    final l10n = AppLocalizations.of(context)!;
    _createSheetDirty.value = false;

    final created = await showAppBottomSheet<bool>(
      context: context,
      title: l10n.featureBoardNewTitle,
      isDirtyListenable: _createSheetDirty,
      body: _FeatureBoardCreateForm(
        dirty: _createSheetDirty,
        onSubmit: ({required title, description}) =>
            ref.read(feedbackServiceProvider).submitBoardFeature(
                  title: title,
                  description: description,
                  sourcePage: '/you/feature-board',
                ),
      ),
    );

    if (created == true && mounted) {
      AppToast.success(context, l10n.featureBoardCreated);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.featureBoardTitle,
        showStandardActions: false,
        actions: [
          IconButton(
            onPressed: _openCreateSheet,
            icon: const AppIcon(name: 'plus'),
            tooltip: l10n.featureBoardAdd,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(MitlistSpacing.md),
          children: [
            _BoardIntro(onAdd: _openCreateSheet),
            const SizedBox(height: MitlistSpacing.lg),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              AppEmptyState(
                icon: const AppIcon(name: 'alertCircleOutline'),
                title: l10n.featureBoardLoadFailed,
                description: l10n.featureBoardTryAgain,
                isError: true,
                actions: [
                  AppButton(text: l10n.commonRetry, onPressed: _load),
                ],
              )
            else if (_items.isEmpty)
              AppEmptyState(
                icon: const AppIcon(name: 'chatBubbleLeftRight'),
                title: l10n.featureBoardNoFeaturesTitle,
                description: l10n.featureBoardNoFeaturesBody,
                actions: [
                  AppButton(
                    text: l10n.featureBoardAdd,
                    icon: const AppIcon(name: 'plus'),
                    onPressed: _openCreateSheet,
                  ),
                ],
              )
            else ...[
              _FeatureSection(
                title: l10n.featureBoardInProgress,
                items: _forStatus(FeatureBoardStatus.inProgress),
                votingIds: _votingIds,
                onUpvote: _upvote,
              ),
              _FeatureSection(
                title: l10n.featureBoardPlanned,
                items: _forStatus(FeatureBoardStatus.planned),
                votingIds: _votingIds,
                onUpvote: _upvote,
              ),
              _FeatureSection(
                title: l10n.featureBoardShipped,
                items: _forStatus(FeatureBoardStatus.shipped),
                votingIds: _votingIds,
                onUpvote: _upvote,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<FeatureBoardItem> _forStatus(FeatureBoardStatus status) {
    final items = _items.where((item) => item.status == status).toList();
    items.sort((a, b) => b.voteCount.compareTo(a.voteCount));
    return items;
  }
}

class _FeatureBoardCreateForm extends StatefulWidget {
  const _FeatureBoardCreateForm({
    required this.dirty,
    required this.onSubmit,
  });

  final ValueNotifier<bool> dirty;
  final Future<void> Function({required String title, String? description})
      onSubmit;

  @override
  State<_FeatureBoardCreateForm> createState() =>
      _FeatureBoardCreateFormState();
}

class _FeatureBoardCreateFormState extends State<_FeatureBoardCreateForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markDirty);
    _descriptionController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _titleController.removeListener(_markDirty);
    _descriptionController.removeListener(_markDirty);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _markDirty() {
    widget.dirty.value = _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.featureBoardEmpty);
      return;
    }
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        title: title,
        description: description.isEmpty ? null : description,
      );
      widget.dirty.value = false;
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = l10n.featureBoardFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.featureBoardNewIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (_error != null) ...[
          AppAlert(type: AppAlertType.error, message: _error!),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppInput(
          controller: _titleController,
          label: l10n.featureBoardTitleLabel,
          hint: l10n.featureBoardTitleHint,
          maxLength: 200,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          controller: _descriptionController,
          label: l10n.featureBoardDescriptionLabel,
          hint: l10n.featureBoardDescriptionHint,
          minLines: 3,
          maxLines: 6,
          maxLength: 5000,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        AppButton(
          text: _isSending
              ? l10n.featureBoardSubmitting
              : l10n.featureBoardSubmit,
          icon: const AppIcon(name: 'plus'),
          isLoading: _isSending,
          onPressed: _isSending ? null : _submit,
        ),
      ],
    );
  }
}

class _BoardIntro extends StatelessWidget {
  const _BoardIntro({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      variant: AppCardVariant.soft,
      tint: AppCardTint.primary,
      padding: AppCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                name: 'bolt',
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  l10n.featureBoardIntroTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            l10n.featureBoardIntroBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            text: l10n.featureBoardAdd,
            icon: const AppIcon(name: 'plus'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({
    required this.title,
    required this.items,
    required this.votingIds,
    required this.onUpvote,
  });

  final String title;
  final List<FeatureBoardItem> items;
  final Set<String> votingIds;
  final ValueChanged<FeatureBoardItem> onUpvote;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          for (var index = 0; index < items.length; index++) ...[
            _FeatureCard(
              item: items[index],
              isVoting: votingIds.contains(items[index].id),
              onUpvote: () => onUpvote(items[index]),
            ),
            if (index != items.length - 1)
              const SizedBox(height: MitlistSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
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
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description case final description?) ...[
                  const SizedBox(height: MitlistSpacing.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: MitlistSpacing.md),
          AppButton(
            text: l10n.featureBoardVotes(item.voteCount),
            icon: AppIcon(name: item.hasVoted ? 'check' : 'chevronUp'),
            size: AppButtonSize.sm,
            variant: item.hasVoted
                ? AppButtonVariant.soft
                : AppButtonVariant.outline,
            isLoading: isVoting,
            onPressed: item.hasVoted || isVoting ? null : onUpvote,
            semanticLabel: item.hasVoted
                ? l10n.featureBoardUpvoted
                : l10n.featureBoardUpvote,
          ),
        ],
      ),
    );
  }
}
