import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/list_models.dart';
import '../../models/list_item_photo_models.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/list_provider.dart';
import '../../services/list_service.dart';
import '../../theme/animations.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../sheets/cost_summary_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';

/// Optional [GoRouter] `extra` when opening a list from the hub (title shows immediately).
class ListDetailRouteArgs {
  const ListDetailRouteArgs({this.listName});
  final String? listName;
}

class _ParsedComposerItem {
  const _ParsedComposerItem({
    required this.name,
    this.quantity = 1,
    this.unit = '',
  });

  final String name;
  final double quantity;
  final String unit;
}

class ListDetailScreen extends ConsumerStatefulWidget {
  final String listId;
  final String? initialListName;

  const ListDetailScreen({
    super.key,
    required this.listId,
    this.initialListName,
  });

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _listName = '';
  final List<ListItem> _items = [];
  StreamSubscription<List<ListItem>>? _itemsSub;
  bool _showCompletionBanner = false;
  bool _showSearch = false;
  String _searchQuery = '';
  Timer? _bannerTimer;
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  ListService? _service;
  bool _dirty = false;
  final FocusNode _composerFocusNode = FocusNode();
  bool _doneSectionExpanded = true;
  String? _groupId;
  List<Product> _productSuggestions = [];
  bool _showProductSuggestions = false;
  final Map<String, List<ListItemPhoto>> _photosByItemId = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialListName != null && widget.initialListName!.isNotEmpty) {
      _listName = widget.initialListName!;
    }
    _composerFocusNode.addListener(_onComposerFocusChanged);
    _load();
  }

  void _onComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _loadProductSuggestions();
      setState(() => _showProductSuggestions = true);
    } else {
      setState(() => _showProductSuggestions = false);
    }
  }

  Future<void> _loadProductSuggestions() async {
    if (_groupId == null) return;
    try {
      final service = await ref.read(listServiceProviderAsync.future);
      final products = await service.listProducts(_groupId!, search: _newItemController.text.isEmpty ? null : _newItemController.text);
      if (!mounted) return;
      setState(() => _productSuggestions = products.take(8).toList());
    } catch (_) {
      if (mounted) {
        setState(() => _productSuggestions = []);
      }
    }
  }

  @override
  void didUpdateWidget(covariant ListDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listId != widget.listId) {
      _service = null;
      _items.clear();
      _searchQuery = '';
      _showSearch = false;
      _searchController.clear();
      _listName =
          (widget.initialListName != null && widget.initialListName!.isNotEmpty)
              ? widget.initialListName!
              : '';
      _load();
      return;
    }
    if (widget.initialListName != null &&
        widget.initialListName!.isNotEmpty &&
        widget.initialListName != oldWidget.initialListName) {
      setState(() => _listName = widget.initialListName!);
    }
  }

  @override
  void dispose() {
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _bannerTimer?.cancel();
    _itemsSub?.cancel();
    _newItemController.dispose();
    _searchController.dispose();
    _composerFocusNode.dispose();
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
      final repo = await ref.read(listRepositoryProvider.future);

      await _itemsSub?.cancel();
      _itemsSub = repo.watchItemsByList(widget.listId).listen((items) {
        if (!mounted) return;
        setState(() {
          _items
            ..clear()
            ..addAll(items);
        });
        _checkCompletionBanner();
      });

      final cached = await repo.getItemsByListOnce(widget.listId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(cached);
        _isLoading = cached.isEmpty;
      });

      // Refresh list + items in background; stream will update.
      await repo.refreshListDetail(widget.listId);
      final list = await service.getList(widget.listId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _listName = list.name;
        _groupId = list.groupId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _addItemPhoto(ListItem item) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      final attachmentRepo =
          await ref.read(attachmentRepositoryProvider.future);
      final attachment = await attachmentRepo.uploadAttachment(
        groupId: groupId,
        purpose: 'list_item_photo',
        filename: file.name,
        contentType: 'image/*',
        bytes: Uint8List.fromList(bytes),
      );
      final svc = await ref.read(listServiceProviderAsync.future);
      await svc.attachItemPhoto(
        groupId: groupId,
        itemId: item.id,
        attachmentId: attachment.id,
      );

      final photos =
          await svc.listItemPhotos(groupId: groupId, itemId: item.id);
      if (!mounted) return;
      setState(() => _photosByItemId[item.id] = photos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add photo: $e')),
      );
    }
  }

  Future<void> _openPhotoViewer(String url) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeItemPhoto(ListItem item) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final photos = _photosByItemId[item.id];
    if (photos == null || photos.isEmpty) return;
    final attachmentId = photos.first.attachmentId;

    try {
      final svc = await ref.read(listServiceProviderAsync.future);
      await svc.detachItemPhoto(
        groupId: groupId,
        itemId: item.id,
        attachmentId: attachmentId,
      );

      // Best-effort cleanup: avoid orphaned attachments.
      try {
        final attachSvc = await ref.read(attachmentServiceProviderAsync.future);
        await attachSvc.deleteAttachment(
          groupId: groupId,
          attachmentId: attachmentId,
        );
                  } catch (_) {
                    debugPrint('[ListDetail] Undo item creation failed for ${item.name}');
                  }

      final updated =
          await svc.listItemPhotos(groupId: groupId, itemId: item.id);
      if (!mounted) return;
      setState(() => _photosByItemId[item.id] = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove photo: $e')),
      );
    }
  }

  Future<void> _toggleItem(ListItem item, bool value) async {
    Haptics.light();
    final service = _service;
    if (service == null) return;

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.updateItemOfflineFirst(
        widget.listId,
        item.id,
        UpdateListItemRequest(checked: value),
      );
      if (!mounted) return;
      setState(() => _dirty = true);
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
        final repo = await ref.read(listRepositoryProvider.future);
        await repo.updateItemOfflineFirst(
          widget.listId,
          item.id,
          UpdateListItemRequest(checked: true),
        );
        if (!mounted) return;
        setState(() {
          _dirty = true;
        });
      } catch (_) {
        break;
      }
    }
    _checkCompletionBanner();
  }

  void _checkCompletionBanner() {
    if (!mounted) return;
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
      final repo = await ref.read(listRepositoryProvider.future);
      final parsed = _parseComposerItem(text);
      if (parsed.quantity == 1 && parsed.unit.isEmpty) {
        await repo.createItemOfflineFirst(
          widget.listId,
          CreateListItemRequest(name: parsed.name),
        );
      } else {
        await service.addItemAmount(
          widget.listId,
          AddListItemAmountRequest(
            name: parsed.name,
            amount: parsed.quantity,
            unit: parsed.unit,
          ),
        );
        await repo.refreshItems(widget.listId);
      }
      if (!mounted) return;
      setState(() {
        _newItemController.clear();
        _dirty = true;
      });
      _checkCompletionBanner();
      _composerFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add item: $e')),
      );
    }
  }

  _ParsedComposerItem _parseComposerItem(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return _ParsedComposerItem(name: text.trim());
    final quantity = double.tryParse(parts.first.replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      return _ParsedComposerItem(name: text.trim());
    }
    var unit = '';
    var nameStart = 1;
    if (parts.length >= 3 &&
        parts[1].length <= 12 &&
        !RegExp(r'\d').hasMatch(parts[1])) {
      unit = parts[1];
      nameStart = 2;
    }
    final name = parts.skip(nameStart).join(' ').trim();
    if (name.isEmpty) return _ParsedComposerItem(name: text.trim());
    return _ParsedComposerItem(name: name, quantity: quantity, unit: unit);
  }

  Future<void> _clearItems({required bool onlyChecked}) async {
    final service = _service;
    if (service == null) return;
    try {
      await service.clearItems(widget.listId, onlyChecked: onlyChecked);
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.refreshItems(widget.listId);
      if (!mounted) return;
      setState(() => _dirty = true);
      _checkCompletionBanner();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear items: $e')),
      );
    }
  }

  Future<void> _deleteItem(ListItem item) async {
    final service = _service;
    if (service == null) return;

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.deleteItemOfflineFirst(widget.listId, item.id);
      if (!mounted) return;
      setState(() {
        _items.remove(item);
        _dirty = true;
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
                    final repo = await ref.read(listRepositoryProvider.future);
                    await repo.createItemOfflineFirst(
                      widget.listId,
                      CreateListItemRequest(
                        name: item.name,
                        quantity: item.quantity,
                        unit: item.unit,
                        note: item.note,
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _dirty = true;
                    });
                    _checkCompletionBanner();
                  } catch (_) {
                    debugPrint('[ListDetail] Undo item creation failed for ${item.name}');
                  }
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

  Future<void> _setItemPrice(ListItem item) async {
    final controller = TextEditingController(
      text: item.priceCents != null
          ? (item.priceCents! / 100).toStringAsFixed(2)
          : '',
    );
    final priceStr = await showAppDialog<String>(
      context: context,
      title: 'Set price',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              prefixText: '\$',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    if (priceStr == null || priceStr.isEmpty) return;
    final price = double.tryParse(priceStr.replaceAll(',', '.'));
    if (price == null || price < 0) return;
    final cents = (price * 100).round();

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.updateItemOfflineFirst(
        widget.listId,
        item.id,
        UpdateListItemRequest(priceCents: cents),
      );
      if (!mounted) return;
      setState(() => _dirty = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set price: \$e')),
      );
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'complete_all':
        _completeAll();
        break;
      case 'clear_checked':
        _clearItems(onlyChecked: true);
        break;
      case 'clear_all':
        _clearItems(onlyChecked: false);
        break;
      case 'cost_summary':
        _showCostSummary();
        break;
    }
  }

  Future<void> _showCostSummary() async {
    if (_service == null) return;
    try {
      final summary = await _service!.getCostSummary(widget.listId);
      final totalCents = summary['total_cents'] as int? ?? 0;
      final equalShareCents = summary['equal_share_cents'] as int? ?? 0;
      final pricedItems = _items.where((i) => i.priceCents != null).length;

      if (!mounted) return;
      await CostSummarySheet.show(
        context,
        listName: _listName,
        totalCents: totalCents,
        equalShareCents: equalShareCents,
        itemCount: pricedItems,
        onGenerateExpense: totalCents > 0
            ? () async {
                try {
                  await _service!.generateExpense(widget.listId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense generated')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              }
            : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cost summary: $e')),
        );
      }
    }
  }

  List<ListItem> get _filteredItems {
    if (_searchQuery.isEmpty) return List.unmodifiable(_items);
    final lower = _searchQuery.toLowerCase();
    return _items.where((i) => i.name.toLowerCase().contains(lower)).toList();
  }

  /// Unchecked first, then checked while searching.
  List<ListItem> get _searchOrderedItems {
    final list = List<ListItem>.from(_filteredItems);
    list.sort((a, b) {
      if (a.checked != b.checked) {
        return a.checked ? 1 : -1;
      }
      return a.position.compareTo(b.position);
    });
    return list;
  }

  List<ListItem> _openItemsSorted() {
    final list = _items.where((i) => !i.checked).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  List<ListItem> _doneItemsSorted() {
    final list = _items.where((i) => i.checked).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final accent = ListTileAccent.fromSeed(
      widget.listId,
      Theme.of(context).brightness,
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MitlistAppBar(
              leading: IconButton(
                icon: const AppIcon(name: 'arrowLeft'),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(_dirty),
              ),
              title: _showSearch
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Search items',
                        hintText: 'Name, e.g. milk',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    )
                  : Text(
                      _listName,
                      overflow: TextOverflow.ellipsis,
                    ),
              actions: [
                IconButton(
                  icon: const AppIcon(name: 'magnifyingGlass'),
                  tooltip: 'Search',
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
                TextButton(
                  onPressed: _completeAll,
                  child: const Text('Check all'),
                ),
                PopupMenuButton<String>(
                  icon: const AppIcon(name: 'ellipsisVertical'),
                  onSelected: _onMenuSelected,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'cost_summary',
                      child: Text('Cost summary'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_checked',
                      child: Text('Clear checked'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Text('Clear list'),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              height: 6,
              width: double.infinity,
              color: accent.stripe,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () {
              _bannerTimer?.cancel();
              setState(() => _showCompletionBanner = false);
            },
            child: AnimatedContainer(
              duration: MitlistAnimations.banner,
              curve: MitlistTheme.easeToast,
              height: _showCompletionBanner
                  ? MitlistSpacing.space8
                  : MitlistSpacing.space0,
              color: MitlistColors.success500,
              width: double.infinity,
              alignment: Alignment.center,
              child: _showCompletionBanner
                  ? Text(
                      'All done!',
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

    if (_searchQuery.isNotEmpty) {
      final ordered = _searchOrderedItems;
      if (ordered.isEmpty) return _buildEmpty();
      return _buildSearchResultItemList(ordered, textTheme);
    }

    final open = _openItemsSorted();
    final done = _doneItemsSorted();
    if (open.isEmpty && done.isEmpty) return _buildEmpty();

    return CheckboxTheme(
      data: CheckboxThemeData(
        shape: const CircleBorder(),
        side: const BorderSide(
          color: MitlistColors.borderPrimary,
          width: 2,
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MitlistColors.primary500;
          }
          return Theme.of(context).colorScheme.surface;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
        children: [
          ...open.map((item) => _buildDismissibleItemRow(item, textTheme)),
          if (done.isNotEmpty) ...[
            Material(
              color: Theme.of(context).brightness == Brightness.dark
                  ? MitlistColors.neutral800
                  : MitlistColors.neutral100,
              child: InkWell(
                onTap: () => setState(
                  () => _doneSectionExpanded = !_doneSectionExpanded,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.md,
                    vertical: MitlistSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Checked off (${done.length})',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        _doneSectionExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: MitlistColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_doneSectionExpanded)
              ...done.map((item) => _buildDismissibleItemRow(item, textTheme)),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultItemList(List<ListItem> items, TextTheme textTheme) {
    return CheckboxTheme(
      data: CheckboxThemeData(
        shape: const CircleBorder(),
        side: const BorderSide(
          color: MitlistColors.borderPrimary,
          width: 2,
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MitlistColors.primary500;
          }
          return Theme.of(context).colorScheme.surface;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildDismissibleItemRow(items[index], textTheme);
        },
      ),
    );
  }

  Widget _buildDismissibleItemRow(ListItem item, TextTheme textTheme) {
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
      child: _buildItemRow(item, textTheme),
    );
  }

  Widget _buildItemRow(ListItem item, TextTheme textTheme) {
    final photos = _photosByItemId[item.id];
    final thumbUrl =
        (photos != null && photos.isNotEmpty) ? photos.first.url : null;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () => _toggleItem(item, !item.checked),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: MitlistColors.borderSecondary,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (thumbUrl != null) ...[
                GestureDetector(
                  onTap: () => _openPhotoViewer(thumbUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Image.network(thumbUrl, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
              ],
              Semantics(
                label: 'Toggle ${item.name}',
                child: Checkbox(
                  value: item.checked,
                  onChanged: (val) => _toggleItem(item, val ?? false),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  item.name,
                  style: textTheme.bodyLarge?.copyWith(
                    decoration:
                        item.checked ? TextDecoration.lineThrough : null,
                    color: item.checked
                        ? MitlistColors.textTertiary
                        : MitlistColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              if (item.quantity > 1)
                Padding(
                  padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                  child: Text(
                    '${_formatQuantity(item.quantity)}x',
                    style: MitlistTypography.monoBody(
                      color: MitlistColors.textSecondary,
                    ),
                  ),
                ),
              if (item.priceCents != null && item.priceCents! > 0)
                Padding(
                  padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                  child: Text(
                    '\$${(item.priceCents! / 100).toStringAsFixed(2)}',
                    style: MitlistTypography.monoBody(
                      color: MitlistColors.primary500,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Item options',
                onSelected: (v) async {
                  if (v == 'photo') await _addItemPhoto(item);
                  if (v == 'remove_photo') await _removeItemPhoto(item);
                  if (v == 'price') await _setItemPrice(item);
                  if (v == 'delete') await _deleteItem(item);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'photo', child: Text('Add photo')),
                  if (thumbUrl != null)
                    const PopupMenuItem(
                      value: 'remove_photo',
                      child: Text('Remove photo'),
                    ),
                  const PopupMenuItem(value: 'price', child: Text('Set price')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(MitlistSpacing.sm),
                  child: AppIcon(name: 'dotsHorizontal', size: MitlistSpacing.space5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/checklist.lottie',
          icon: const AppIcon(name: 'queueList'),
          title: 'Nothing on the list yet',
          description:
              'Add milk, bread, eggs — whatever you need. Tap the + below to get started.',
          actions: [
            AppButton(
              text: 'Add first item',
              onPressed: () => _composerFocusNode.requestFocus(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final brightness = Theme.of(context).brightness;
    final fill = brightness == Brightness.dark
        ? MitlistColors.neutral900
        : MitlistColors.surfacePrimary;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          border: const Border(
            top: BorderSide(
              color: MitlistColors.borderPrimary,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          MitlistSpacing.md,
          MitlistSpacing.sm,
          MitlistSpacing.md,
          MitlistSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showProductSuggestions && _productSuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _productSuggestions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: MitlistSpacing.sm),
                    itemBuilder: (context, index) {
                      final product = _productSuggestions[index];
                      return ActionChip(
                        label: Text(product.name),
                        onPressed: () {
                          _newItemController.text = product.name;
                          _addItem();
                        },
                      );
                    },
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _newItemController,
                    focusNode: _composerFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addItem(),
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Milk · Oats · 2 avocados',
                      filled: true,
                      fillColor: fill,
                    ),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  icon: const AppIcon(name: 'plus', color: MitlistColors.textOnPrimary),
                  onPressed: _addItem,
                  size: AppButtonSize.lg,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
