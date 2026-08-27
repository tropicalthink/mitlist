import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../theme/spacing.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/latest_request_guard.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class ShoppingLocationsScreen extends ConsumerStatefulWidget {
  const ShoppingLocationsScreen({super.key});

  @override
  ConsumerState<ShoppingLocationsScreen> createState() =>
      _ShoppingLocationsScreenState();
}

class _ShoppingLocationsScreenState
    extends ConsumerState<ShoppingLocationsScreen> {
  bool _isLoading = true;
  String? _error;
  bool _hasHousehold = true;
  final List<ShoppingLocation> _items = [];
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
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!isValidGroupId(groupId)) {
        if (!mounted || !_loadGuard.isCurrent(request)) return;
        setState(() {
          _items.clear();
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      final service = await ref.read(listServiceProviderAsync.future);
      final items = await service.listShoppingLocations(groupId!);
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _items.clear();
        _items.addAll(items);
        _hasHousehold = true;
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
      appBar: MitlistAppBar(title: Text(l10n.shoppingLocationsTitle)),
      body: _buildBody(),
      floatingActionButton: !_hasHousehold || _isLoading
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: _openCreateSheet,
              text: l10n.shoppingLocationsAdd,
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
            lottieAsset: 'assets/animations/lottie/404.lottie',
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
            lottieAsset: 'assets/animations/lottie/House.lottie',
            icon: const AppIcon(name: 'homeOutline'),
            title: l10n.commonNoHousehold,
            description: l10n.shoppingLocationsNoHouseholdDesc,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            icon: const AppIcon(name: 'storeOutline'),
            title: l10n.shoppingLocationsEmptyTitle,
            description: l10n.shoppingLocationsEmptyDesc,
            actions: [
              AppButton(
                text: l10n.shoppingLocationsAdd,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
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
        final item = _items[index];
        return _LocationCard(name: item.name);
      },
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

    final result = await showAppBottomSheet<_CreateLocationResult>(
      context: context,
      title: AppLocalizations.of(context)!.shoppingLocationsSheetTitle,
      body: _CreateLocationForm(groupId: groupId!),
    );
    if (result == null) return;

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      await service.createShoppingLocation(
        CreateShoppingLocationRequest(
          groupId: result.groupId,
          name: result.name,
          sortOrder: _items.length,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shoppingLocationsCouldNotCreate)),
      );
    }
  }
}

class _LocationCard extends StatelessWidget {
  final String name;

  const _LocationCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Row(
          children: [
            const AppIcon(name: 'storeOutline'),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Text(
                name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateLocationResult {
  final String groupId;
  final String name;

  const _CreateLocationResult({
    required this.groupId,
    required this.name,
  });
}

class _CreateLocationForm extends StatefulWidget {
  final String groupId;
  const _CreateLocationForm({required this.groupId});

  @override
  State<_CreateLocationForm> createState() => _CreateLocationFormState();
}

class _CreateLocationFormState extends State<_CreateLocationForm> {
  final _nameController = TextEditingController();
  String? _error;

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
          label: l10n.shoppingLocationsFieldName,
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
      setState(() => _error = l10n.shoppingLocationsValidationName);
      return;
    }

    Navigator.of(context).pop(_CreateLocationResult(
      groupId: widget.groupId,
      name: name,
    ));
  }
}
