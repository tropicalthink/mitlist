import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/recipe_models.dart';
import '../providers/group_provider.dart';
import '../providers/recipe_provider.dart';
import '../router.dart' show currentGroupIdProvider;
import '../services/group_id_validator.dart';
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_input.dart';
import '../widgets/app_toast.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// Files one recipe into a cookbook, from the recipe itself.
///
/// Tapping a cookbook adds immediately — one recipe, one destination, no
/// confirm step. A cookbook can also be created inline so the first filing
/// does not send the user off to the cookbooks screen and back.
class RecipeAddToCookbookSheet extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeAddToCookbookSheet({super.key, required this.recipeId});

  static Future<void> show(BuildContext context, {required String recipeId}) {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<void>(
      context: context,
      title: l10n.recipeDetailAddToCookbook,
      body: RecipeAddToCookbookSheet(recipeId: recipeId),
    );
  }

  @override
  ConsumerState<RecipeAddToCookbookSheet> createState() =>
      _RecipeAddToCookbookSheetState();
}

class _RecipeAddToCookbookSheetState
    extends ConsumerState<RecipeAddToCookbookSheet> {
  bool _isLoading = true;
  String? _error;
  final List<RecipeCollection> _cookbooks = [];
  String? _groupId;
  String? _busyId;
  final TextEditingController _newNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      try {
        final groups = await ref.read(cachedGroupsProvider.future);
        final id =
            resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
        _groupId = isValidGroupId(id) ? id : null;
      } catch (_) {
        _groupId = null;
      }
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final items = await svc.listCollections(limit: 100, groupId: _groupId);
      if (!mounted) return;
      setState(() {
        _cookbooks
          ..clear()
          ..addAll(items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  Future<void> _addTo(RecipeCollection c) async {
    if (_busyId != null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busyId = c.id);
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.addRecipeToCollection(
        c.id,
        AddRecipeToCollectionRequest(recipeId: widget.recipeId),
      );
      if (!mounted) return;
      unawaited(Haptics.success());
      Navigator.of(context).pop();
      AppToast.success(context, l10n.recipeAddedToCookbook(c.name));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyId = null);
      AppToast.error(context, l10n.recipeAddToCookbookFailed);
    }
  }

  Future<void> _createAndAdd() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty || _busyId != null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busyId = 'create');
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      // Inline creation makes a personal cookbook; sharing it with the
      // household is an edit on the cookbooks screen.
      final created = await svc.createCollection(
        CreateCollectionRequest(name: name),
      );
      await svc.addRecipeToCollection(
        created.id,
        AddRecipeToCollectionRequest(recipeId: widget.recipeId),
      );
      if (!mounted) return;
      unawaited(Haptics.success());
      Navigator.of(context).pop();
      AppToast.success(context, l10n.recipeAddedToCookbook(created.name));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyId = null);
      AppToast.error(context, l10n.recipeAddToCookbookFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          AppSkeleton(width: double.infinity, height: 64),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(width: double.infinity, height: 64),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(width: double.infinity, height: 64),
        ],
      );
    }

    if (_error != null) {
      return AppEmptyState(
        paddingPreset: AppEmptyStatePadding.md,
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
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_cookbooks.isEmpty)
          AppEmptyState(
            paddingPreset: AppEmptyStatePadding.sm,
            icon: const AppIcon(name: 'squares2x2', size: 40),
            title: l10n.recipeAddToCookbookEmptyTitle,
            description: l10n.recipeAddToCookbookEmptyDesc,
          )
        else
          for (final c in _cookbooks)
            Padding(
              padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
              child: _CookbookRow(
                collection: c,
                busy: _busyId == c.id,
                onTap: _busyId == null ? () => _addTo(c) : null,
              ),
            ),
        const SizedBox(height: MitlistSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppInput(
                controller: _newNameController,
                label: l10n.recipeAddToCookbookNewName,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createAndAdd(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Padding(
              // Sits level with the input, under its floating label.
              padding: const EdgeInsets.only(top: MitlistSpacing.lg),
              child: AppButton(
                text: l10n.commonAdd,
                icon: const AppIcon(name: 'plus'),
                isLoading: _busyId == 'create',
                onPressed:
                    _newNameController.text.trim().isEmpty || _busyId != null
                        ? null
                        : _createAndAdd,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CookbookRow extends StatelessWidget {
  final RecipeCollection collection;
  final bool busy;
  final VoidCallback? onTap;

  const _CookbookRow({
    required this.collection,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shared = collection.isSharedWithHousehold;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      interactive: onTap != null,
      onTap: onTap,
      semanticLabel: collection.name,
      child: Row(
        children: [
          AppIcon(
            name: shared ? 'userGroup' : 'squares2x2',
            color: colorScheme.onSurfaceVariant,
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
                Text(
                  '${l10n.cookbooksRecipeCount(collection.recipeCount ?? 0)}'
                  ' · ${shared ? l10n.recipeDetailSharedLabel : l10n.cookbookDetailPersonal}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: MitlistSpacing.space5,
              height: MitlistSpacing.space5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          else
            AppIcon(name: 'plus', color: colorScheme.primary),
        ],
      ),
    );
  }
}
