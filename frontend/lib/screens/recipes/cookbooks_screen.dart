import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_models.dart';
import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../sheets/cookbook_form_sheet.dart';
import '../../theme/spacing.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/latest_request_guard.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class CookbooksScreen extends ConsumerStatefulWidget {
  const CookbooksScreen({super.key});

  @override
  ConsumerState<CookbooksScreen> createState() => _CookbooksScreenState();
}

class _CookbooksScreenState extends ConsumerState<CookbooksScreen> {
  bool _isLoading = true;
  String? _error;
  final List<RecipeCollection> _items = [];
  String? _submittingId;
  Group? _household;
  final LatestRequestGuard _loadGuard = LatestRequestGuard();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadGuard.dispose();
    super.dispose();
  }

  /// The household whose cookbooks show alongside the user's own, and the one
  /// a new cookbook can be shared with.
  Future<Group?> _resolveHousehold() async {
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final id = resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
      if (!isValidGroupId(id)) return null;
      for (final g in groups) {
        if (g.id == id) return g;
      }
    } catch (_) {
      // No household is a valid state; the list is just personal then.
    }
    return null;
  }

  Future<void> _load() async {
    final request = _loadGuard.begin();
    final hadContent = _items.isNotEmpty;
    setState(() {
      _isLoading = !hadContent;
      _error = null;
    });
    try {
      final household = await _resolveHousehold();
      final svc = await ref.read(recipeServiceProviderAsync.future);
      // Without the household the list would only ever show cookbooks the
      // user created, and the kitchen tab would count more than this screen
      // could show.
      final items = await svc.listCollections(
        limit: 100,
        groupId: household?.id,
      );
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _household = household;
        _items
          ..clear()
          ..addAll(items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      final message = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      if (hadContent) {
        setState(() => _isLoading = false);
        AppToast.error(context, message);
        return;
      }
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar(
        title: Text(l10n.cookbooksTitle),
        showStandardActions: false,
      ),
      body: _buildBody(),
      floatingActionButton: _isLoading
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: _openCreateSheet,
              text: l10n.cookbooksAdd,
              icon: const AppIcon(name: 'plus'),
              tooltip: l10n.cookbooksAdd,
            ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _load,
      child: _buildBodyContent(),
    );
  }

  Widget _wrapForRefresh(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildBodyContent() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 88),
        ),
      );
    }
    if (_error != null) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            icon: const AppIcon(name: 'alertCircleOutline'),
            title: l10n.commonSomethingWentWrong,
            description: _error,
            isError: true,
            actions: [
              AppButton(
                variant: AppButtonVariant.outline,
                text: l10n.commonRetry,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            icon: const AppIcon(name: 'squares2x2', size: 56),
            title: l10n.cookbooksEmptyTitle,
            description: l10n.cookbooksEmptyDesc,
            actions: [
              AppButton(
                text: l10n.cookbooksAdd,
                icon: const AppIcon(name: 'plus'),
                onPressed: _openCreateSheet,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.xxl + MitlistSpacing.xl,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: MitlistSpacing.sm),
      itemBuilder: (context, index) {
        final c = _items[index];
        return ListEntrance(
          index: index,
          child: _CookbookCard(
            collection: c,
            householdName: _household?.name,
            isSubmitting: _submittingId == c.id,
            onOpen: () => _openDetail(c),
            onEdit: () => _openEditSheet(c),
            onDelete: () => _confirmDelete(c),
          ),
        );
      },
    );
  }

  Future<void> _openDetail(RecipeCollection c) async {
    await context.pushNamed(
      'cookbookDetail',
      pathParameters: {'collectionId': c.id},
      extra: c,
    );
    // Recipes may have been filed or removed; keep the counts honest.
    if (mounted) await _load();
  }

  Future<void> _openCreateSheet() async {
    final result = await showCookbookFormSheet(
      context,
      household: _household,
    );
    if (result == null) return;

    setState(() => _submittingId = 'create');
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.createCollection(CreateCollectionRequest(
        name: result.name,
        groupId: result.shareWithHousehold ? _household?.id : null,
      ));
      await _load();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppToast.error(context, l10n.cookbooksCouldNotCreate);
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _openEditSheet(RecipeCollection c) async {
    final result = await showCookbookFormSheet(
      context,
      household: _household,
      initialName: c.name,
      initialShared: c.isSharedWithHousehold,
    );
    if (result == null) return;

    setState(() => _submittingId = c.id);
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.updateCollection(
        c.id,
        UpdateCollectionRequest(
          name: result.name,
          groupId: result.shareWithHousehold ? _household?.id : null,
          makePrivate: !result.shareWithHousehold && c.isSharedWithHousehold,
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppToast.error(context, l10n.cookbooksCouldNotRename);
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _confirmDelete(RecipeCollection c) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.cookbooksDeleteTitle,
      body: Text(l10n.cookbooksDeleteBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;

    setState(() => _submittingId = c.id);
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.deleteCollection(c.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, l10n.cookbooksCouldNotDelete);
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }
}

enum _CookbookMenuAction { edit, delete }

class _CookbookCard extends StatelessWidget {
  final RecipeCollection collection;
  final String? householdName;
  final bool isSubmitting;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CookbookCard({
    required this.collection,
    required this.householdName,
    required this.isSubmitting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shared = collection.isSharedWithHousehold;
    final scopeLabel = shared && householdName != null
        ? l10n.cookbookDetailSharedWith(householdName!)
        : (shared ? l10n.recipeDetailSharedLabel : l10n.cookbookDetailPersonal);

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      interactive: !isSubmitting,
      animated: true,
      onTap: isSubmitting ? null : onOpen,
      semanticLabel: l10n.cookbooksOpen(collection.name),
      child: Row(
        children: [
          Container(
            width: MitlistSpacing.space12,
            height: MitlistSpacing.space12,
            decoration: BoxDecoration(
              color: shared
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outline, width: 2),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              name: shared ? 'userGroup' : 'squares2x2',
              size: 22,
              color: shared
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  collection.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  '${l10n.cookbooksRecipeCount(collection.recipeCount ?? 0)}'
                  ' · $scopeLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isSubmitting)
            SizedBox(
              width: MitlistSpacing.space5,
              height: MitlistSpacing.space5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          else
            PopupMenuButton<_CookbookMenuAction>(
              icon: const AppIcon(name: 'ellipsisVertical'),
              tooltip: l10n.commonOptions,
              onSelected: (value) {
                switch (value) {
                  case _CookbookMenuAction.edit:
                    onEdit();
                  case _CookbookMenuAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CookbookMenuAction.edit,
                  child: Text(l10n.cookbooksEdit),
                ),
                PopupMenuItem(
                  value: _CookbookMenuAction.delete,
                  child: Text(l10n.commonDelete),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
