import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/list_models.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart';
import '../../repositories/grocery_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/scan/scan_models.dart';
import '../../services/scan/suggestion_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/mitlist_app_bar.dart';

const _uuid = Uuid();
const _newListSentinel = '__new__';

/// A single entry in the flat, reorderable list — either an aisle section
/// header or an actual prediction item.
class _FlatEntry {
  final bool isHeader;
  final String? aisleLabel;
  final GroceryPrediction? prediction;
  final int? itemIndex; // index in the owner's _items list

  const _FlatEntry.header(String label)
      : isHeader = true,
        aisleLabel = label,
        prediction = null,
        itemIndex = null;

  const _FlatEntry.item(GroceryPrediction p, int idx)
      : isHeader = false,
        aisleLabel = null,
        prediction = p,
        itemIndex = idx;
}

class ScanReviewScreen extends ConsumerStatefulWidget {
  final GroceryScanResult scanResult;
  final String groupId;
  final String userId;
  final String? targetListId;
  final String? targetListName;

  const ScanReviewScreen({
    super.key,
    required this.scanResult,
    required this.groupId,
    required this.userId,
    this.targetListId,
    this.targetListName,
  });

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  late List<GroceryPrediction> _items;
  late List<GroceryPrediction> _ignored;
  bool _isAdding = false;

  // Phase 5: store picker
  List<ShoppingLocation> _stores = [];
  ShoppingLocation? _activeStore;

