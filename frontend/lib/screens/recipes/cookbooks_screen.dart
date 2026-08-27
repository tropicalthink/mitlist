import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/recipe_models.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/latest_request_guard.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/empty_state.dart';
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

  Future<void> _load() async {
    final request = _loadGuard.begin();
    final hadContent = _items.isNotEmpty;
    setState(() {
      _isLoading = !hadContent;
      _error = null;
    });
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final items = await svc.listCollections(limit: 100);
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _items.clear();
        _items.addAll(items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      final message = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      if (hadContent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
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
      appBar: MitlistAppBar(title: Text(l10n.cookbooksTitle)),
      body: _buildBody(),
      floatingActionButton: _isLoading
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: _openCreateSheet,
              text: l10n.cookbooksAdd,
              icon: const AppIcon(name: 'plus'),
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
          child: AppSkeleton(width: double.infinity, height: 72),
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
            icon: const AppIcon(name: 'squares2x2'),
            title: l10n.cookbooksEmptyTitle,
            description: l10n.cookbooksEmptyDesc,
            actions: [
              AppButton(
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
                text: l10n.cookbooksAdd,
                onPressed: _openCreateSheet,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final c = _items[index];
        return _CookbookCard(
          collection: c,
          isSubmitting: _submittingId == c.id,
          onOpen: () => context.pushNamed(
            'cookbookDetail',
            pathParameters: {'collectionId': c.id},
            extra: c.name,
          ),
          onRename: () => _openRenameSheet(c),
          onDelete: () => _confirmDelete(c),
        );
      },
    );
  }

  Future<void> _openCreateSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppBottomSheet<String>(
      context: context,
      title: l10n.cookbooksSheetTitle,
      body: const _CookbookNameForm(),
    );
    if (result == null) return;

    setState(() => _submittingId = 'create');
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.createCollection(CreateCollectionRequest(name: result));
      await _load();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cookbooksCouldNotCreate)),
      );
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _openRenameSheet(RecipeCollection c) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showAppBottomSheet<String>(
      context: context,
      title: l10n.cookbooksRenameSheetTitle,
      body: _CookbookNameForm(initialName: c.name),
    );
    if (result == null) return;

    setState(() => _submittingId = c.id);
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.updateCollection(c.id, UpdateCollectionRequest(name: result));
      await _load();
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cookbooksCouldNotRename)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cookbooksCouldNotDelete)),
      );
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }
}

class _CookbookCard extends StatelessWidget {
  final RecipeCollection collection;
  final bool isSubmitting;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CookbookCard({
    required this.collection,
    required this.isSubmitting,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        onTap: isSubmitting ? null : onOpen,
        child: Row(
          children: [
            const AppIcon(name: 'squares2x2'),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: MitlistSpacing.space1),
                  Text(
                    l10n.cookbooksRecipeCount(collection.recipeCount ?? 0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.labelXSmall(),
                  ),
                ],
              ),
            ),
            if (isSubmitting)
              const SizedBox(
                width: MitlistSpacing.space5,
                height: MitlistSpacing.space5,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              PopupMenuButton<String>(
                icon: const AppIcon(name: 'ellipsisVertical'),
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(l10n.cookbooksRename),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(l10n.commonDelete),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CookbookNameForm extends StatefulWidget {
  final String? initialName;
  const _CookbookNameForm({this.initialName});

  @override
  State<_CookbookNameForm> createState() => _CookbookNameFormState();
}

class _CookbookNameFormState extends State<_CookbookNameForm> {
  late final TextEditingController _nameController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
        ],
        AppInput(
          controller: _nameController,
          label: l10n.cookbooksFieldName,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              text: l10n.commonCancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            AppButton(
              variant: AppButtonVariant.solid,
              text: l10n.commonSave,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.cookbooksValidationName);
      return;
    }
    Navigator.of(context).pop(name);
  }
}
