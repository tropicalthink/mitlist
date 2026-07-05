import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/list_models.dart';
import '../../services/restock_service.dart';
import '../../theme/animations.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/format_currency.dart';
import '../../utils/haptics.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../sheets/cost_summary_sheet.dart';
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
import 'list_detail_controller.dart';

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
  late ListDetailController _controller;
  bool _showSearch = false;
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _composerFocusNode = FocusNode();
  bool _editingTitle = false;
  bool _showProductSuggestions = false;
  String? _pendingCanonicalId;

  /// Re-entrancy guard spanning a full user gesture (dialog input included), so
  /// the controller stays UI-agnostic. Mirrors the original screen's behavior.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = ListDetailController(
      ref: ref,
      listId: widget.listId,
      initialListName: widget.initialListName,
    )..addListener(_onControllerChanged);
    _composerFocusNode.addListener(_onComposerFocusChanged);
    _newItemController.addListener(_onComposerTextChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    if (widget.autoFocusTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEditingTitle());
    }
    _runLoad();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// Runs the controller load, then pops the keyboard only for an empty list
  /// (the next step is clearly typing). On a populated list it would cover the
  /// items people came to read.
  Future<void> _runLoad() async {
    await _controller.load();
    if (!mounted) return;
    if (!_controller.hasError && _controller.items.isEmpty) {
      FocusScope.of(context).requestFocus(_composerFocusNode);
    }
  }

  void _onComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _controller.refreshSuggestions(_newItemController.text);
      setState(() => _showProductSuggestions = true);
    } else {
      setState(() => _showProductSuggestions = false);
    }
  }

  void _onComposerTextChanged() {
    if (!_composerFocusNode.hasFocus) return;
    _controller.refreshSuggestionsDebounced(_newItemController.text);
  }

  void _startEditingTitle() {
    final name = _controller.listName;
    _titleController.text = name;
    _titleController.selection =
        TextSelection(baseOffset: 0, extentOffset: name.length);
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
    if (newName.isEmpty || newName == _controller.listName) return;
    try {
      await _controller.renameList(newName);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listCouldNotRename)),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ListDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listId != widget.listId) {
      _controller
        ..removeListener(_onControllerChanged)
        ..dispose();
      _showSearch = false;
      _searchController.clear();
      _controller = ListDetailController(
        ref: ref,
        listId: widget.listId,
        initialListName: widget.initialListName,
      )..addListener(_onControllerChanged);
      _runLoad();
      return;
    }
    if (widget.initialListName != null &&
        widget.initialListName!.isNotEmpty &&
        widget.initialListName != oldWidget.initialListName) {
      _controller.setListName(widget.initialListName!);
    }
  }

  @override
  void dispose() {
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _newItemController.removeListener(_onComposerTextChanged);
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _newItemController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _composerFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addItemPhoto(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _controller.addItemPhoto(item);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotAddPhoto)),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _removeItemPhoto(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _controller.removeItemPhoto(item);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotRemovePhoto)),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _toggleItem(ListItem item, bool value) async {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    try {
      await _controller.toggleItem(item, value,
          disableAnimations: disableAnimations);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
      );
    }
  }

  Future<void> _completeAll() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _controller.completeAll();
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _uncheckAll() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _controller.uncheckAll();
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _addItem() async {
    if (_isSaving) return;
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;
    final canonicalId = _pendingCanonicalId;
    _pendingCanonicalId = null;
    _isSaving = true;
    // Clear the field up front so the composer is ready for the next item
    // immediately; the row itself lands via the items stream. The text is
    // restored if the add fails, so nothing is lost.
    _newItemController.clear();
    unawaited(Haptics.light());
    try {
      await _controller.addItem(text, canonicalItemId: canonicalId);
      if (!mounted) return;
      _composerFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      _newItemController.text = text;
      _newItemController.selection =
          TextSelection.collapsed(offset: text.length);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotAddItem)),
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _addRestockSuggestion(RestockSuggestion suggestion) async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await _controller.addRestockSuggestion(suggestion);
      if (!mounted) return;
      unawaited(Haptics.light());
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
      final count = _controller.items.length;
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
    try {
      await _controller.clearItems(onlyChecked: onlyChecked);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotClear)),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _deleteItem(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    var deleted = false;
    try {
      await _controller.deleteItem(item);
      deleted = true;
    } catch (e) {
      if (mounted) {
        unawaited(Haptics.failure());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
        );
      }
    } finally {
      _isSaving = false;
    }
    if (!deleted || !mounted) return;
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
  }

  Future<void> _restoreDeletedItem(ListItem item) async {
    try {
      await _controller.restoreDeletedItem(item);
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
    final priceController = TextEditingController(
      text: item.priceCents != null
          ? (item.priceCents! / 100).toStringAsFixed(2)
          : '',
    );
    final priceStr = await showAppDialog<String>(
      context: context,
      title: l10n.listDetailSetPrice,
      body: TextField(
        controller: priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.listDetailPriceInput,
          prefixText: currencySymbol(_controller.groupCurrency),
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
          onPressed: () =>
              Navigator.of(context).pop(priceController.text.trim()),
        ),
      ],
    );
    priceController.dispose();
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
      await _controller.setItemPrice(item, cents);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotSetPrice)),
        );
      }
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
    try {
      final ok = await _controller.archiveList();
      if (!mounted) return;
      if (ok) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailFailedArchive)),
        );
      }
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
      body: Text(l10n.listDetailDeleteBody),
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
    try {
      final ok = await _controller.deleteList();
      if (!mounted) return;
      if (ok) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotDelete)),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _showCostSummary() async {
    if (!_controller.isReady) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final summary = await _controller.getCostSummary();
      final totalCents = summary['total_cents'] as int? ?? 0;
      final equalShareCents = summary['equal_share_cents'] as int? ?? 0;
      final pricedItems =
          _controller.items.where((i) => i.priceCents != null).length;

      if (!mounted) return;
      await CostSummarySheet.show(
        context,
        listName: _controller.listName,
        totalCents: totalCents,
        equalShareCents: equalShareCents,
        itemCount: pricedItems,
        currencyCode: _controller.groupCurrency,
        onGenerateExpense: totalCents > 0
            ? () async {
                if (_isSaving) return;
                _isSaving = true;
                try {
                  await _controller.generateExpense();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.listDetailExpenseGenerated)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(friendlyErrorMessage(
                              e, AppLocalizations.of(context)!))),
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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    try {
      await _controller.reorderOpen(oldIndex, newIndex);
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
    final groupId = _controller.groupId;
    final userId = await _controller.ensureUserId();
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
      listName: _controller.listName.isNotEmpty ? _controller.listName : null,
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
    final photos = _controller.photosFor(item.id);
    final hasPhoto = photos != null && photos.isNotEmpty;

    final action = await ListItemActionsSheet.show(
      context,
      item: item,
      hasPhoto: hasPhoto,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case ListItemAction.rename:
        await _renameItem(item);
      case ListItemAction.quantity:
        await _setItemQuantity(item);
      case ListItemAction.note:
        await _editItemNote(item);
      case ListItemAction.viewPhoto:
        final viewPhotos = _controller.photosFor(item.id);
        if (viewPhotos != null && viewPhotos.isNotEmpty) {
          await ListItemPhotoViewer.show(context, viewPhotos.first.url);
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

  Future<void> _renameItem(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: item.name);
    final newName = await showAppDialog<String>(
      context: context,
      title: l10n.commonRename,
      body: TextField(
        controller: nameController,
        autofocus: true,
        maxLength: 200,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: l10n.listItemName),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
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
          onPressed: () =>
              Navigator.of(context).pop(nameController.text.trim()),
        ),
      ],
    );
    nameController.dispose();
    if (newName == null || newName.isEmpty || newName == item.name) {
      _isSaving = false;
      return;
    }
    try {
      await _controller.updateItemFields(item, name: newName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _setItemQuantity(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController(
      text: item.quantity == item.quantity.roundToDouble()
          ? item.quantity.toInt().toString()
          : item.quantity.toString(),
    );
    final unitController = TextEditingController(text: item.unit);
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.listItemChangeQuantity,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountController,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.listItemQuantityAmount),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          TextField(
            controller: unitController,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.listItemQuantityUnit),
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
        ],
      ),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonSave,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    final amount =
        double.tryParse(amountController.text.trim().replaceAll(',', '.'));
    final unit = unitController.text.trim();
    amountController.dispose();
    unitController.dispose();
    if (confirmed != true || amount == null || amount <= 0) {
      _isSaving = false;
      return;
    }
    try {
      await _controller.updateItemFields(item, quantity: amount, unit: unit);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _editItemNote(ListItem item) async {
    if (_isSaving) return;
    _isSaving = true;
    final l10n = AppLocalizations.of(context)!;
    final noteController = TextEditingController(text: item.note);
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: item.note.isEmpty ? l10n.listItemAddNote : l10n.listItemEditNote,
      body: TextField(
        controller: noteController,
        autofocus: true,
        minLines: 1,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(labelText: l10n.listItemNoteLabel),
      ),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonSave,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    final note = noteController.text.trim();
    noteController.dispose();
    if (confirmed != true || note == item.note) {
      _isSaving = false;
      return;
    }
    try {
      await _controller.updateItemFields(item, note: note);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
        );
      }
    } finally {
      _isSaving = false;
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
                onPressed: () => Navigator.of(context).pop(_controller.dirty),
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
                      label: l10n.listDetailEditName(_controller.listName),
                      child: GestureDetector(
                        onTap: _startEditingTitle,
                        child: Text(
                          _controller.listName,
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
                  tooltip: _showSearch
                      ? l10n.listDetailCloseSearch
                      : l10n.listDetailSearchTooltip,
                  onPressed: () {
                    unawaited(Haptics.light());
                    final opening = !_showSearch;
                    setState(() => _showSearch = opening);
                    if (!opening) {
                      _searchController.clear();
                      _controller.setSearchQuery('');
                    }
                  },
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
                    PopupMenuItem(
                      value: 'cost_summary',
                      child: Text(l10n.listDetailCostSummary),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'complete_all',
                      child: Text(l10n.listDetailCheckAll),
                    ),
                    PopupMenuItem(
                      value: 'uncheck_all',
                      child: Text(l10n.listDetailUncheckAll),
                    ),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Text(l10n.listDetailClearTitle),
                    ),
                    const PopupMenuDivider(),
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
            _buildProgressStripe(accent),
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
                  onChanged: (value) => _controller.setSearchQuery(value),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_controller.groupId != null)
            ListGroupBanner(groupId: _controller.groupId!),
          Expanded(child: _buildBody()),
          if (!_controller.isLoading && !_controller.hasError)
            ValueListenableBuilder<int>(
              valueListenable: _controller.suggestionsRevision,
              builder: (context, _, __) => _buildBottomBar(),
            ),
        ],
      ),
    );
  }

  /// The list's 6px accent stripe doubling as a progress bar: the filled
  /// portion tracks checked-off items so "how far along is this list" is
  /// visible from the header ("what's due, clearly"). An empty list renders
  /// the faint track only, keeping the stripe as the list's identity mark.
  Widget _buildProgressStripe(ListTileAccent accent) {
    final l10n = AppLocalizations.of(context)!;
    final total = _controller.items.length;
    final done = _controller.items.where((i) => i.checked).length;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: total == 0 ? null : l10n.listDetailProgress(done, total),
      child: Container(
        height: 6,
        width: double.infinity,
        color: accent.stripe.withValues(alpha: 0.25),
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration:
              disableAnimations ? Duration.zero : MitlistAnimations.medium,
          curve: MitlistTheme.easeSettle,
          alignment: Alignment.centerLeft,
          widthFactor: total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
          heightFactor: 1,
          child: ColoredBox(color: accent.stripe),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _runLoad,
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
    if (_controller.isLoading) {
      return _wrapForRefresh(const ListDetailSkeleton());
    }
    if (_controller.hasError) {
      return _wrapForRefresh(ListDetailErrorView(
        message: AppLocalizations.of(context)!.listDetailCouldNotLoad,
        onRetry: _runLoad,
        onDismiss: _controller.dismissError,
      ));
    }

    if (_controller.searchQuery.isNotEmpty) {
      final ordered = _controller.searchOrderedItems;
      if (ordered.isEmpty) {
        return _wrapForRefresh(
            ListDetailSearchEmptyView(onClearSearch: _clearSearch));
      }
      return _buildSearchResultItemList(ordered);
    }

    final open = _controller.openItemsSorted;
    final done = _controller.doneItemsSorted;
    if (open.isEmpty && done.isEmpty) {
      return _wrapForRefresh(ListDetailEmptyView(
        onScan: () => _launchScan(source: ImageSource.camera),
        onType: () => _composerFocusNode.requestFocus(),
      ));
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_controller.groupId != null)
          SliverToBoxAdapter(
            child: RunningLowStrip(
              groupId: _controller.groupId!,
              currentItemNames: _controller.items
                  .where((it) => !it.checked)
                  .map((it) => it.name.toLowerCase())
                  .toSet(),
              onAdd: _addRestockSuggestion,
            ),
          ),
        if (open.isNotEmpty)
          SliverReorderableList(
            itemCount: open.length,
            onReorder: (oldIndex, newIndex) =>
                unawaited(_onReorder(oldIndex, newIndex)),
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
              expanded: _controller.doneSectionExpanded,
              onToggle: _controller.toggleDoneSection,
            ),
          ),
        if (done.isNotEmpty && _controller.doneSectionExpanded)
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
      collapsed: _controller.isCollapsing(item.id),
      onCollapsed: () => _controller.finishSettle(item.id),
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
    final photos = _controller.photosFor(item.id);
    final thumbUrl =
        (photos != null && photos.isNotEmpty) ? photos.first.url : null;

    return ListItemRowReactive(
      item: item,
      photoUrl: thumbUrl,
      currencySymbol: currencySymbol(_controller.groupCurrency),
      claimedLabel: item.claimedBy != null ? '· claimed' : null,
      onToggle: (val) => _toggleItem(item, val),
      onPhotoTap: thumbUrl != null
          ? () => ListItemPhotoViewer.show(context, thumbUrl)
          : null,
      onLongPress: () => _handleItemAction(item),
      reorderIndex: reorderIndex,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.setSearchQuery('');
  }

  Widget _buildBottomBar() {
    return ListComposerBar(
      controller: _newItemController,
      focusNode: _composerFocusNode,
      onAdd: _addItem,
      onScan: () => _launchScan(),
      productSuggestions: _controller.productSuggestions,
      grocerySuggestions: _controller.grocerySuggestions,
      showProductSuggestions: _showProductSuggestions,
      onGrocerySuggestionSelected: (s) =>
          _pendingCanonicalId = s.canonicalItemId,
    );
  }
}
