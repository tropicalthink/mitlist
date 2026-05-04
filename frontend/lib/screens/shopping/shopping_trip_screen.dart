import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../theme/theme.dart';
import '../../utils/active_group_context.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class ShoppingTripScreen extends ConsumerStatefulWidget {
  const ShoppingTripScreen({super.key});

  @override
  ConsumerState<ShoppingTripScreen> createState() => _ShoppingTripScreenState();
}

class _ShoppingTripScreenState extends ConsumerState<ShoppingTripScreen> {
  bool _isLoading = true;
  bool _hasHousehold = true;
  String? _error;
  final List<ItemList> _lists = [];
  final Map<String, List<ListItem>> _itemsByList = {};
  final Set<String> _checkedItemIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groupId = await _resolveGroupId();
      if (groupId == null) {
        setState(() {
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }

      final listSvc = await ref.read(listServiceProviderAsync.future);
      final lists = await listSvc.listLists(groupId, limit: 100);
      final shoppingLists = lists.where((l) => l.type == 'shopping' || l.type == 'general').toList();

      if (shoppingLists.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final listIds = shoppingLists.map((l) => l.id).toList();
      final result = await listSvc.getShoppingTrip(listIds, groupId: groupId);

      final itemsByList = <String, List<ListItem>>{};
      final rawLists = result['lists'] as List<dynamic>? ?? [];
      for (final rl in rawLists) {
        final listId = rl['list_id'] as String? ?? '';
        final rawItems = rl['items'] as List<dynamic>? ?? [];
        final items = rawItems.map((ri) {
          final m = Map<String, dynamic>.from(ri as Map);
          return ListItem.fromJson(m);
        }).where((i) => !i.checked).toList();
        if (items.isNotEmpty) {
          itemsByList[listId] = items;
        }
      }

      setState(() {
        _lists.addAll(shoppingLists);
        _itemsByList.addAll(itemsByList);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  Future<String?> _resolveGroupId() async {
    try {
      final groupSvc = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupSvc.listGroups(limit: 50);
      return resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    } catch (_) {
      return null;
    }
  }

  void _toggleItem(String itemId) {
    setState(() {
      if (_checkedItemIds.contains(itemId)) {
        _checkedItemIds.remove(itemId);
      } else {
        _checkedItemIds.add(itemId);
      }
    });
  }

  Future<void> _completeChecked() async {
    if (_checkedItemIds.isEmpty) return;
    setState(() => _isSubmitting = true);

    final checkedItems = <ListItem>[];
    for (final items in _itemsByList.values) {
      for (final item in items) {
        if (_checkedItemIds.contains(item.id)) {
          checkedItems.add(item);
        }
      }
    }
    final totalCents = checkedItems.fold<int>(
        0, (sum, item) => sum + (item.priceCents ?? 0));

    try {
      final listSvc = await ref.read(listServiceProviderAsync.future);
      await listSvc.completeShoppingItems(_checkedItemIds.toList());

      if (!mounted) return;
      setState(() => _checkedItemIds.clear());
      await _load();
      if (!mounted) return;

      if (totalCents > 0) {
        final totalStr = (totalCents / 100).toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u20ac$totalStr worth of items marked as done'),
            action: SnackBarAction(
              label: 'Add expense',
              onPressed: () => context.pushNamed('money'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items marked as done')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _listName(String listId) {
    final list = _lists.cast<ItemList?>().firstWhere(
          (l) => l?.id == listId,
          orElse: () => null,
        );
    return list?.name ?? 'List';
  }

  int get _totalItems {
    return _itemsByList.values.fold(0, (sum, items) => sum + items.length);
  }

  int get _checkedCount => _checkedItemIds.length;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MitlistAppBar(
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Shopping Trip'),
        actions: [
          if (_checkedCount > 0)
            TextButton(
              onPressed: _isSubmitting ? null : _completeChecked,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Done ($_checkedCount)'),
            ),
        ],
      ),
      body: _buildBody(textTheme),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isLoading) {
      return _buildSkeleton();
    }
    if (!_hasHousehold) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: const Icon(Icons.home_outlined),
          title: 'No household yet',
          description: 'Create or join a household before starting a shopping trip.',
          actions: [
            AppButton(
              text: 'Go to households',
              onPressed: () => context.goNamed('groupsList'),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/404.lottie',
          icon: const Icon(Icons.error_outline),
          title: 'Something went wrong',
          description: _error,
          actions: [
            AppButton(
              variant: AppButtonVariant.outline,
              text: 'Retry',
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    if (_lists.isEmpty) {
      return const Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/checklist.lottie',
          icon: Icon(Icons.shopping_bag_outlined),
          title: 'No lists yet',
          description: 'Create a shopping list to start a trip',
        ),
      );
    }
    if (_totalItems == 0) {
      return const Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/Checkmark.lottie',
          icon: Icon(Icons.check_circle_outline),
          title: 'All caught up',
          description: 'No open items across your lists. Add items to a list to see them here.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md, vertical: MitlistSpacing.sm),
        itemCount: _itemsByList.length,
        itemBuilder: (context, index) {
          final listId = _itemsByList.keys.elementAt(index);
          final items = _itemsByList[listId]!;
          final listName = _listName(listId);
          return _ListSection(
            listId: listId,
            listName: listName,
            items: items,
            checkedIds: _checkedItemIds,
            onToggle: _toggleItem,
            onTapList: () => context.pushNamed('listDetail', pathParameters: {'listId': listId}),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: 3,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
        child: AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 140, height: 16),
              const SizedBox(height: MitlistSpacing.sm),
              const Divider(),
              const SizedBox(height: MitlistSpacing.sm),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                  child: Row(
                    children: [
                      const AppSkeleton(width: 20, height: 20),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: AppSkeleton(
                          width: double.infinity,
                          height: 14,
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.md),
                      AppSkeleton(
                        width: MitlistSpacing.space10,
                        height: 14,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  final String listId;
  final String listName;
  final List<ListItem> items;
  final Set<String> checkedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onTapList;

  const _ListSection({
    required this.listId,
    required this.listName,
    required this.items,
    required this.checkedIds,
    required this.onToggle,
    required this.onTapList,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTapList,
              borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      listName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const AppIcon(name: 'chevronRight', size: 16),
                ],
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            const Divider(),
            const SizedBox(height: MitlistSpacing.sm),
            ...items.map((item) {
              final isChecked = checkedIds.contains(item.id);
              return _ItemRow(
                item: item,
                isChecked: isChecked,
                onToggle: () => onToggle(item.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ListItem item;
  final bool isChecked;
  final VoidCallback onToggle;

  const _ItemRow({
    required this.item,
    required this.isChecked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final qtyText = item.quantity > 0
        ? '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
      child: Row(
        children: [
          Semantics(
            label: 'Toggle ${item.name}',
            child: Checkbox(
              value: isChecked,
              onChanged: (_) => onToggle(),
            ),
          ),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                decoration: isChecked ? TextDecoration.lineThrough : null,
                color: isChecked ? MitlistColors.textSecondary : MitlistColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (qtyText.isNotEmpty)
            Text(
              qtyText.trim(),
              style: MitlistTypography.labelXSmall(),
            ),
              if (item.priceCents != null && item.priceCents! > 0)
                Padding(
                  padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                  child: Text(
                    '€${(item.priceCents! / 100).toStringAsFixed(2)}',
                    style: MitlistTypography.labelXSmall(),
                  ),
                ),
        ],
      ),
    );
  }
}
