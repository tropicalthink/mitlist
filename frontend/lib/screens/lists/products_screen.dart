import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  bool _isLoading = true;
  String? _error;
  bool _hasHousehold = true;
  final List<Product> _items = [];
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!isValidGroupId(groupId)) {
        setState(() {
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      final service = await ref.read(listServiceProviderAsync.future);
      final items = await service.listProducts(groupId!);
      setState(() {
        _items.clear();
        _items.addAll(items);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  List<Product> get _filtered {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar(title: Text(l10n.productsTitle)),
      body: _buildBody(),
      floatingActionButton: !_hasHousehold || _isLoading
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: _openCreateSheet,
              text: l10n.productsAdd,
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
    if (!_hasHousehold) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            icon: const AppIcon(name: 'tagOutline'),
            title: l10n.commonNoHousehold,
            description: l10n.productsNoHouseholdDesc,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            icon: const AppIcon(name: 'tagOutline'),
            title: l10n.productsNoResults,
            actions: [
              AppButton(
                text: l10n.productsAdd,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
                onPressed: _openCreateSheet,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.md,
            MitlistSpacing.md,
            MitlistSpacing.md,
            MitlistSpacing.sm,
          ),
          child: AppInput(
            controller: _searchController,
            hint: l10n.productsSearchHint,
            clearable: true,
            prefixIcon: const AppIcon(name: 'magnifyingGlass'),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _wrapForRefresh(
                  Center(
                    child: AppEmptyState(
                      paddingPreset: AppEmptyStatePadding.md,
                      icon: const AppIcon(name: 'tagOutline'),
                      title: l10n.productsNoResults,
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    MitlistSpacing.md,
                    0,
                    MitlistSpacing.md,
                    MitlistSpacing.md,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _ProductCard(product: filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openCreateSheet() async {
    final groups = await ref.read(cachedGroupsProvider.future);
    final groupId = resolveActiveGroupId(
      groups,
      ref.read(currentGroupIdProvider),
    );
    if (!isValidGroupId(groupId)) return;
    if (!mounted) return;

    final result = await showModalBottomSheet<_CreateProductResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ProductCreationSheet(groupId: groupId!),
    );
    if (result == null) return;

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      await service.createProduct(
        CreateProductRequest(
          groupId: result.groupId,
          name: result.name,
          unit: result.unit,
          barcode: result.barcode,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.productsCouldNotCreate)),
      );
    }
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = [
      if (product.unit.trim().isNotEmpty) product.unit.trim(),
      if (product.barcode.trim().isNotEmpty) product.barcode.trim(),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (secondary.isNotEmpty) ...[
                    const SizedBox(height: MitlistSpacing.space1),
                    Row(
                      children: [
                        const AppIcon(name: 'tagOutline', size: 14),
                        const SizedBox(width: MitlistSpacing.space1),
                        Expanded(
                          child: Text(
                            secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MitlistTypography.labelXSmall(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCreationSheet extends StatelessWidget {
  final String groupId;

  const _ProductCreationSheet({required this.groupId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: MitlistSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.productsSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: MitlistSpacing.md),
            _CreateProductForm(groupId: groupId),
          ],
        ),
      ),
    );
  }
}

class _CreateProductResult {
  final String groupId;
  final String name;
  final String unit;
  final String barcode;

  const _CreateProductResult({
    required this.groupId,
    required this.name,
    required this.unit,
    required this.barcode,
  });
}

class _CreateProductForm extends StatefulWidget {
  final String groupId;
  const _CreateProductForm({required this.groupId});

  @override
  State<_CreateProductForm> createState() => _CreateProductFormState();
}

class _CreateProductFormState extends State<_CreateProductForm> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _barcodeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _barcodeController.dispose();
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
          label: l10n.productsFieldName,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppInput(
          controller: _unitController,
          label: l10n.productsFieldUnit,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppInput(
          controller: _barcodeController,
          label: l10n.productsFieldBarcode,
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
      setState(() => _error = l10n.productsValidationName);
      return;
    }

    Navigator.of(context).pop(_CreateProductResult(
      groupId: widget.groupId,
      name: name,
      unit: _unitController.text.trim(),
      barcode: _barcodeController.text.trim(),
    ));
  }
}
