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
import '../../services/restock_service.dart';
import '../../services/scan/grocery_suggestion_service.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../sheets/cost_summary_sheet.dart';
import '../../utils/list_composer_parser.dart';
import '../../widgets/list/list_all_done_panel.dart';
import '../../widgets/list/list_composer_bar.dart';
import '../../widgets/list/list_detail_skeleton.dart';
import '../../widgets/list/list_detail_states.dart';
import '../../widgets/list/list_done_section_header.dart';
import '../../widgets/list/list_group_banner.dart';
import '../../widgets/list/list_item_actions_sheet.dart';
import '../../widgets/list/list_item_photo_viewer.dart';
import '../../widgets/list/list_item_row_reactive.dart';
import '../../widgets/list/list_scan_launcher.dart';
import '../../widgets/list/list_settle_collapse.dart';
import '../../widgets/list/running_low_strip.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/mitlist_app_bar.dart';

/// Optional [GoRouter] `extra` when opening a list from the hub (title shows immediately).
class ListDetailRouteArgs {
  const ListDetailRouteArgs({this.listName, this.autoFocusTitle = false});
  final String? listName;
  final bool autoFocusTitle;
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
  int _suggestGeneration = 0;

  // Cached sorted sections — recomputed only when items or settle-state changes.
  List<ListItem> _openItems = const [];
  List<ListItem> _doneItems = const [];
  bool _sectionsDirty = true;

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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listCouldNotRename)),
        );
      }
    }
  }

  /// Refreshes both suggestion sources for the current composer text: the
  /// offline canonical grocery seed (alias-powered) and the backend product
  /// history. A generation counter ensures stale results from a prior keystroke
  /// are silently discarded if a newer query has already started.
  Future<void> _refreshSuggestions() async {
    final groupId = _groupId;
    if (groupId == null) return;
    final query = _newItemController.text.trim();
    final gen = ++_suggestGeneration;

    // Local grocery seed first — alias-powered, on-device.
    final grocery = await ref
        .read(grocerySuggestionServiceProvider)
        .suggest(query, groupId);
    if (!mounted || _suggestGeneration != gen) return;

    // When the composer is empty, prepend restock predictions.
    List<GrocerySuggestion> blended = grocery;
    if (query.isEmpty) {
      try {
        final currentNames = _items
            .where((it) => !it.checked)
            .map((it) => it.name.toLowerCase())
            .toSet();
        final restock = await ref.read(restockServiceProvider).due(
              groupId: groupId,
              currentItemNames: currentNames,
              limit: 5,
            );
        if (!mounted || _suggestGeneration != gen) return;
        if (restock.isNotEmpty) {
          final restockChips = restock.map((r) => GrocerySuggestion(
                canonicalItemId: r.canonicalItemId,
                name: r.name,
                category: '',
                unit: '',
              ));
          blended = [...restockChips, ...grocery];
        }
      } catch (_) {}
    }

    if (!mounted || _suggestGeneration != gen) return;
    setState(() => _grocerySuggestions = blended);

    try {
      final service = await ref.read(listServiceProviderAsync.future);
      if (!mounted || _suggestGeneration != gen) return;
      final products = await service.listProducts(groupId,
          search: query.isEmpty ? null : query);
      if (!mounted || _suggestGeneration != gen) return;
      setState(() => _productSuggestions = products.take(8).toList());
    } catch (_) {
      if (mounted && _suggestGeneration == gen) {
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
          _sectionsDirty = true;
          _items
            ..clear()
            ..addAll(items);
        });
        unawaited(_loadPhotosForItems(items));
      });

      final cached = await repo.getItemsByListOnce(widget.listId);
      if (!mounted) return;
      final cachedGroupId = await repo.getGroupId(widget.listId);
      if (!mounted) return;
      setState(() {
        _sectionsDirty = true;
        _items
          ..clear()
          ..addAll(cached);
        _isLoading = cached.isEmpty;
        if (cachedGroupId != null) _groupId = cachedGroupId;
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
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.listDetailCouldNotLoad;
      });
    }
  }

  Future<void> _loadPhotosForItems(List<ListItem> items) async {
    final groupId = _groupId;
    final service = _service;
    if (groupId == null || service == null) return;

    final toLoad =
        items.where((item) => !_photoLoadAttempted.contains(item.id)).toList();
    if (toLoad.isEmpty) return;
    for (final item in toLoad) {
      _photoLoadAttempted.add(item.id);
    }

    final batch = <String, List<ListItemPhoto>>{};
    await Future.wait(
      toLoad.map((item) async {
        try {
          final photos = await service.listItemPhotos(
            groupId: groupId,
            itemId: item.id,
          );
          if (photos.isNotEmpty) batch[item.id] = photos;
        } catch (_) {}
      }),
    );
    if (!mounted || batch.isEmpty) return;
    setState(() => _photosByItemId.addAll(batch));
  }

  Future<void> _addItemPhoto(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final groupId = _groupId;
    if (groupId == null) {
      _isSaving = false;
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      _isSaving = false;
      return;
    }

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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotAddPhoto)),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _removeItemPhoto(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final groupId = _groupId;
    if (groupId == null) {
      _isSaving = false;
      return;
    }
    final photos = _photosByItemId[item.id];
    if (photos == null || photos.isEmpty) {
      _isSaving = false;
      return;
    }
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
      } catch (_) {}

      final updated =
          await svc.listItemPhotos(groupId: groupId, itemId: item.id);
      if (!mounted) return;
      setState(() => _photosByItemId[item.id] = updated);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotRemovePhoto)),
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
      setState(() {
        _sectionsDirty = true;
        _settling.add(item.id);
      });
      _settleTimers[item.id] = Timer(_settleHold, () {
        if (!mounted) return;
        setState(() {
          _sectionsDirty = true;
          _collapsing.add(item.id);
        });
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
      _dirty = true;
    } catch (e) {
      if (!mounted) return;
      _cancelSettle(item.id);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.listDetailCouldNotUpdate)),
      );
    }
  }

  void _cancelSettle(String id) {
    _settleTimers.remove(id)?.cancel();
    if (_settling.contains(id) || _collapsing.contains(id)) {
      setState(() {
        _sectionsDirty = true;
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
      _sectionsDirty = true;
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
          _dirty = true;
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
          _dirty = true;
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
    if (text.isEmpty) {
      _isSaving = false;
      return;
    }

    final service = _service;
    if (service == null) {
      _isSaving = false;
      return;
    }

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      final parsed = parseComposerItem(text);
      if (parsed.quantity == 1 && parsed.unit.isEmpty) {
        await repo.createItemOfflineFirst(
          widget.listId,
          CreateListItemRequest(name: parsed.name),
        );
      } else {
        // Offline-first too: optimistic local merge/create, additive server
        // sync via the outbox. Previously this branch did a blocking network
        // POST + full refresh, so quantity adds ("2 milk") lagged ~10s on a
        // slow backend and silently failed when it was unreachable.
        await repo.addItemAmountOfflineFirst(
          widget.listId,
          name: parsed.name,
          amount: parsed.quantity,
          unit: parsed.unit,
        );
      }
      if (!mounted) return;
      unawaited(Haptics.light());
      _newItemController.clear();
      _dirty = true;
      _composerFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotAddItem)),
      );
    } finally {
      _isSaving = false;
    }
  }

  /// Adds a restock suggestion to the list via the existing offline-first write
  /// path — the same [listRepositoryProvider.createItemOfflineFirst] call used
  /// by [_addItem]. This is NOT a new write path; only the entry point differs.
  Future<void> _addRestockSuggestion(RestockSuggestion suggestion) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.createItemOfflineFirst(
        widget.listId,
        CreateListItemRequest(
          name: suggestion.name,
          canonicalItemId: suggestion.canonicalItemId,
        ),
      );
      if (!mounted) return;
      unawaited(Haptics.light());
      _dirty = true;
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotAddItem)),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _clearItems({required bool onlyChecked}) async {
    if (_isSaving) return;
    if (!onlyChecked) {
      final count = _items.length;
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showAppDialog<bool>(
        context: context,
        title: l10n.listDetailClearTitle,
        body: Text(
          l10n.listDetailClearBody(count),
        ),
        actions: [
          AppButton(
            text: l10n.commonCancel,
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          AppButton(
            text: l10n.listDetailClearConfirm,
            color: AppButtonColor.error,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
      if (confirmed != true || !mounted) return;
    }
    _isSaving = true;
    final service = _service;
    if (service == null) {
      _isSaving = false;
      return;
    }
    try {
      await service.clearItems(widget.listId, onlyChecked: onlyChecked);
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.refreshItems(widget.listId);
      if (!mounted) return;
      _dirty = true;
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotClear)),
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
    if (service == null) {
      _isSaving = false;
      return;
    }

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.deleteItemOfflineFirst(widget.listId, item.id);
      if (!mounted) return;
      setState(() {
        _sectionsDirty = true;
        _items.remove(item);
      });
      _dirty = true;
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
      _isSaving = false;
      return;
    }

    if (!mounted) {
      _isSaving = false;
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.listDetailItemDeleted(item.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: l10n.commonUndo,
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
          canonicalItemId: item.canonicalItemId,
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
      _dirty = true;
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotRestore)),
      );
    }
  }

  Future<void> _setItemPrice(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: item.priceCents != null
          ? (item.priceCents! / 100).toStringAsFixed(2)
          : '',
    );
    final priceStr = await showAppDialog<String>(
      context: context,
      title: l10n.listDetailSetPrice,
      body: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.listDetailPriceInput,
          prefixText: _currencySymbol,
          hintText: l10n.listDetailPriceHint,
        ),
      ),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonSave,
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    );
    controller.dispose();
    if (priceStr == null || priceStr.isEmpty) {
      _isSaving = false;
      return;
    }
    final price = double.tryParse(priceStr.replaceAll(',', '.'));
    if (price == null || price < 0) {
      _isSaving = false;
      return;
    }
    final cents = (price * 100).round();

    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.updateItemOfflineFirst(
        widget.listId,
        item.id,
        UpdateListItemRequest(priceCents: cents),
      );
      if (!mounted) return;
      _dirty = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotSetPrice)),
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.listDetailArchiveTitle,
      body: Text(l10n.listDetailArchiveBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonArchive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    _isSaving = true;
    if (_service == null) {
      _isSaving = false;
      return;
    }
    try {
      await _service!.archiveList(widget.listId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailFailedArchive)),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _deleteList() async {
    if (_isSaving) return;
    _isSaving = true;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.listDetailDeleteTitle,
      body: Text(
          l10n.listDetailDeleteBody),
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
    if (confirmed != true || !mounted) {
      _isSaving = false;
      return;
    }
    if (_service == null) {
      _isSaving = false;
      return;
    }
    try {
      await _service!.deleteList(widget.listId);
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.deleteListLocal(widget.listId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotDelete)),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _showCostSummary() async {
    if (_service == null) return;
    final l10n = AppLocalizations.of(context)!;
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
                      SnackBar(content: Text(l10n.listDetailExpenseGenerated)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
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
          SnackBar(content: Text(l10n.listDetailCouldNotLoadCostSummary)),
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

  void _ensureSectionsUpToDate() {
    if (!_sectionsDirty) return;
    _openItems = _items.where(_displaysAsOpen).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    _doneItems = _items.where((i) => !_displaysAsOpen(i)).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    _sectionsDirty = false;
  }

  List<ListItem> _openItemsSorted() {
    _ensureSectionsUpToDate();
    return _openItems;
  }

  List<ListItem> _doneItemsSorted() {
    _ensureSectionsUpToDate();
    return _doneItems;
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
      _sectionsDirty = true;
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
          canonicalItemId: item.canonicalItemId,
          claimedBy: item.claimedBy,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );
      }
    });
    _dirty = true;

    unawaited(_persistReorder(itemIdsInOrder));
  }

  Future<void> _persistReorder(List<String> itemIdsInOrder) async {
    try {
      final repo = await ref.read(listRepositoryProvider.future);
      await repo.reorderItemsOfflineFirst(widget.listId, itemIdsInOrder);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.listDetailCouldNotReorder),
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotStartScan)),
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
    final l10n2 = AppLocalizations.of(context)!;
    final message = l10n2.listDetailItemsAdded(addedCount);
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
          await ListItemPhotoViewer.show(context, photos.first.url);
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

    final l10n = AppLocalizations.of(context)!;
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
                tooltip: l10n.commonBack,
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
                  : Semantics(
                      button: true,
                      label: l10n.listDetailEditName(_listName),
                      child: GestureDetector(
                        onTap: _startEditingTitle,
                        child: Text(
                          _listName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                   tooltip: _showSearch ? l10n.listDetailCloseSearch : l10n.listDetailSearchTooltip,
                  onPressed: () {
                    unawaited(Haptics.light());
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
                   tooltip: l10n.listDetailScanList,
                  onPressed: () => _launchScan(),
                ),
                PopupMenuButton<String>(
                  icon: const AppIcon(name: 'ellipsisVertical'),
                   tooltip: l10n.listOptionsTooltip,
                  onSelected: _onMenuSelected,
                   itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.commonRename),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'complete_all',
                      child: Text(l10n.listDetailCheckAll),
                    ),
                    PopupMenuItem(
                      value: 'cost_summary',
                      child: Text(l10n.listDetailCostSummary),
                    ),
                    PopupMenuItem(
                      value: 'uncheck_all',
                      child: Text(l10n.listDetailUncheckAll),
                    ),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Text(l10n.listDetailClearTitle),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(l10n.commonArchive),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.commonDelete,
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
                  decoration: InputDecoration(
                    labelText: l10n.listDetailFilterLabel,
                    hintText: l10n.listDetailFilterHint,
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_groupId != null) ListGroupBanner(groupId: _groupId!),
          Expanded(child: _buildBody()),
          if (!_isLoading && _errorMessage == null) _buildBottomBar(),
        ],
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
    if (_isLoading) return _wrapForRefresh(const ListDetailSkeleton());
    if (_errorMessage != null) {
      return _wrapForRefresh(ListDetailErrorView(
        message: _errorMessage!,
        onRetry: _load,
        onDismiss: () => setState(() => _errorMessage = null),
      ));
    }

    if (_searchQuery.isNotEmpty) {
      final ordered = _searchOrderedItems;
      if (ordered.isEmpty) {
        return _wrapForRefresh(
            ListDetailSearchEmptyView(onClearSearch: _clearSearch));
      }
      return _buildSearchResultItemList(ordered);
    }

    final open = _openItemsSorted();
    final done = _doneItemsSorted();
    if (open.isEmpty && done.isEmpty) {
      return _wrapForRefresh(ListDetailEmptyView(
        onScan: () => _launchScan(source: ImageSource.camera),
        onType: () => _composerFocusNode.requestFocus(),
      ));
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_groupId != null)
          SliverToBoxAdapter(
            child: RunningLowStrip(
              groupId: _groupId!,
              currentItemNames: _items
                  .where((it) => !it.checked)
                  .map((it) => it.name.toLowerCase())
                  .toSet(),
              onAdd: _addRestockSuggestion,
            ),
          ),
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
          SliverToBoxAdapter(
            child: ListAllDonePanel(
              onClearChecked: () => _clearItems(onlyChecked: true),
            ),
          ),
        if (done.isNotEmpty)
          SliverToBoxAdapter(
            child: ListDoneSectionHeader(
              doneCount: done.length,
              expanded: _doneSectionExpanded,
              onToggle: () =>
                  setState(() => _doneSectionExpanded = !_doneSectionExpanded),
            ),
          ),
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

  Widget _buildSearchResultItemList(List<ListItem> items) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildDismissibleItemRow(items[index]);
      },
    );
  }

  Widget _buildDismissibleItemRow(ListItem item, {int? reorderIndex}) {
    return SettleCollapse(
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

    return ListItemRowReactive(
      item: item,
      photoUrl: thumbUrl,
      currencySymbol: _currencySymbol,
      claimedLabel: item.claimedBy != null ? '\u00b7 claimed' : null,
      onToggle: (val) => _toggleItem(item, val),
      onPhotoTap: thumbUrl != null
          ? () => ListItemPhotoViewer.show(context, thumbUrl)
          : null,
      onLongPress: () => _handleItemAction(item),
      reorderIndex: reorderIndex,
    );
  }

  String get _currencySymbol {
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CAD': 'CA\$',
      'AUD': 'A\$',
      'NZD': 'NZ\$',
      'CHF': 'CHF',
      'CNY': '¥',
      'HKD': 'HK\$',
      'SGD': 'S\$',
      'SEK': 'kr',
      'NOK': 'kr',
      'DKK': 'kr',
      'INR': '₹',
      'BRL': 'R\$',
      'MXN': 'MX\$',
      'ZAR': 'R',
      'KRW': '₩',
      'TRY': '₺',
    };
    return symbols[_groupCurrency] ?? _groupCurrency;
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
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
