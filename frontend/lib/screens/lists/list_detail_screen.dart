import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';

class ListDetailScreen extends StatefulWidget {
  final String listId;
  const ListDetailScreen({super.key, required this.listId});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListItem {
  final String id;
  String name;
  bool completed = false;
  int quantity;

  _ListItem({
    required this.id,
    required this.name,
    this.quantity = 1,
  });
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _listName = '';
  final List<_ListItem> _items = [];
  final List<String> _suggestions = [];
  bool _showCompletionBanner = false;
  bool _showSearch = false;
  String _searchQuery = '';
  Timer? _bannerTimer;
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _newItemController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulated async load
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _isLoading = false;
      _listName = 'Grocery List';
      _suggestions.addAll(['Milk', 'Eggs', 'Bread', 'Butter']);
      _items.addAll([
        _ListItem(id: '1', name: 'Milk', quantity: 2),
        _ListItem(id: '2', name: 'Eggs', quantity: 12),
        _ListItem(id: '3', name: 'Bread'),
        _ListItem(id: '4', name: 'Butter'),
      ]);
    });
  }

  void _toggleItem(_ListItem item, bool value) {
    Haptics.light();
    setState(() {
      item.completed = value;
    });
    _checkCompletionBanner();
  }

  void _completeAll() {
    setState(() {
      for (final item in _items) {
        item.completed = true;
      }
    });
    _checkCompletionBanner();
  }

  void _checkCompletionBanner() {
    final total = _items.length;
    final completed = _items.where((i) => i.completed).length;

    if (total > 0 && completed == total) {
      setState(() => _showCompletionBanner = true);
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showCompletionBanner = false);
        }
      });
    } else {
      _bannerTimer?.cancel();
      setState(() => _showCompletionBanner = false);
    }
  }

  void _addItem() {
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _items.add(_ListItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: text,
      ));
      _newItemController.clear();
    });
    _checkCompletionBanner();
  }

  void _addSuggestion(String suggestion) {
    setState(() {
      _items.add(_ListItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: suggestion,
      ));
    });
    _checkCompletionBanner();
  }

  void _deleteItem(_ListItem item) {
    final index = _items.indexOf(item);
    setState(() {
      _items.remove(item);
    });
    _checkCompletionBanner();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          decoration: BoxDecoration(
            color: MitlistColors.neutral950,
            border: Border.all(
              color: MitlistColors.borderPrimary,
              width: 2,
            ),
            boxShadow: MitlistShadows.shadowMedium,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${item.name} deleted'.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _items.insert(index, item);
                  });
                  _checkCompletionBanner();
                },
                style: TextButton.styleFrom(
                  foregroundColor: MitlistColors.primary400,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.md,
                  ),
                ),
                child: const Text('UNDO'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'edit':
        // TODO: Navigate to edit list
        break;
      case 'complete_all':
        _completeAll();
        break;
      case 'archive':
        // TODO: Archive list
        break;
      case 'cost_summary':
        // TODO: Show cost summary dialog
        break;
      case 'add_expense':
        // TODO: Show expense creation sheet
        break;
    }
  }

  void _onItemMenuSelected(String value, _ListItem item) {
    switch (value) {
      case 'edit':
        // TODO: Edit item
        break;
      case 'delete':
        _deleteItem(item);
        break;
      case 'expense':
        // TODO: Add expense for item
        break;
    }
  }

  List<_ListItem> get _filteredItems {
    if (_searchQuery.isEmpty) return List.unmodifiable(_items);
    final lower = _searchQuery.toLowerCase();
    return _items.where((i) => i.name.toLowerCase().contains(lower)).toList();
  }

  double get _progress {
    if (_items.isEmpty) return 0;
    return _items.where((i) => i.completed).length / _items.length;
  }

  bool get _isComplete =>
      _items.isNotEmpty && _items.every((i) => i.completed);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search items...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text(
                _listName,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'magnifyingGlass'),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const AppIcon(name: 'ellipsisVertical'),
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                value: 'complete_all',
                child: Text('Complete all'),
              ),
              const PopupMenuItem(value: 'archive', child: Text('Archive')),
              const PopupMenuItem(
                value: 'cost_summary',
                child: Text('Cost summary'),
              ),
              const PopupMenuItem(
                value: 'add_expense',
                child: Text('Add expense'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky progress bar
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: LinearProgressIndicator(
              value: _items.isEmpty ? 0 : _progress,
              color: _isComplete
                  ? MitlistColors.success500
                  : MitlistColors.primary500,
              backgroundColor: MitlistColors.neutral200,
              minHeight: MitlistSpacing.space1,
            ),
          ),
          // Completion banner
          GestureDetector(
            onTap: () {
              _bannerTimer?.cancel();
              setState(() => _showCompletionBanner = false);
            },
            child: AnimatedContainer(
              duration: MitlistAnimations.banner,
              curve: MitlistTheme.easeToast,
              height: _showCompletionBanner
                  ? MitlistSpacing.space10
                  : MitlistSpacing.space0,
              color: MitlistColors.success500,
              width: double.infinity,
              alignment: Alignment.center,
              child: _showCompletionBanner
                  ? Text(
                      'All done!'.toUpperCase(),
                      style: textTheme.labelMedium?.copyWith(
                        color: MitlistColors.textOnSuccess,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Suggestion chips
          if (_suggestions.isNotEmpty &&
              !_isLoading &&
              _errorMessage == null)
            Padding(
              padding: const EdgeInsets.only(
                top: MitlistSpacing.md,
                bottom: MitlistSpacing.sm,
              ),
              child: SizedBox(
                height: MitlistSpacing.space8,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.md,
                  ),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: MitlistSpacing.sm),
                  itemBuilder: (context, index) {
                    final s = _suggestions[index];
                    return AppChip(
                      label: s,
                      onSelected: (_) => _addSuggestion(s),
                    );
                  },
                ),
              ),
            ),
          // Body content
          Expanded(child: _buildBody()),
          // Sticky bottom bar
          if (!_isLoading && _errorMessage == null) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) return _buildSkeleton();
    if (_errorMessage != null) return _buildError();

    final filtered = _filteredItems;
    if (filtered.isEmpty) return _buildEmpty();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(
        color: MitlistColors.borderSecondary,
        thickness: 2,
        indent: MitlistSpacing.md,
        endIndent: MitlistSpacing.md,
      ),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: MitlistColors.error500,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
            ),
            child: const AppIcon(
              name: 'trash',
              color: Colors.white,
            ),
          ),
          onDismissed: (_) {
            Haptics.medium();
            _deleteItem(item);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: item.completed,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  onChanged: (val) => _toggleItem(item, val ?? false),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    item.name,
                    style: textTheme.bodyMedium?.copyWith(
                      decoration: item.completed
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.completed
                          ? MitlistColors.textTertiary
                          : MitlistColors.textPrimary,
                    ),
                  ),
                ),
                if (item.quantity > 1)
                  Text(
                    '${item.quantity}x',
                    style: MitlistTypography.monoBody(
                      color: MitlistColors.textSecondary,
                    ),
                  ),
                const SizedBox(width: MitlistSpacing.sm),
                PopupMenuButton<String>(
                  icon: const AppIcon(
                    name: 'ellipsisVertical',
                    size: 20,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                    const PopupMenuItem(
                      value: 'expense',
                      child: Text('Add expense'),
                    ),
                  ],
                  onSelected: (value) => _onItemMenuSelected(value, item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              const AppSkeleton(width: 24, height: 24),
              const SizedBox(width: MitlistSpacing.md),
              Expanded(
                child: AppSkeleton(
                  width: double.infinity,
                  height: MitlistSpacing.space4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAlert(type: AppAlertType.error, message: _errorMessage!),
            const SizedBox(height: MitlistSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  text: 'Retry',
                  variant: AppButtonVariant.outline,
                  onPressed: _load,
                ),
                const SizedBox(width: MitlistSpacing.md),
                AppButton(
                  text: 'Dismiss',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => setState(() => _errorMessage = null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          icon: AppIcon(name: 'queueList'),
          title: 'No items yet',
          description: 'Add something using the bar below.',
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: MitlistColors.surfacePrimary,
          border: Border(
            top: BorderSide(
              color: MitlistColors.borderPrimary,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newItemController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(),
                decoration: const InputDecoration(
                  hintText: 'Add item...',
                ),
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            AppButton(
              text: 'Add',
              size: AppButtonSize.sm,
              onPressed: _addItem,
            ),
          ],
        ),
      ),
    );
  }
}
