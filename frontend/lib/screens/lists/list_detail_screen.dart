import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/list_models.dart';
import '../../models/list_item_photo_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attachment_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart';
import '../../services/list_service.dart';
import '../../services/scan/grocery_suggestion_service.dart';
import '../../theme/animations.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../sheets/cost_summary_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list/list_composer_bar.dart';
import '../../widgets/list/list_item_actions_sheet.dart';
import '../../widgets/list/list_item_row.dart';
import '../../widgets/list/list_scan_launcher.dart';
import '../../widgets/odometer.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';

/// Optional [GoRouter] `extra` when opening a list from the hub (title shows immediately).
class ListDetailRouteArgs {
  const ListDetailRouteArgs({this.listName, this.autoFocusTitle = false});
  final String? listName;
  final bool autoFocusTitle;
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
  final bool autoFocusTitle;

  const ListDetailScreen({
    super.key,
    required this.listId,
    this.initialListName,
    this.autoFocusTitle = false,
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
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  bool _editingTitle = false;
  ListService? _service;
  bool _dirty = false;
  final FocusNode _composerFocusNode = FocusNode();
  bool _doneSectionExpanded = true;
  String? _groupId;
  List<Product> _productSuggestions = [];
  List<GrocerySuggestion> _grocerySuggestions = [];
  bool _showProductSuggestions = false;
  Timer? _suggestDebounce;
  final Map<String, List<ListItemPhoto>> _photosByItemId = {};
  final Set<String> _photoLoadAttempted = {};
  bool _isSaving = false;
  String _groupCurrency = 'USD';
  String? _userId;

  /// Checked items briefly held in the open section so the strike animation
  /// plays in place before the row collapses away into "Checked off".
  final Set<String> _settling = {};
  final Set<String> _collapsing = {};
  final Map<String, Timer> _settleTimers = {};

  /// How long a freshly checked row rests in place before collapsing.
  static const Duration _settleHold = Duration(milliseconds: 650);

  @override
  void initState() {
    super.initState();
    if (widget.initialListName != null && widget.initialListName!.isNotEmpty) {
      _listName = widget.initialListName!;
    }
    _composerFocusNode.addListener(_onComposerFocusChanged);
    _newItemController.addListener(_onComposerTextChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    if (widget.autoFocusTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEditingTitle());
    }
    _load();
  }

  void _onComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _refreshSuggestions();
      setState(() => _showProductSuggestions = true);
    } else {
      setState(() => _showProductSuggestions = false);
    }
  }

  void _onComposerTextChanged() {
    if (!_composerFocusNode.hasFocus) return;
    _suggestDebounce?.cancel();
    _suggestDebounce =
        Timer(const Duration(milliseconds: 180), _refreshSuggestions);
  }

