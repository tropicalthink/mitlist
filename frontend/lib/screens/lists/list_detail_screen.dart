import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/list_models.dart';
import '../../providers/list_provider.dart';
import '../../services/list_service.dart';
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
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  final String listId;
  const ListDetailScreen({super.key, required this.listId});

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _listName = '';
  final List<ListItem> _items = [];
  bool _showCompletionBanner = false;
  bool _showSearch = false;
  String _searchQuery = '';
  Timer? _bannerTimer;
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  ListService? _service;

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

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      _service = service;
      final list = await service.getList(widget.listId);
      final items = await service.listItems(widget.listId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _listName = list.name;
        _items
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleItem(ListItem item, bool value) async {
    Haptics.light();
    final service = _service;
    if (service == null) return;

    try {
      final updated = await service.updateItem(widget.listId, item.id,
          UpdateListItemRequest(checked: value));
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((i) => i.id == item.id);
        if (idx >= 0) _items[idx] = updated;
      });
      _checkCompletionBanner();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  void _completeAll() async {
    final service = _service;
    if (service == null) return;

    for (final item in _items.where((i) => !i.checked)) {
      try {
        final updated = await service.updateItem(widget.listId, item.id,
            UpdateListItemRequest(checked: true));
        if (!mounted) return;
        setState(() {
          final idx = _items.indexWhere((i) => i.id == item.id);
          if (idx >= 0) _items[idx] = updated;
        });
      } catch (_) {
        break;
      }
    }
    _checkCompletionBanner();
  }

  void _checkCompletionBanner() {
    final total = _items.length;
    final completed = _items.where((i) => i.checked).length;

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

  Future<void> _addItem() async {
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;

    final service = _service;
    if (service == null) return;

    try {
      final item = await service.createItem(
          widget.listId, CreateListItemRequest(name: text));
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _newItemController.clear();
      });
      _checkCompletionBanner();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add item: $e')),
      );
    }
  }

  Future<void> _deleteItem(ListItem item) async {
    final service = _service;
    if (service == null) return;

    final index = _items.indexOf(item);

    try {
      await service.deleteItem(widget.listId, item.id);
      if (!mounted) return;
      setState(() {
        _items.remove(item);
      });
      _checkCompletionBanner();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item')),
      );
      return;
    }

    if (!mounted) return;
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
                onPressed: () async {
                  final service = _service;
                  if (service == null) return;
                  try {
                    final restored = await service.createItem(
                        widget.listId,
                        CreateListItemRequest(
                            name: item.name, quantity: item.quantity));
                    if (!mounted) return;
                    setState(() {
                      _items.insert(index, restored);
                    });
                    _checkCompletionBanner();
                  } catch (_) {}
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
      case 'complete_all':
        _completeAll();
        break;
    }
  }

  List<ListItem> get _filteredItems {
    if (_searchQuery.isEmpty) return List.unmodifiable(_items);
    final lower = _searchQuery.toLowerCase();
    return _items.where((i) => i.name.toLowerCase().contains(lower)).toList();
  }

  double get _progress {
    if (_items.isEmpty) return 0;
    return _items.where((i) => i.checked).length / _items.length;
  }

  bool get _isComplete =>
      _items.isNotEmpty && _items.every((i) => i.checked);

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
              const PopupMenuItem(
                value: 'complete_all',
                child: Text('Complete all'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
          Expanded(child: _buildBody()),
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
                  value: item.checked,
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
                      decoration: item.checked
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.checked
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
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') _deleteItem(item);
                  },
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