  // Phase 6: suggestions
  List<GrocerySuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.scanResult.items);
    _ignored = List.of(widget.scanResult.ignored);
    _loadStores();
    _loadSuggestions();
  }

  // ---------------------------------------------------------------------------
  // Phase 5: store picker + aisle refresh
  // ---------------------------------------------------------------------------

  Future<void> _loadStores() async {
    if (!mounted) return;
    try {
      final svc = await ref.read(listServiceProviderAsync.future);
      final stores = await svc.listShoppingLocations(widget.groupId);
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _activeStore = stores.isNotEmpty ? stores.first : null;
      });
      if (_activeStore != null) await _refreshAisles(_activeStore!.id);
    } catch (_) {
      // Stores are optional; continue without store picker on error.
    }
  }

  Future<void> _refreshAisles(String storeId) async {
    final db = ref.read(appDatabaseProvider);
    final aisles = await db.getStoreAisles(
      groupId: widget.groupId,
      storeId: storeId,
    );
    if (!mounted) return;
    final aisleMap = {for (final a in aisles) a.canonicalItemId: a};
    setState(() {
      _items = _items.map((p) {
        if (p.canonicalItemId == null) return p;
        final a = aisleMap[p.canonicalItemId];
        if (a == null) return p;
        return p.copyWith(aisle: a.aisle, aisleSortOrder: a.sortOrder);
      }).toList();
      _items.sort((a, b) => a.aisleSortOrder.compareTo(b.aisleSortOrder));
    });
  }

  void _onStoreChanged(ShoppingLocation? store) {
    if (store == null) return;
    setState(() => _activeStore = store);
    unawaited(_refreshAisles(store.id));
  }

  // ---------------------------------------------------------------------------
  // Phase 5: drag-to-reorder
  // ---------------------------------------------------------------------------

  String get _otherAisle => AppLocalizations.of(context)!.aisleOther;

  List<_FlatEntry> _buildFlatEntries() {
    String? currentAisle;
    final entries = <_FlatEntry>[];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final aisle = item.aisle ?? _otherAisle;
      if (aisle != currentAisle) {
        entries.add(_FlatEntry.header(aisle));
        currentAisle = aisle;
      }
      entries.add(_FlatEntry.item(item, i));
    }
    return entries;
  }

  void _onReorder(int oldFlat, int newFlat) {
    final entries = _buildFlatEntries();
    if (oldFlat >= entries.length) return;
    if (entries[oldFlat].isHeader) return; // headers aren't reorderable

    // Flutter calls onReorder with newIndex AFTER the removal.
    if (newFlat > oldFlat) newFlat--;

    // Clamp to valid item slots (skip header destinations).
    while (newFlat < entries.length && entries[newFlat].isHeader) {
      newFlat++;
    }
    if (newFlat >= entries.length) newFlat = entries.length - 1;
    while (newFlat > 0 && entries[newFlat].isHeader) {
      newFlat--;
    }
    if (newFlat < 0 || entries[newFlat].isHeader) return;

    final srcIdx = entries[oldFlat].itemIndex!;
    final dstIdx = entries[newFlat].itemIndex!;
    if (srcIdx == dstIdx) return;

    setState(() {
      final moved = _items.removeAt(srcIdx);
      // Determine new aisle from surrounding items.
      final newAisle = _aisleForInsertionPoint(dstIdx, entries, newFlat);
      final reinserted = moved.copyWith(aisle: newAisle);
      _items.insert(dstIdx, reinserted);
      _renumberSortOrders();
    });
    unawaited(_uploadAisleFeedback());
  }

  /// Infers the aisle name for the position around [flatIdx] in [entries].
  String _aisleForInsertionPoint(
      int flatIdx, List<_FlatEntry> entries, int nearFlat) {
    // Scan backwards from the flat destination for the nearest header.
    for (int i = nearFlat; i >= 0; i--) {
      if (entries[i].isHeader) return entries[i].aisleLabel!;
    }
    return _items.isNotEmpty ? (_items.first.aisle ?? _otherAisle) : _otherAisle;
  }

  void _renumberSortOrders() {
    for (int i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(aisleSortOrder: (i + 1) * 10);
    }
  }

  Future<void> _uploadAisleFeedback() async {
    final storeId = _activeStore?.id;
    final groceryRepo = await ref.read(groceryRepositoryProvider.future);
    final entries = _items
        .where((p) => p.canonicalItemId != null)
        .map((p) => AisleFeedbackEntry(
              id: _uuid.v4(),
              canonicalItemId: p.canonicalItemId!,
              storeId: storeId,
              aisle: p.aisle ?? _otherAisle,
              sortOrder: p.aisleSortOrder,
            ))
        .toList();
    await groceryRepo.updateAisleFeedback(
        groupId: widget.groupId, entries: entries);
  }

  // ---------------------------------------------------------------------------
  // Phase 6: suggestions
  // ---------------------------------------------------------------------------

  Future<void> _loadSuggestions() async {
    final db = ref.read(appDatabaseProvider);
    final presentIds =
        _items.map((p) => p.canonicalItemId).whereType<String>().toList();
    if (presentIds.isEmpty) return;
    final svc = SuggestionService(db);
    final suggestions = await svc.suggest(
      groupId: widget.groupId,
      presentCanonicalIds: presentIds,
    );
    if (mounted) setState(() => _suggestions = suggestions);
  }

  void _addSuggestion(GrocerySuggestion suggestion) {
    final newItem = GroceryPrediction(
      id: _uuid.v4(),
      rawText: suggestion.displayName,
      displayName: suggestion.displayName,
      canonicalItemId: suggestion.canonicalItemId,
      confidenceLevel: ConfidenceLevel.autoAccept,
      confidenceScore: 1.0,
    );
    setState(() {
      _items.add(newItem);
      _suggestions
          .removeWhere((s) => s.canonicalItemId == suggestion.canonicalItemId);
    });
  }

  // ---------------------------------------------------------------------------
  // Item editing
  // ---------------------------------------------------------------------------

  void _updateItem(int index, GroceryPrediction updated) {
    setState(() => _items[index] = updated);
  }

  void _removeItem(int index) {
    final item = _items[index];
    setState(() {
      _items.removeAt(index);
      _ignored.add(item);
    });
  }

  void _restoreIgnored(int index) {
    final item = _ignored[index];
    setState(() {
      _ignored.removeAt(index);
      _items.add(item);
    });
  }

  void _acceptAll() {
    setState(() {
      _items = _items
          .map((p) => p.copyWith(confidenceLevel: ConfidenceLevel.autoAccept))
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Add to list
  // ---------------------------------------------------------------------------

  Future<void> _addToList() async {
    final listId = await _resolveTargetListId();
    if (listId == null || !mounted) return;

    setState(() => _isAdding = true);

    final targetListId = listId;

    final correctionSvc = ref.read(correctionMemoryProvider);
    final groceryRepo = await ref.read(groceryRepositoryProvider.future);
    final repo = await ref.read(listRepositoryProvider.future);

    for (final item in _items) {
      if (item.canonicalItemId != null &&
          item.rawText.toLowerCase() != item.displayName.toLowerCase()) {
        await correctionSvc.recordAlias(
          groupId: widget.groupId,
          userId: widget.userId,
          rawText: item.rawText,
          canonicalItemId: item.canonicalItemId!,
        );
        unawaited(groceryRepo.uploadCorrection(
          groupId: widget.groupId,
          rawText: item.rawText,
          canonicalItemId: item.canonicalItemId!,
        ));
      }
    }

    await Future.wait(_items.map((p) => repo.createItemOfflineFirst(
          targetListId,
          CreateListItemRequest(
            name: p.displayName,
            quantity: p.quantity,
            unit: p.unit,
            canonicalItemId: p.canonicalItemId,
          ),
        )));

    if (mounted) {
      setState(() => _isAdding = false);
      Navigator.of(context).pop(_items.length);
    }
  }

  Future<String?> _resolveTargetListId() async {
    final targetListId = widget.targetListId;
    if (targetListId != null) return targetListId;

    final picked = await _showListPicker();
    if (picked == null || !mounted) return null;
    if (picked != _newListSentinel) return picked;

    return _createTargetList();
  }

  Future<String?> _createTargetList() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showAppBottomSheet<String>(
      context: context,
      title: l10n.scanReviewNewList,
      body: const _NewListSheet(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return null;

    final service = await ref.read(listServiceProviderAsync.future);
    final created = await service.createList(
      CreateListRequest(groupId: widget.groupId, name: name.trim()),
    );

    final repo = await ref.read(listRepositoryProvider.future);
    await repo.refreshLists(widget.groupId);
    return created.id;
  }

  Future<String?> _showListPicker() async {
    final l10n = AppLocalizations.of(context)!;
    final r = await ref.read(listRepositoryProvider.future);
    final lists = await r.getListsByGroupOnce(widget.groupId);

    if (!mounted) return null;

    return showAppBottomSheet<String>(
      context: context,
      title: l10n.scanReviewAddToWhichList,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...lists.map((list) => ListTile(
                leading: const AppIcon(name: 'listBullet'),
                title: Text(list.name),
                onTap: () => Navigator.of(context).pop(list.id),
              )),
          const SizedBox(height: MitlistSpacing.sm),
          ListTile(
            leading: const AppIcon(name: 'plus'),
            title: Text(l10n.scanReviewNewListOption),
            onTap: () => Navigator.of(context).pop(_newListSentinel),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pendingCount = _items
        .where((p) => p.confidenceLevel != ConfidenceLevel.autoAccept)
        .length;
    final flatEntries = _buildFlatEntries();

    final appBarTitle = widget.targetListName != null
        ? l10n.scanReviewAddToList(widget.targetListName!)
        : l10n.scanReviewReviewItems;
    final ctaLabel = widget.targetListId != null
        ? l10n.commonItemCount(_items.length)
        : '${l10n.commonItemCount(_items.length)} ${l10n.recipeAddToList.toLowerCase()}';

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        appBarTitle,
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (pendingCount > 0)
            AppButton(
              text: l10n.scanReviewAcceptAll(pendingCount),
              onPressed: _acceptAll,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
            ),
        ],
      ),
      body: Column(
        children: [
          // Store picker (Phase 5)
          if (_stores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md, MitlistSpacing.sm, MitlistSpacing.md, 0),
              child: Row(
                children: [
                  AppIcon(
                      name: 'storeOutline',
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: MitlistSpacing.xs),
                  Text(
                    l10n.scanReviewStoreLabel,
                    style: MitlistTypography.labelXSmall(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.xs),
                  Expanded(
                    child: AppDropdown<ShoppingLocation>(
                      value: _activeStore,
                      items: _stores
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: _onStoreChanged,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              itemCount: flatEntries.length +
                  (_ignored.isNotEmpty ? _ignored.length + 2 : 0) +
                  (_suggestions.isNotEmpty ? _suggestions.length + 2 : 0),
              itemBuilder: (context, index) {
                // Main items + headers
                if (index < flatEntries.length) {
                  final entry = flatEntries[index];
                  if (entry.isHeader) {
                    return _AisleHeader(
                      key: ValueKey('h_${entry.aisleLabel}'),
                      label: entry.aisleLabel!,
                    );
                  }
                  final itemIdx = entry.itemIndex!;
                  return _PredictionTile(
                    key: ValueKey('i_${entry.prediction!.id}'),
                    index: itemIdx,
                    prediction: entry.prediction!,
                    onChanged: (u) => _updateItem(itemIdx, u),
                    onRemove: () => _removeItem(itemIdx),
                  );
                }

                // Suggestions section (Phase 6)
                final afterItems = index - flatEntries.length;
                if (_suggestions.isNotEmpty) {
                  if (afterItems == 0) {
                    return _SectionLabel(
                      key: const ValueKey('sug_header'),
                      label: l10n.scanReviewYouMightNeed,
                    );
                  }
                  if (afterItems == 1) {
                    return _SuggestionRow(
                      key: const ValueKey('sug_chips'),
                      suggestions: _suggestions,
                      onAdd: _addSuggestion,
                    );
                  }
                }

                // Ignored section
                final afterSuggestions =
                    _suggestions.isNotEmpty ? afterItems - 2 : afterItems;
                if (_ignored.isNotEmpty) {
                  if (afterSuggestions == 0) {
                    return _SectionLabel(
                      key: const ValueKey('ign_header'),
                      label: l10n.scanReviewIgnored,
                    );
                  }
                  final ignoredIdx = afterSuggestions - 1;
                  if (ignoredIdx >= 0 && ignoredIdx < _ignored.length) {
                    return _IgnoredTile(
                      key: ValueKey('ign_$ignoredIdx'),
                      prediction: _ignored[ignoredIdx],
                      onRestore: () => _restoreIgnored(ignoredIdx),
                    );
                  }
                }

                return const SizedBox.shrink(key: ValueKey('_noop'));
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              child: AppButton(
                text: _isAdding ? l10n.commonAdding : ctaLabel,
                onPressed: _items.isEmpty || _isAdding ? null : _addToList,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewListSheet extends StatefulWidget {
  const _NewListSheet();

  @override
  State<_NewListSheet> createState() => _NewListSheetState();
}

class _NewListSheetState extends State<_NewListSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: AppLocalizations.of(context)!.scanReviewScannedList);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          controller: _controller,
          label: l10n.commonListName,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppButton(
          text: l10n.scanReviewCreateList,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Aisle section header — non-draggable
// ---------------------------------------------------------------------------

class _AisleHeader extends StatelessWidget {
  final String label;
  const _AisleHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: MitlistSpacing.md,
        bottom: MitlistSpacing.xs,
      ),
      child: Row(
        children: [
          AppIcon(
              name: 'shoppingCartOutline',
              size: 12,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: MitlistSpacing.xs),
          Text(
            label.toUpperCase(),
            style: MitlistTypography.labelXSmall(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: MitlistSpacing.xs),
          Expanded(
            child: Divider(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic section label (Ignored / Suggestions)
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          top: MitlistSpacing.lg, bottom: MitlistSpacing.xs),
      child: Text(
        label,
        style: MitlistTypography.labelXSmall(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Suggestion chips row (Phase 6)
// ---------------------------------------------------------------------------

class _SuggestionRow extends StatelessWidget {
  final List<GrocerySuggestion> suggestions;
  final ValueChanged<GrocerySuggestion> onAdd;

  const _SuggestionRow({
    super.key,
    required this.suggestions,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: Wrap(
        spacing: MitlistSpacing.xs,
        runSpacing: MitlistSpacing.xs,
        children: suggestions
            .map((s) => Tooltip(
                  message: s.reason,
                  child: ActionChip(
                    avatar: const AppIcon(name: 'plus', size: 14),
                    label: Text(s.displayName),
                    onPressed: () => onAdd(s),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prediction tile — drag handle + confidence state
// ---------------------------------------------------------------------------

class _PredictionTile extends StatelessWidget {
  final int index;
  final GroceryPrediction prediction;
  final ValueChanged<GroceryPrediction> onChanged;
  final VoidCallback onRemove;

  const _PredictionTile({
    super.key,
    required this.index,
    required this.prediction,
    required this.onChanged,
    required this.onRemove,
  });

  Color _stateColor(BuildContext context) {
    return switch (prediction.confidenceLevel) {
      ConfidenceLevel.autoAccept => MitlistColors.success600,
      ConfidenceLevel.review => MitlistColors.warning600,
      ConfidenceLevel.ask => MitlistColors.error600,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stateColor = _stateColor(context);
    final needsAction =
        prediction.confidenceLevel != ConfidenceLevel.autoAccept;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        padding: AppCardPadding.none,
        child: InkWell(
          onTap: needsAction ? () => _openEditor(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: stateColor, width: 3),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.sm,
              vertical: MitlistSpacing.sm,
            ),
            child: Row(
              children: [
                // Drag handle (Phase 5)
                ReorderableDragStartListener(
                  index: index,
                  child: AppIcon(
                    name: 'dragHandle',
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.xs),

                // State dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: stateColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prediction.displayName,
                              style: textTheme.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (prediction.quantity > 1 ||
                              prediction.unit.isNotEmpty)
                            Text(
                              _qtyLabel(),
                              style: MitlistTypography.monoBody(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (needsAction &&
                          prediction.rawText.toLowerCase() !=
                              prediction.displayName.toLowerCase())
                        Text(
                          '"${prediction.rawText}"',
                          style: textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                if (needsAction)
                  AppIcon(name: 'editOutline', size: 18, color: stateColor)
                else
                  AppIcon(
                      name: 'checkCircleOutline', size: 18, color: stateColor),
                const SizedBox(width: MitlistSpacing.xs),
                Semantics(
                  button: true,
                  label: AppLocalizations.of(context)!.scanReviewRemoveItem(prediction.displayName),
                  child: GestureDetector(
                    onTap: onRemove,
                    child: AppIcon(
                        name: 'minusCircleOutline',
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _qtyLabel() {
    if (prediction.quantity != 1 && prediction.unit.isNotEmpty) {
      return '${_fmtQty(prediction.quantity)} ${prediction.unit}';
    }
    if (prediction.quantity != 1) return '×${_fmtQty(prediction.quantity)}';
    if (prediction.unit.isNotEmpty) return prediction.unit;
    return '';
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.round().toString() : q.toString();

  void _openEditor(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showAppBottomSheet<void>(
      context: context,
      title: l10n.scanReviewEditItem,
      body: _ItemEditorSheet(prediction: prediction, onSave: onChanged),
    );
  }
}

// ---------------------------------------------------------------------------
// Ignored tile
// ---------------------------------------------------------------------------

class _IgnoredTile extends StatelessWidget {
  final GroceryPrediction prediction;
  final VoidCallback onRestore;

  const _IgnoredTile(
      {super.key, required this.prediction, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
      child: Row(
        children: [
          AppIcon(
              name: 'removeDoneOutline',
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              prediction.displayName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
            ),
          ),
          AppButton(
            text: AppLocalizations.of(context)!.scanReviewRestore,
            onPressed: onRestore,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item editor bottom sheet
// ---------------------------------------------------------------------------

class _ItemEditorSheet extends StatefulWidget {
  final GroceryPrediction prediction;
  final ValueChanged<GroceryPrediction> onSave;

  const _ItemEditorSheet({required this.prediction, required this.onSave});

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prediction.displayName);
    _qtyCtrl = TextEditingController(
        text: widget.prediction.quantity == 1
            ? ''
            : _fmtQty(widget.prediction.quantity));
    _unitCtrl = TextEditingController(text: widget.prediction.unit);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 1;
    widget.onSave(widget.prediction.copyWith(
      displayName: name,
      quantity: qty,
      unit: _unitCtrl.text.trim(),
      confidenceLevel: ConfidenceLevel.autoAccept,
      confidenceScore: 1.0,
    ));
    Navigator.of(context).pop();
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.round().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.prediction.rawText.toLowerCase() !=
            widget.prediction.displayName.toLowerCase())
          Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Text(
              l10n.scanReviewOCRSaw(widget.prediction.rawText),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        AppInput(controller: _nameCtrl, label: l10n.scanReviewItemName),
        const SizedBox(height: MitlistSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppInput(
                controller: _qtyCtrl,
                label: l10n.scanReviewQty,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(child: AppInput(controller: _unitCtrl, label: l10n.scanReviewUnit)),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (widget.prediction.alternatives.isNotEmpty) ...[
          Text(
            l10n.scanReviewDidYouMean,
            style: MitlistTypography.labelXSmall(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Wrap(
            spacing: MitlistSpacing.xs,
            children: widget.prediction.alternatives
                .map((alt) => ActionChip(
                      label: Text(alt),
                      onPressed: () => _nameCtrl.text = alt,
                    ))
                .toList(),
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppButton(text: l10n.commonConfirm, onPressed: _save),
      ],
    );
  }
}
