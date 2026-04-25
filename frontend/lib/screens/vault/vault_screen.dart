import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vault_provider.dart';
import '../../providers/group_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultItem {
  final String id;
  final String name;
  final String category;
  final DateTime? expiryDate;
  final int documentCount;
  final int tagCount;

  _VaultItem({
    required this.id,
    required this.name,
    required this.category,
    this.expiryDate,
    this.documentCount = 0,
    this.tagCount = 0,
  });
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _filterExpired = false;
  bool _filterSoon = false;
  Timer? _searchDebounce;

  final List<String> _categories = const [
    'All',
    'Wi-Fi',
    'Paint',
    'Insurance',
    'Warranty',
    'Emergency',
    'Custom',
  ];

  List<_VaultItem> _allItems = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vaultService = await ref.read(vaultServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
      final groupId = groups.isNotEmpty ? groups.first.id : '';
      final apiItems = await vaultService.listVaultItems(groupId);

      if (!mounted) return;

      final items = apiItems.map((api) => _VaultItem(
        id: api.id,
        name: api.title,
        category: api.type,
        expiryDate: api.reminderDate,
        documentCount: api.content.isNotEmpty ? 1 : 0,
        tagCount: 0,
      )).toList();

      setState(() {
        _allItems = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load vault items';
        _isLoading = false;
      });
    }
  }

  bool _matchesFilter(_VaultItem item) {
    if (_selectedCategory != 'All' && item.category != _selectedCategory) {
      return false;
    }
    if (_filterExpired && item.expiryDate != null && !_isExpired(item.expiryDate!)) {
      return false;
    }
    if (_filterSoon &&
        item.expiryDate != null &&
        !_isExpiringSoon(item.expiryDate!)) {
      return false;
    }
    if (_searchQuery.isNotEmpty &&
        !item.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return false;
    }
    return true;
  }

  static bool _isExpired(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  static bool _isExpiringSoon(DateTime date) {
    final weeks = date.difference(DateTime.now()).inDays;
    return weeks >= 0 && weeks <= 30;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildSkeletonGrid();
    if (_errorMessage != null) return _buildError();
    if (_filteredItems.isEmpty) return _buildEmpty();
    return _buildGrid(_filteredItems);
  }

  List<_VaultItem> get _filteredItems {
    return _allItems.where(_matchesFilter).toList();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAlert(
              type: AppAlertType.error,
              message: _errorMessage!,
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: 'Retry',
              onPressed: _loadItems,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: AppEmptyState(
        icon: const AppIcon(name: 'folderOpen', size: 56),
        title: 'No items yet',
        description: 'Add important documents and info to your household vault.',
      ),
    );
  }

  Widget _buildGrid(List<_VaultItem> items) {
    final textTheme = Theme.of(context).textTheme;
    return GridView.builder(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: MitlistSpacing.md,
        crossAxisSpacing: MitlistSpacing.md,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCard(items[index], textTheme),
    );
  }

  Widget _buildCard(_VaultItem item, TextTheme textTheme) {
    String? expiryLabel;
    if (item.expiryDate != null) {
      final days = item.expiryDate!.difference(DateTime.now()).inDays;
      if (days < 0) {
        expiryLabel = 'Expired';
      } else if (days <= 30) {
        expiryLabel = 'Expires in $days days';
      }
    }

    return AppCard(
      interactive: true,
      onTap: () {},
      padding: AppCardPadding.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: MitlistSpacing.space1,
            color: MitlistColors.primary500,
          ),
          Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: MitlistSpacing.space12,
                  height: MitlistSpacing.space12,
                  color: MitlistColors.neutral100,
                  child: const Center(
                    child: AppIcon(
                      name: 'folder',
                      size: MitlistSpacing.space6,
                    ),
                  ),
                ),
                const SizedBox(height: MitlistSpacing.md),
                Text(
                  item.name,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MitlistSpacing.sm),
                AppChip(
                  label: item.category,
                  onSelected: null,
                ),
                if (expiryLabel != null) ...[
                  const SizedBox(height: MitlistSpacing.sm),
                  AppChip(
                    label: expiryLabel,
                    selected: true,
                    onSelected: null,
                  ),
                ],
                if (item.documentCount > 0 || item.tagCount > 0) ...[
                  const SizedBox(height: MitlistSpacing.sm),
                  Text(
                    '${item.documentCount} docs · ${item.tagCount} tags',
                    style: textTheme.bodySmall?.copyWith(
                      color: MitlistColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: MitlistSpacing.md,
        crossAxisSpacing: MitlistSpacing.md,
        childAspectRatio: 0.75,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => AppCard(
        padding: AppCardPadding.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeleton(
              width: double.infinity,
              height: MitlistSpacing.space1,
            ),
            Padding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSkeleton(
                    width: MitlistSpacing.space12,
                    height: MitlistSpacing.space12,
                  ),
                  const SizedBox(height: MitlistSpacing.md),
                  const AppSkeleton(
                    width: double.infinity,
                    height: MitlistSpacing.space3,
                  ),
                  const SizedBox(height: MitlistSpacing.sm),
                  const AppSkeleton(
                    width: MitlistSpacing.space10,
                    height: MitlistSpacing.space3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}