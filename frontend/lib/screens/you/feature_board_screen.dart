import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import 'feature_board_widgets.dart';

class FeatureBoardScreen extends ConsumerStatefulWidget {
  const FeatureBoardScreen({super.key});

  @override
  ConsumerState<FeatureBoardScreen> createState() => _FeatureBoardScreenState();
}

class _FeatureBoardScreenState extends ConsumerState<FeatureBoardScreen> {
  List<FeatureBoardItem> _items = const [];
  final Set<String> _votingIds = {};
  final ValueNotifier<bool> _createSheetDirty = ValueNotifier(false);
  FeatureBoardKind? _kind;
  FeatureBoardSort _sort = FeatureBoardSort.top;
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
    final kind = _kind;
    final sort = _sort;
    try {
      final items = await ref
          .read(feedbackServiceProvider)
          .listFeatureBoard(kind: kind, sort: sort);
      // A filter change while this request was in flight has its own load.
      if (!mounted || kind != _kind || sort != _sort) return;
      setState(() {
        _items = items;
        _error = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || kind != _kind || sort != _sort) return;
      setState(() {
        _error = AppLocalizations.of(context)!.featureBoardLoadFailed;
        _isLoading = false;
      });
    }
  }

  void _setKind(FeatureBoardKind? kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _items = const [];
    });
    _load();
  }

  void _setSort(FeatureBoardSort sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _items = const [];
    });
    _load();
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

  Future<void> _open(FeatureBoardItem item) async {
    await context.pushNamed(
      'featureBoardItem',
      pathParameters: {'id': item.id},
      extra: item,
    );
    // Votes and comments may have changed while the detail was open.
    if (mounted) await _load();
  }

  Future<void> _openCreateSheet() async {
    final l10n = AppLocalizations.of(context)!;
    _createSheetDirty.value = false;

    final createdKind = await showAppBottomSheet<FeatureBoardKind>(
      context: context,
      title: l10n.featureBoardNewTitle,
      isDirtyListenable: _createSheetDirty,
      body: _FeatureBoardCreateForm(
        dirty: _createSheetDirty,
        initialKind: _kind ?? FeatureBoardKind.feature,
        onSubmit: ({required title, description, required kind}) =>
            ref.read(feedbackServiceProvider).submitBoardFeature(
                  title: title,
                  description: description,
                  kind: kind,
                  sourcePage: '/you/feature-board',
                ),
      ),
    );

    if (createdKind != null && mounted) {
      AppToast.success(
        context,
        createdKind == FeatureBoardKind.bug
            ? l10n.featureBoardBugCreated
            : l10n.featureBoardCreated,
      );
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
            _FilterRow(
              kind: _kind,
              sort: _sort,
              onKindChanged: _setKind,
              onSortChanged: _setSort,
            ),
            const SizedBox(height: MitlistSpacing.md),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: MitlistSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
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
            else
              for (var index = 0; index < _items.length; index++) ...[
                _FeatureCard(
                  item: _items[index],
                  isVoting: _votingIds.contains(_items[index].id),
                  onUpvote: () => _upvote(_items[index]),
                  onOpen: () => _open(_items[index]),
                ),
                if (index != _items.length - 1)
                  const SizedBox(height: MitlistSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.kind,
    required this.sort,
    required this.onKindChanged,
    required this.onSortChanged,
  });

  final FeatureBoardKind? kind;
  final FeatureBoardSort sort;
  final ValueChanged<FeatureBoardKind?> onKindChanged;
  final ValueChanged<FeatureBoardSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          AppChip(
            label: l10n.featureBoardFilterAll,
            selected: kind == null,
            onSelected: (_) => onKindChanged(null),
          ),
          const SizedBox(width: MitlistSpacing.space2),
          AppChip(
            label: l10n.featureBoardFilterFeatures,
            leading: const AppIcon(name: 'lightbulb'),
            selected: kind == FeatureBoardKind.feature,
            onSelected: (_) => onKindChanged(FeatureBoardKind.feature),
          ),
          const SizedBox(width: MitlistSpacing.space2),
          AppChip(
            label: l10n.featureBoardFilterBugs,
            leading: const AppIcon(name: 'bugReport'),
            selected: kind == FeatureBoardKind.bug,
            onSelected: (_) => onKindChanged(FeatureBoardKind.bug),
          ),
          const SizedBox(width: MitlistSpacing.space4),
          AppChip(
            label: l10n.featureBoardSortTop,
            leading: const AppIcon(name: 'chevronUp'),
            selected: sort == FeatureBoardSort.top,
            onSelected: (_) => onSortChanged(FeatureBoardSort.top),
          ),
          const SizedBox(width: MitlistSpacing.space2),
          AppChip(
            label: l10n.featureBoardSortNew,
            leading: const AppIcon(name: 'clockOutline'),
            selected: sort == FeatureBoardSort.newest,
            onSelected: (_) => onSortChanged(FeatureBoardSort.newest),
          ),
        ],
      ),
    );
  }
}

class _FeatureBoardCreateForm extends StatefulWidget {
  const _FeatureBoardCreateForm({
    required this.dirty,
    required this.initialKind,
    required this.onSubmit,
  });

  final ValueNotifier<bool> dirty;
  final FeatureBoardKind initialKind;
  final Future<void> Function({
    required String title,
    String? description,
    required FeatureBoardKind kind,
  }) onSubmit;

  @override
  State<_FeatureBoardCreateForm> createState() =>
      _FeatureBoardCreateFormState();
}

class _FeatureBoardCreateFormState extends State<_FeatureBoardCreateForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late FeatureBoardKind _kind = widget.initialKind;
  bool _isSending = false;
  String? _error;

  bool get _isBug => _kind == FeatureBoardKind.bug;

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
      setState(() =>
          _error = _isBug ? l10n.featureBoardBugEmpty : l10n.featureBoardEmpty);
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
        kind: _kind,
      );
      widget.dirty.value = false;
      if (mounted) Navigator.of(context).pop(_kind);
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
        FeatureBoardKindSelector(
          value: _kind,
          onChanged: (kind) => setState(() => _kind = kind),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          _isBug ? l10n.featureBoardNewBugIntro : l10n.featureBoardNewIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (_error != null) ...[
          AppAlert(type: AppAlertType.error, message: _error!),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppInput(
          controller: _titleController,
          label: _isBug
              ? l10n.featureBoardBugTitleLabel
              : l10n.featureBoardTitleLabel,
          hint: _isBug
              ? l10n.featureBoardBugTitleHint
              : l10n.featureBoardTitleHint,
          maxLength: 200,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          controller: _descriptionController,
          label: _isBug
              ? l10n.featureBoardBugDescriptionLabel
              : l10n.featureBoardDescriptionLabel,
          hint: _isBug
              ? l10n.featureBoardBugDescriptionHint
              : l10n.featureBoardDescriptionHint,
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.item,
    required this.isVoting,
    required this.onUpvote,
    required this.onOpen,
  });

  final FeatureBoardItem item;
  final bool isVoting;
  final VoidCallback onUpvote;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      interactive: true,
      onTap: onOpen,
      semanticLabel: item.title,
      child: Row(
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
                  item.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description case final description?) ...[
                  const SizedBox(height: MitlistSpacing.xs),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: MitlistSpacing.sm),
                Wrap(
                  spacing: MitlistSpacing.space2,
                  runSpacing: MitlistSpacing.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FeatureBoardStatusChip(status: item.status),
                    FeatureBoardKindChip(kind: item.kind),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          name: 'chatBubbleLeftRight',
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: MitlistSpacing.space1),
                        Text(
                          l10n.featureBoardComments(item.commentCount),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
