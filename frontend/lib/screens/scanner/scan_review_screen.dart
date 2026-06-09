import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/list_models.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart';
import '../../services/scan/scan_models.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/mitlist_app_bar.dart';

class ScanReviewScreen extends ConsumerStatefulWidget {
  final GroceryScanResult scanResult;
  final String groupId;
  final String userId;

  const ScanReviewScreen({
    super.key,
    required this.scanResult,
    required this.groupId,
    required this.userId,
  });

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  late List<GroceryPrediction> _items;
  late List<GroceryPrediction> _ignored;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.scanResult.items);
    _ignored = List.of(widget.scanResult.ignored);
  }

  // ---------------------------------------------------------------------------
  // Item editing helpers
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

  // ---------------------------------------------------------------------------
  // Confirm-all: accept everything in review/ask state without editing
  // ---------------------------------------------------------------------------

  void _acceptAll() {
    setState(() {
      _items = _items
          .map((p) => p.copyWith(confidenceLevel: ConfidenceLevel.autoAccept))
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Add to list flow
  // ---------------------------------------------------------------------------

  Future<void> _addToList() async {
    final listId = await _showListPicker();
    if (listId == null || !mounted) return;

    setState(() => _isAdding = true);

    final correctionSvc = ref.read(correctionMemoryProvider);
    final groceryRepo = await ref.read(groceryRepositoryProvider.future);
    final repo = await ref.read(listRepositoryProvider.future);

    // Save any corrections (items where user changed the display name).
    // Write locally first, then upload asynchronously so it reaches other devices.
    for (final item in _items) {
      if (item.canonicalItemId != null &&
          item.rawText.toLowerCase() != item.displayName.toLowerCase()) {
        await correctionSvc.recordAlias(
          groupId: widget.groupId,
          userId: widget.userId,
          rawText: item.rawText,
          canonicalItemId: item.canonicalItemId!,
        );
        // Best-effort upload — failure is silent, local alias already written.
        unawaited(groceryRepo.uploadCorrection(
          groupId: widget.groupId,
          rawText: item.rawText,
          canonicalItemId: item.canonicalItemId!,
        ));
      }
    }

    // Create all items in parallel for speed.
    await Future.wait(_items.map((p) => repo.createItemOfflineFirst(
          listId,
          CreateListItemRequest(
            name: p.displayName,
            quantity: p.quantity,
            unit: p.unit,
          ),
        )));

    if (mounted) {
      setState(() => _isAdding = false);
      Navigator.of(context).pop(true);
    }
  }

  Future<String?> _showListPicker() async {
    final r = await ref.read(listRepositoryProvider.future);
    final lists = await r.getListsByGroupOnce(widget.groupId);

    if (!mounted) return null;

    return showAppBottomSheet<String>(
      context: context,
      title: 'Add to which list?',
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
            title: const Text('New list…'),
            onTap: () => Navigator.of(context).pop('__new__'),
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
    final pendingCount = _items
        .where((p) => p.confidenceLevel != ConfidenceLevel.autoAccept)
        .length;

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Review items',
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (pendingCount > 0)
            TextButton(
              onPressed: _acceptAll,
              child: Text('Accept all ($pendingCount)'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Engine badge
          if (widget.scanResult.engine == 'crofai')
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.md,
                vertical: MitlistSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: MitlistSpacing.xs),
                  Text(
                    'Recognised via cloud fallback',
                    style: MitlistTypography.labelXSmall(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              children: [
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xl),
                    child: Center(
                      child: Text(
                        'No items detected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  )
                else ...[
                  ..._items.asMap().entries.map((e) => _PredictionTile(
                        key: ValueKey(e.value.id),
                        prediction: e.value,
                        onChanged: (updated) => _updateItem(e.key, updated),
                        onRemove: () => _removeItem(e.key),
                      )),
                ],

                // Ignored section
                if (_ignored.isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.lg),
                  Text(
                    'Ignored',
                    style: MitlistTypography.labelXSmall(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.sm),
                  ..._ignored.asMap().entries.map((e) => _IgnoredTile(
                        prediction: e.value,
                        onRestore: () => _restoreIgnored(e.key),
                      )),
                ],
              ],
            ),
          ),

          // Bottom action bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    text: _isAdding
                        ? 'Adding…'
                        : 'Add ${_items.length} item${_items.length == 1 ? '' : 's'} to list',
                    onPressed: _items.isEmpty || _isAdding ? null : _addToList,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prediction tile — shows one item with its confidence state
// ---------------------------------------------------------------------------

class _PredictionTile extends StatelessWidget {
  final GroceryPrediction prediction;
  final ValueChanged<GroceryPrediction> onChanged;
  final VoidCallback onRemove;

  const _PredictionTile({
    super.key,
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
    final needsAction = prediction.confidenceLevel != ConfidenceLevel.autoAccept;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        padding: AppCardPadding.none,
        child: InkWell(
          onTap: needsAction
              ? () => _openEditor(context)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: stateColor, width: 3),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.md,
              vertical: MitlistSpacing.sm,
            ),
            child: Row(
              children: [
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
                            ),
                          ),
                          if (prediction.quantity > 1 || prediction.unit.isNotEmpty)
                            Text(
                              _qtyLabel(),
                              style: MitlistTypography.monoBody(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (needsAction && prediction.rawText.toLowerCase() !=
                          prediction.displayName.toLowerCase())
                        Text(
                          '"${prediction.rawText}"',
                          style: textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (prediction.aisle != null && prediction.aisle!.isNotEmpty)
                        Text(
                          prediction.aisle!,
                          style: MitlistTypography.labelXSmall(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                // Actions
                if (needsAction)
                  Icon(Icons.edit_outlined,
                      size: 18, color: stateColor)
                else
                  Icon(Icons.check_circle_outline,
                      size: 18, color: stateColor),
                const SizedBox(width: MitlistSpacing.xs),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(Icons.remove_circle_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    showAppBottomSheet<void>(
      context: context,
      title: 'Edit item',
      body: _ItemEditorSheet(
        prediction: prediction,
        onSave: onChanged,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ignored tile
// ---------------------------------------------------------------------------

class _IgnoredTile extends StatelessWidget {
  final GroceryPrediction prediction;
  final VoidCallback onRestore;

  const _IgnoredTile({required this.prediction, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.remove_done_outlined,
              size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.sm, vertical: 0)),
            child: const Text('Restore'),
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

  const _ItemEditorSheet(
      {required this.prediction, required this.onSave});

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
      // Accept the item: user confirmed the name.
      confidenceLevel: ConfidenceLevel.autoAccept,
      confidenceScore: 1.0,
    ));
    Navigator.of(context).pop();
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.round().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.prediction.rawText.toLowerCase() !=
            widget.prediction.displayName.toLowerCase())
          Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Text(
              'OCR saw: "${widget.prediction.rawText}"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        AppInput(
          controller: _nameCtrl,
          label: 'Item name',
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppInput(
                controller: _qtyCtrl,
                label: 'Qty',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: AppInput(
                controller: _unitCtrl,
                label: 'Unit',
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        // Alternatives
        if (widget.prediction.alternatives.isNotEmpty) ...[
          Text(
            'Did you mean?',
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
                      onPressed: () {
                        _nameCtrl.text = alt;
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppButton(
          text: 'Confirm',
          onPressed: _save,
        ),
      ],
    );
  }
}