  void _startEditingTitle() {
    _titleController.text = _listName;
    _titleController.selection =
        TextSelection(baseOffset: 0, extentOffset: _listName.length);
    setState(() => _editingTitle = true);
    _titleFocusNode.requestFocus();
  }

  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus && _editingTitle) {
      _submitTitleEdit();
    }
  }

  Future<void> _submitTitleEdit() async {
    final newName = _titleController.text.trim();
    setState(() => _editingTitle = false);
    if (newName.isEmpty || newName == _listName) return;
    final svc = _service;
    if (svc == null) return;
    try {
      await svc.updateList(widget.listId, UpdateListRequest(name: newName));
      if (mounted) setState(() => _listName = newName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t rename list.')),
        );
      }
    }
  }

  /// Refreshes both suggestion sources for the current composer text: the
  /// offline canonical grocery seed (alias-powered) and the backend product
  /// history. The grocery seed needs no network and matches shorthand/typos.
  Future<void> _refreshSuggestions() async {
    final groupId = _groupId;
    if (groupId == null) return;
    final query = _newItemController.text.trim();

    // Local grocery seed first — instant, offline.
    final grocery =
        await ref.read(grocerySuggestionServiceProvider).suggest(query, groupId);
    if (mounted) setState(() => _grocerySuggestions = grocery);

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      final products = await service
          .listProducts(groupId, search: query.isEmpty ? null : query);
      if (!mounted) return;
      setState(() => _productSuggestions = products.take(8).toList());
    } catch (_) {
      if (mounted) setState(() => _productSuggestions = []);
    }
  }

  @override
  void didUpdateWidget(covariant ListDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listId != widget.listId) {
      _service = null;
      _items.clear();
      _photosByItemId.clear();
      _photoLoadAttempted.clear();
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
    for (final timer in _settleTimers.values) {
      timer.cancel();
    }
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _newItemController.removeListener(_onComposerTextChanged);
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _suggestDebounce?.cancel();
    _itemsSub?.cancel();
    _newItemController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _composerFocusNode.dispose();
    _titleFocusNode.dispose();
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
        unawaited(_loadPhotosForItems(items));
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

      // Attach SSE so edits from other household members appear in real time.
      final sseService = ref.read(sseServiceProvider);
      repo.attachSse(sseService, list.groupId);
      try {
        final authService = await ref.read(authServiceProviderAsync.future);
        final me = await authService.getMe();
        if (mounted) setState(() => _userId = me.id);
      } catch (_) {}
      try {
        final groupService = await ref.read(groupServiceProviderAsync.future);
        final group = await groupService.getGroup(list.groupId);
        if (mounted) setState(() => _groupCurrency = group.currency);
      } catch (_) {}
      unawaited(_loadPhotosForItems(_items));
      // Pop the keyboard only for an empty list (the next step is clearly
      // typing). On a populated list it would cover the items people came
      // to read.
      if (mounted && _items.isEmpty) {
        FocusScope.of(context).requestFocus(_composerFocusNode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Couldn\u2019t load list.';
      });
    }
  }

  Future<void> _loadPhotosForItems(List<ListItem> items) async {
    final groupId = _groupId;
    final service = _service;
    if (groupId == null || service == null) return;

    final toLoad = items
        .where((item) => !_photoLoadAttempted.contains(item.id))
        .toList();
    if (toLoad.isEmpty) return;
    for (final item in toLoad) {
      _photoLoadAttempted.add(item.id);
    }

    await Future.wait(
      toLoad.map((item) async {
        try {
          final photos = await service.listItemPhotos(
            groupId: groupId,
            itemId: item.id,
          );
          if (!mounted || photos.isEmpty) return;
          setState(() => _photosByItemId[item.id] = photos);
        } catch (_) {}
      }),
    );
  }

  Future<void> _addItemPhoto(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final groupId = _groupId;
    if (groupId == null) { _isSaving = false; return; }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) { _isSaving = false; return; }

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
        SnackBar(content: const Text('Couldn\u2019t add photo.')),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _openPhotoViewer(String url) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Semantics(
                  label: 'List image',
                  child: Image.network(url, fit: BoxFit.contain, cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context) * 1.5).round(), errorBuilder: (_, __, ___) => Center(
                    child: AppIcon(name: 'brokenImage', color: Theme.of(context).colorScheme.onSurface, size: 48),
                  )),
              ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: AppIcon(name: 'xMark', color: Theme.of(context).colorScheme.onSurface),
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
    if (_isSaving) return;
    _isSaving = true;
    final groupId = _groupId;
    if (groupId == null) { _isSaving = false; return; }
    final photos = _photosByItemId[item.id];
    if (photos == null || photos.isEmpty) { _isSaving = false; return; }
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
                  }

      final updated =
          await svc.listItemPhotos(groupId: groupId, itemId: item.id);
      if (!mounted) return;
      setState(() => _photosByItemId[item.id] = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Couldn\u2019t remove photo.')),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _toggleItem(ListItem item, bool value) async {
    unawaited(Haptics.light());
    final service = _service;
    if (service == null) return;

    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (value && !disableAnimations && _searchQuery.isEmpty) {
      // Hold the row in place while the strike draws, then collapse it away
      // into the done section instead of jump-cutting on the next rebuild.
      _settleTimers.remove(item.id)?.cancel();
      setState(() => _settling.add(item.id));
      _settleTimers[item.id] = Timer(_settleHold, () {
        if (!mounted) return;
        setState(() => _collapsing.add(item.id));
      });
    } else {
      _cancelSettle(item.id);
    }

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.updateItemOfflineFirst(
        widget.listId,
        item.id,
        UpdateListItemRequest(checked: value),
      );
      if (!mounted) return;
      setState(() => _dirty = true);
    } catch (e) {
      if (!mounted) return;
      _cancelSettle(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Couldn\u2019t update. Please try again.')),
      );
    }
  }

  void _cancelSettle(String id) {
    _settleTimers.remove(id)?.cancel();
    if (_settling.contains(id) || _collapsing.contains(id)) {
      setState(() {
        _settling.remove(id);
        _collapsing.remove(id);
      });
    }
  }

  /// Called when a settled row finishes its collapse animation; the item then
  /// re-sections into "Checked off" with no visible jump.
  void _finishSettle(String id) {
    _settleTimers.remove(id)?.cancel();
    if (!mounted) return;
    setState(() {
      _settling.remove(id);
      _collapsing.remove(id);
    });
  }

  Future<void> _completeAll() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
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
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _uncheckAll() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      final service = _service;
      if (service == null) return;

      for (final item in _items.where((i) => i.checked)) {
        try {
          final repo = await ref.read(listRepositoryProvider.future);
          await repo.updateItemOfflineFirst(
            widget.listId,
            item.id,
            UpdateListItemRequest(checked: false),
          );
          if (!mounted) return;
          setState(() {
            _dirty = true;
          });
        } catch (_) {
          break;
        }
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _addItem() async {
    if (_isSaving) return;
    _isSaving = true;
    final text = _newItemController.text.trim();
    if (text.isEmpty) { _isSaving = false; return; }

    final service = _service;
    if (service == null) { _isSaving = false; return; }

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
      unawaited(Haptics.light());
      setState(() {
        _newItemController.clear();
        _dirty = true;
      });
      _composerFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\u2019t add item. Please try again.')),
      );
    } finally {
      _isSaving = false;
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
    if (_isSaving) return;
    if (!onlyChecked) {
      final count = _items.length;
      final confirmed = await showAppDialog<bool>(
        context: context,
        title: 'Clear list',
        body: Text(
          'This will remove all $count item${count == 1 ? '' : 's'}. This cannot be undone.',
        ),
        actions: [
          AppButton(
            text: 'Cancel',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          AppButton(
            text: 'Clear list',
            color: AppButtonColor.error,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
      if (confirmed != true || !mounted) return;
    }
    _isSaving = true;
    final service = _service;
    if (service == null) { _isSaving = false; return; }
    try {
      await service.clearItems(widget.listId, onlyChecked: onlyChecked);
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.refreshItems(widget.listId);
      if (!mounted) return;
      setState(() => _dirty = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\u2019t clear items. Please try again.')),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _deleteItem(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    _cancelSettle(item.id);
    final service = _service;
    if (service == null) { _isSaving = false; return; }

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.deleteItemOfflineFirst(widget.listId, item.id);
      if (!mounted) return;
      setState(() {
        _items.remove(item);
        _dirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item')),
      );
      _isSaving = false;
      return;
    }

    if (!mounted) { _isSaving = false; return; }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item.name} deleted',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _restoreDeletedItem(item),
        ),
      ),
    );
    _isSaving = false;
  }

  Future<void> _restoreDeletedItem(ListItem item) async {
    final service = _service;
    if (service == null) return;
    try {
      final repo = await ref.read(listRepositoryProvider.future);
      final restored = await repo.createItemOfflineFirst(
        widget.listId,
        CreateListItemRequest(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          note: item.note,
          priceCents: item.priceCents,
        ),
      );
      if (item.checked) {
        await repo.updateItemOfflineFirst(
          widget.listId,
          restored.id,
          const UpdateListItemRequest(checked: true),
        );
      }
      if (!mounted) return;
      setState(() {
        _dirty = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t restore item.')),
      );
    }
  }

  Future<void> _setItemPrice(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final controller = TextEditingController(
      text: item.priceCents != null
          ? (item.priceCents! / 100).toStringAsFixed(2)
          : '',
    );
    final priceStr = await showAppDialog<String>(
      context: context,
      title: 'Set price',
      body: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Price',
          prefixText: _currencySymbol,
          hintText: '0.00',
        ),
      ),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Save',
          onPressed: () =>
              Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    );
    controller.dispose();
    if (priceStr == null || priceStr.isEmpty) { _isSaving = false; return; }
    final price = double.tryParse(priceStr.replaceAll(',', '.'));
    if (price == null || price < 0) { _isSaving = false; return; }
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
        SnackBar(content: const Text('Couldn\u2019t set price.')),
      );
    } finally {
      _isSaving = false;
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'rename':
        _startEditingTitle();
        break;
      case 'complete_all':
        _completeAll();
        break;
      case 'uncheck_all':
        _uncheckAll();
        break;
      case 'clear_all':
        _clearItems(onlyChecked: false);
        break;
      case 'cost_summary':
        _showCostSummary();
        break;
      case 'archive':
        _archiveList();
        break;
      case 'delete':
        _deleteList();
        break;
    }
  }

  Future<void> _archiveList() async {
    if (_isSaving) return;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Archive list',
      body: const Text('This list will be hidden from your household.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Archive',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    _isSaving = true;
    if (_service == null) { _isSaving = false; return; }
    try {
      await _service!.archiveList(widget.listId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to archive list.')),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _deleteList() async {
    if (_isSaving) return;
    _isSaving = true;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete list',
      body: const Text('This will permanently delete this list and all its items. This cannot be undone.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Delete',
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) { _isSaving = false; return; }
    if (_service == null) { _isSaving = false; return; }
    try {
      await _service!.deleteList(widget.listId);
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.deleteListLocal(widget.listId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t delete list.')),
      );
    } finally {
      _isSaving = false;
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
        currencyCode: _groupCurrency,
        onGenerateExpense: totalCents > 0
            ? () async {
                if (_isSaving) return;
                _isSaving = true;
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
                      SnackBar(content: Text(friendlyErrorMessage(e))),
                    );
                  }
                } finally {
                  _isSaving = false;
                }
              }
            : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\u2019t load cost summary.')),
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
      final aOpen = _displaysAsOpen(a);
      final bOpen = _displaysAsOpen(b);
      if (aOpen != bOpen) {
        return aOpen ? -1 : 1;
      }
      return a.position.compareTo(b.position);
    });
    return list;
  }

  /// Settling rows count as open so they stay in place during the hold.
  bool _displaysAsOpen(ListItem item) =>
      !item.checked || _settling.contains(item.id);

  List<ListItem> _openItemsSorted() {
    final list = _items.where(_displaysAsOpen).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  List<ListItem> _doneItemsSorted() {
    final list = _items.where((i) => !_displaysAsOpen(i)).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  void _onReorderOpen(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    Haptics.light();

    final open = _openItemsSorted();
    final done = _doneItemsSorted();
    final reorderedOpen = List<ListItem>.from(open);
    final moved = reorderedOpen.removeAt(oldIndex);
    reorderedOpen.insert(newIndex, moved);

    final itemIdsInOrder = [
      ...reorderedOpen.map((i) => i.id),
      ...done.map((i) => i.id),
    ];

    setState(() {
      var pos = 0;
      for (final id in itemIdsInOrder) {
        final idx = _items.indexWhere((i) => i.id == id);
        if (idx < 0) continue;
        final item = _items[idx];
        _items[idx] = ListItem(
          id: item.id,
          listId: item.listId,
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          note: item.note,
          checked: item.checked,
          position: pos++,
          priceCents: item.priceCents,
          claimedBy: item.claimedBy,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );
      }
      _dirty = true;
    });

    unawaited(_persistReorder(itemIdsInOrder));
  }

  Future<void> _persistReorder(List<String> itemIdsInOrder) async {
    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.reorderItemsOfflineFirst(widget.listId, itemIdsInOrder);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\u2019t reorder items. Please try again.'),
        ),
      );
    }
  }

  Future<void> _launchScan({ImageSource? source}) async {
    final groupId = _groupId;
    var userId = _userId;
    if (userId == null) {
      try {
        final authService = await ref.read(authServiceProviderAsync.future);
        final me = await authService.getMe();
        userId = me.id;
        if (mounted) setState(() => _userId = userId);
      } catch (_) {}
    }
    if (groupId == null || userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t start scan. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    final addedCount = await launchListScan(
      context,
      ref,
      groupId: groupId,
      userId: userId,
      listId: widget.listId,
      listName: _listName.isNotEmpty ? _listName : null,
      source: source,
    );
    if (!mounted || addedCount == null || addedCount <= 0) return;
    final message = addedCount == 1
        ? '1 item added to list'
        : '$addedCount items added to list';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleItemAction(ListItem item) async {
    final photos = _photosByItemId[item.id];
    final hasPhoto = photos != null && photos.isNotEmpty;

    final action = await ListItemActionsSheet.show(
      context,
      item: item,
      hasPhoto: hasPhoto,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case ListItemAction.viewPhoto:
        final photos = _photosByItemId[item.id];
        if (photos != null && photos.isNotEmpty) {
          await _openPhotoViewer(photos.first.url);
        }
      case ListItemAction.photo:
        await _addItemPhoto(item);
      case ListItemAction.removePhoto:
        await _removeItemPhoto(item);
      case ListItemAction.price:
        await _setItemPrice(item);
      case ListItemAction.delete:
        await _deleteItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ListTileAccent.fromSeed(
      widget.listId,
      Theme.of(context).brightness,
    );

    final headerHeight = kToolbarHeight + 6 + (_showSearch ? 52.0 : 0);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headerHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MitlistAppBar(
              showStandardActions: false,
              leading: IconButton(
                icon: const AppIcon(name: 'arrowLeft'),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(_dirty),
              ),
              title: _editingTitle
                  ? TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _submitTitleEdit(),
                    )
                  : GestureDetector(
                      onTap: _startEditingTitle,
                      child: Text(
                        _listName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              actions: [
                IconButton(
                  icon: AppIcon(
                    name: 'magnifyingGlass',
                    color: _showSearch
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: _showSearch ? 'Close search' : 'Search',
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
                IconButton(
                  icon: const AppIcon(name: 'camera'),
                  tooltip: 'Scan list',
                  onPressed: () => _launchScan(),
                ),
                PopupMenuButton<String>(
                  icon: const AppIcon(name: 'ellipsisVertical'),
                  tooltip: 'List options',
                  onSelected: _onMenuSelected,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'complete_all',
                      child: Text('Check all'),
                    ),
                    const PopupMenuItem(
                      value: 'cost_summary',
                      child: Text('Cost summary'),
                    ),
                    const PopupMenuItem(
                      value: 'uncheck_all',
                      child: Text('Uncheck all'),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Text('Clear list'),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
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
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.xs,
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Filter items',
                    hintText: 'Name, e.g. milk',
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
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
      if (ordered.isEmpty) return _buildSearchEmpty();
      return _buildSearchResultItemList(ordered);
    }

    final open = _openItemsSorted();
    final done = _doneItemsSorted();
    if (open.isEmpty && done.isEmpty) return _buildEmpty();

    return CustomScrollView(
      slivers: [
        if (open.isNotEmpty)
          SliverReorderableList(
            itemCount: open.length,
            onReorder: _onReorderOpen,
            itemBuilder: (context, index) {
              final item = open[index];
              return _buildDismissibleItemRow(item, reorderIndex: index);
            },
          ),
        if (open.isEmpty && done.isNotEmpty)
          SliverToBoxAdapter(child: _buildAllDonePanel()),
        if (done.isNotEmpty)
          SliverToBoxAdapter(child: _buildDoneHeader(done.length, textTheme)),
        if (done.isNotEmpty && _doneSectionExpanded)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildDismissibleItemRow(done[index]),
              childCount: done.length,
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: MitlistSpacing.md),
        ),
      ],
    );
  }

  /// Quiet landing for a fully checked-off list: acknowledgment plus the two
  /// actions that actually come next mid-errand.
  Widget _buildAllDonePanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Row(
        children: [
          AppIcon(name: 'checkCircle', size: 20, color: colorScheme.primary),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              'All checked off',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppButton(
            text: 'Clear checked',
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            onPressed: () => _clearItems(onlyChecked: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneHeader(int doneCount, TextTheme textTheme) {
    final headerStyle = textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () =>
            setState(() => _doneSectionExpanded = !_doneSectionExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          child: Row(
            children: [
              Text('Checked off', style: headerStyle),
              const SizedBox(width: MitlistSpacing.sm),
              MitlistOdometer(value: doneCount, textStyle: headerStyle),
              const Spacer(),
              AppIcon(
                name: _doneSectionExpanded ? 'chevronUp' : 'chevronDown',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItemList(List<ListItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildDismissibleItemRow(items[index]);
      },
    );
  }

  Widget _buildDismissibleItemRow(ListItem item, {int? reorderIndex}) {
    return _SettleCollapse(
      key: ValueKey(item.id),
      collapsed: _collapsing.contains(item.id),
      onCollapsed: () => _finishSettle(item.id),
      child: _buildDismissibleCore(item, reorderIndex: reorderIndex),
    );
  }

  Widget _buildDismissibleCore(ListItem item, {int? reorderIndex}) {
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.md,
        ),
        child: AppIcon(
          name: 'trash',
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      onDismissed: (_) {
        Haptics.medium();
        _deleteItem(item);
      },
      child: _buildItemRow(item, reorderIndex: reorderIndex),
    );
  }

  Widget _buildItemRow(ListItem item, {int? reorderIndex}) {
    final photos = _photosByItemId[item.id];
    final thumbUrl =
        (photos != null && photos.isNotEmpty) ? photos.first.url : null;

    return ListItemRow(
      item: item,
      photoUrl: thumbUrl,
      currencySymbol: _currencySymbol,
      claimedLabel: item.claimedBy != null ? '\u00b7 claimed' : null,
      onToggle: (val) => _toggleItem(item, val),
      onPhotoTap:
          thumbUrl != null ? () => _openPhotoViewer(thumbUrl) : null,
      onLongPress: () => _handleItemAction(item),
      reorderIndex: reorderIndex,
    );
  }

  String get _currencySymbol {
    const symbols = {
      'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
      'CAD': 'CA\$', 'AUD': 'A\$', 'NZD': 'NZ\$', 'CHF': 'CHF',
      'CNY': '¥', 'HKD': 'HK\$', 'SGD': 'S\$', 'SEK': 'kr',
      'NOK': 'kr', 'DKK': 'kr', 'INR': '₹', 'BRL': 'R\$',
      'MXN': 'MX\$', 'ZAR': 'R', 'KRW': '₩', 'TRY': '₺',
    };
    return symbols[_groupCurrency] ?? _groupCurrency;
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
          icon: AppIcon(name: 'queueList'),
          title: 'Nothing here yet',
          description:
              'Photograph a handwritten list, fridge note, or screenshot. We\u2019ll pull out the items.',
          actions: [
            AppButton(
              text: 'Scan a list',
              icon: const AppIcon(name: 'camera'),
              onPressed: () => _launchScan(source: ImageSource.camera),
            ),
            AppButton(
              text: 'Type an item',
              variant: AppButtonVariant.outline,
              onPressed: () => _composerFocusNode.requestFocus(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmpty() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No items match your filter',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: 'Clear search',
              variant: AppButtonVariant.outline,
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return ListComposerBar(
      controller: _newItemController,
      focusNode: _composerFocusNode,
      onAdd: _addItem,
      onScan: () => _launchScan(),
      productSuggestions: _productSuggestions,
      grocerySuggestions: _grocerySuggestions,
      showProductSuggestions: _showProductSuggestions,
    );
  }
}

/// Collapses its child's height to zero (with a fade) when [collapsed] flips
/// on, then reports completion via [onCollapsed] so the parent can re-section
/// the item without a visible jump. At rest it is a transparent passthrough.
class _SettleCollapse extends StatelessWidget {
  const _SettleCollapse({
    super.key,
    required this.collapsed,
    required this.onCollapsed,
    required this.child,
  });

  final bool collapsed;
  final VoidCallback onCollapsed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: collapsed ? 0.0 : 1.0),
      duration: disableAnimations ? Duration.zero : MitlistAnimations.micro,
      curve: MitlistAnimations.easeExit,
      onEnd: () {
        if (collapsed) onCollapsed();
      },
      child: child,
      builder: (context, t, child) {
        if (t >= 1.0) return child!;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
    );
  }
}
