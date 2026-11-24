import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../utils/list_item_edit.dart';
import '../app_icon.dart';

/// What the accessory row shows: the details at a glance, or one of the two
/// fields that need room of their own.
enum ListEditAccessoryMode { details, unit, price }

/// The row of controls pinned above the keyboard while a list line is
/// edited in place, like the formatting bar of a notes app: amount (− / value
/// / +), unit, price, note, photo and delete. A detail that has a value shows
/// it ("kg", "€3.00"). The row scrolls sideways rather than overflow on a
/// narrow screen or at a large text size.
///
/// The fields' values live in controllers the screen owns; the screen reads
/// them all when the edit is committed, so nothing here writes on its own.
/// Every field shares [tapRegionGroupId] with the line, so moving between the
/// line and this row is not "tapping outside" the edit.
class ListItemEditAccessory extends StatefulWidget {
  const ListItemEditAccessory({
    super.key,
    required this.itemName,
    required this.quantityController,
    required this.quantityFocusNode,
    required this.unitController,
    required this.unitFocusNode,
    required this.priceController,
    required this.priceFocusNode,
    required this.noteController,
    required this.currencySymbol,
    required this.onNote,
    required this.onDelete,
    required this.onDone,
    this.onReturnFocus,
    this.onInteract,
    this.hasPhoto = false,
    this.onAddPhoto,
    this.onViewPhoto,
    this.onRemovePhoto,
    this.tapRegionGroupId,
  });

  /// For screen-reader labels ("Delete Milk").
  final String itemName;

  final TextEditingController quantityController;
  final FocusNode quantityFocusNode;
  final TextEditingController unitController;
  final FocusNode unitFocusNode;
  final TextEditingController priceController;
  final FocusNode priceFocusNode;

  /// Read for the note chip's label; the note field itself sits in the line.
  final TextEditingController noteController;
  final String currencySymbol;

  /// Show the note field under the name and move the keyboard there.
  final VoidCallback onNote;
  final VoidCallback onDelete;

  /// Return / Done in one of this row's fields: the edit is finished.
  final VoidCallback onDone;

  /// A field of this row is closing: hand the keyboard back to the line
  /// before it goes, so the edit does not read as finished.
  final VoidCallback? onReturnFocus;

  /// Called before any control here acts (the screen reads an amount typed
  /// into the name first, so the stepper starts from it).
  final VoidCallback? onInteract;

  final bool hasPhoto;
  final VoidCallback? onAddPhoto;
  final VoidCallback? onViewPhoto;
  final VoidCallback? onRemovePhoto;

  final Object? tapRegionGroupId;

  /// The units offered as one-tap choices, besides whatever is typed.
  static List<String> commonUnits(AppLocalizations l10n) => [
        'g',
        'kg',
        'ml',
        'l',
        l10n.listEditUnitPieces,
        l10n.listEditUnitPack,
        l10n.listEditUnitCan,
        l10n.listEditUnitBottle,
      ];

  @override
  State<ListItemEditAccessory> createState() => _ListItemEditAccessoryState();
}

class _ListItemEditAccessoryState extends State<ListItemEditAccessory> {
  ListEditAccessoryMode _mode = ListEditAccessoryMode.details;

  /// Whether the row has controls scrolled out of sight before / after the
  /// visible part: a fade on that edge says the row scrolls.
  final ValueNotifier<({bool before, bool after})> _overflow =
      ValueNotifier((before: false, after: false));

  bool _onScrollMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;
    _overflow.value = (
      before: metrics.extentBefore > 0.5,
      after: metrics.extentAfter > 0.5,
    );
    return false;
  }

  @override
  void dispose() {
    _overflow.dispose();
    super.dispose();
  }

  Object get _group => widget.tapRegionGroupId ?? EditableText;

  void _interact() => widget.onInteract?.call();

  double get _amount => parseItemAmount(widget.quantityController.text) ?? 1;

  void _step(int delta) {
    _interact();
    final current = _amount;
    final next = (current + delta).clamp(1, 9999).toDouble();
    if (next == current) return;
    unawaited(Haptics.light());
    widget.quantityController.text = formatItemAmount(next);
  }

  void _open(ListEditAccessoryMode mode) {
    _interact();
    final node = mode == ListEditAccessoryMode.unit
        ? widget.unitFocusNode
        : widget.priceFocusNode;
    setState(() => _mode = mode);
    // Focus passes straight to the field as it attaches, so there is no
    // moment where nothing in the edit has the keyboard.
    node.requestFocus();
  }

  void _close() {
    widget.onReturnFocus?.call();
    setState(() => _mode = ListEditAccessoryMode.details);
  }

  void _pickUnit(String unit) {
    final current = widget.unitController.text.trim();
    widget.unitController.text = current == unit ? '' : unit;
    unawaited(Haptics.light());
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return TapRegion(
      groupId: _group,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: l10n.listEditDetailsFor(widget.itemName),
        child: Material(
          key: const ValueKey('list-edit-accessory'),
          color: scheme.surface,
          shape: Border(
            top: BorderSide(
              color: scheme.outline,
              width: MitlistSpacing.space0_5,
            ),
          ),
          child: SafeArea(
            top: false,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                widget.quantityController,
                widget.unitController,
                widget.priceController,
                widget.noteController,
              ]),
              builder: (context, _) {
                final children = switch (_mode) {
                  ListEditAccessoryMode.details => _details(l10n, scheme),
                  ListEditAccessoryMode.unit => _unitEditor(l10n),
                  ListEditAccessoryMode.price => _priceEditor(l10n),
                };
                final row = SingleChildScrollView(
                  key: const ValueKey('list-edit-accessory-scroll'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(MitlistSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(width: MitlistSpacing.xs),
                        children[i],
                      ],
                    ],
                  ),
                );
                return Stack(
                  children: [
                    NotificationListener<ScrollMetricsNotification>(
                      onNotification: (n) => _onScrollMetrics(n.metrics),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) => _onScrollMetrics(n.metrics),
                        child: row,
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _overflow,
                      builder: (context, overflow, _) => Positioned.fill(
                        child: IgnorePointer(
                          child: Row(
                            children: [
                              if (overflow.before)
                                _EdgeFade(
                                  key: const ValueKey(
                                      'list-edit-accessory-more-before'),
                                  color: scheme.surface,
                                  towardsEnd: false,
                                ),
                              const Spacer(),
                              if (overflow.after)
                                _EdgeFade(
                                  key: const ValueKey(
                                      'list-edit-accessory-more'),
                                  color: scheme.surface,
                                  towardsEnd: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _details(AppLocalizations l10n, ColorScheme scheme) {
    final unit = widget.unitController.text.trim();
    final priceCents = parsePriceCents(widget.priceController.text);
    final hasPrice = priceCents != null && priceCents > 0;
    final price = hasPrice
        ? '${widget.currencySymbol}${(priceCents / 100).toStringAsFixed(2)}'
        : null;
    final note = widget.noteController.text.trim();
    final canDecrease = _amount > 1;
    final fieldWidth =
        MediaQuery.textScalerOf(context).scale(MitlistSpacing.space12);

    return [
      // − amount + as one outlined control, so it costs as little of a
      // narrow row as it can while every target stays 44dp.
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.outline,
            width: MitlistSpacing.space0_5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SquareIconButton(
              key: const ValueKey('list-edit-less'),
              icon: 'minus',
              tooltip: l10n.listItemOneLess,
              outlined: false,
              onPressed: canDecrease ? () => _step(-1) : null,
            ),
            // Read out as "Amount" with its value, not a bare number.
            Semantics(
              container: true,
              label: l10n.listItemQuantityAmount,
              child: SizedBox(
                width: fieldWidth,
                child: TextField(
                  key: const ValueKey('list-edit-quantity'),
                  controller: widget.quantityController,
                  focusNode: widget.quantityFocusNode,
                  groupId: _group,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  maxLines: 1,
                  onTap: _interact,
                  onSubmitted: (_) => widget.onDone(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '1',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: MitlistSpacing.sm + MitlistSpacing.xs,
                    ),
                  ),
                ),
              ),
            ),
            _SquareIconButton(
              key: const ValueKey('list-edit-more'),
              icon: 'plus',
              tooltip: l10n.listItemOneMore,
              outlined: false,
              onPressed: () => _step(1),
            ),
          ],
        ),
      ),
      _DetailChip(
        key: const ValueKey('list-edit-unit'),
        icon: 'tagOutline',
        label: unit.isEmpty ? l10n.listItemUnit : unit,
        hasValue: unit.isNotEmpty,
        tooltip:
            unit.isEmpty ? l10n.listEditUnitAdd : l10n.listEditUnitValue(unit),
        onTap: () => _open(ListEditAccessoryMode.unit),
      ),
      _DetailChip(
        key: const ValueKey('list-edit-price'),
        icon: 'banknotes',
        label: price ?? l10n.listDetailPriceInput,
        hasValue: price != null,
        tooltip: price == null
            ? l10n.listEditPriceAdd
            : l10n.listEditPriceValue(price),
        onTap: () => _open(ListEditAccessoryMode.price),
      ),
      _DetailChip(
        key: const ValueKey('list-edit-note'),
        icon: 'editNote',
        label: note.isEmpty ? l10n.listItemNoteLabel : note,
        hasValue: note.isNotEmpty,
        tooltip:
            note.isEmpty ? l10n.listEditNoteAdd : l10n.listEditNoteValue(note),
        onTap: () {
          _interact();
          widget.onNote();
        },
      ),
      if (widget.hasPhoto) ...[
        if (widget.onViewPhoto != null)
          _DetailChip(
            key: const ValueKey('list-edit-photo-view'),
            icon: 'image',
            label: l10n.listItemViewPhoto,
            hasValue: true,
            iconOnly: true,
            tooltip: l10n.listItemViewPhoto,
            onTap: () {
              _interact();
              widget.onViewPhoto!();
            },
          ),
        if (widget.onRemovePhoto != null)
          _SquareIconButton(
            key: const ValueKey('list-edit-photo-remove'),
            icon: 'imageNotSupportedOutline',
            tooltip: l10n.listItemRemovePhoto,
            onPressed: () {
              _interact();
              widget.onRemovePhoto!();
            },
          ),
      ] else if (widget.onAddPhoto != null)
        _SquareIconButton(
          key: const ValueKey('list-edit-photo-add'),
          icon: 'camera',
          tooltip: l10n.listItemAddPhoto,
          onPressed: () {
            _interact();
            widget.onAddPhoto!();
          },
        ),
      _SquareIconButton(
        key: const ValueKey('list-edit-delete'),
        icon: 'trash',
        tooltip: l10n.listEditDeleteItem(widget.itemName),
        color: scheme.error,
        onPressed: widget.onDelete,
      ),
    ];
  }

  List<Widget> _unitEditor(AppLocalizations l10n) {
    final current = widget.unitController.text.trim();
    return [
      _SquareIconButton(
        key: const ValueKey('list-edit-back'),
        icon: 'check',
        tooltip: l10n.listEditBack,
        onPressed: _close,
      ),
      _InlineField(
        fieldKey: const ValueKey('list-edit-unit-field'),
        controller: widget.unitController,
        focusNode: widget.unitFocusNode,
        groupId: _group,
        label: l10n.listItemUnit,
        maxLength: 20,
        onSubmitted: widget.onDone,
      ),
      for (final unit in ListItemEditAccessory.commonUnits(l10n))
        _DetailChip(
          key: ValueKey('list-edit-unit-option-$unit'),
          label: unit,
          hasValue: unit == current,
          selected: unit == current,
          tooltip: unit,
          onTap: () => _pickUnit(unit),
        ),
      if (current.isNotEmpty)
        _SquareIconButton(
          key: const ValueKey('list-edit-unit-clear'),
          icon: 'xMark',
          tooltip: l10n.listEditClearUnit,
          onPressed: () => widget.unitController.clear(),
        ),
    ];
  }

  List<Widget> _priceEditor(AppLocalizations l10n) {
    return [
      _SquareIconButton(
        key: const ValueKey('list-edit-back'),
        icon: 'check',
        tooltip: l10n.listEditBack,
        onPressed: _close,
      ),
      _InlineField(
        fieldKey: const ValueKey('list-edit-price-field'),
        controller: widget.priceController,
        focusNode: widget.priceFocusNode,
        groupId: _group,
        label: l10n.listDetailPriceInput,
        hint: l10n.listDetailPriceHint,
        prefix: widget.currencySymbol,
        numeric: true,
        onSubmitted: widget.onDone,
      ),
      if (widget.priceController.text.trim().isNotEmpty)
        _SquareIconButton(
          key: const ValueKey('list-edit-price-clear'),
          icon: 'xMark',
          tooltip: l10n.listEditClearPrice,
          onPressed: () => widget.priceController.clear(),
        ),
    ];
  }
}

/// A text field that sits in the row: the unit or the price being typed.
class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.groupId,
    required this.label,
    required this.onSubmitted,
    this.hint,
    this.prefix,
    this.numeric = false,
    this.maxLength,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Object groupId;
  final String label;
  final String? hint;
  final String? prefix;
  final bool numeric;
  final int? maxLength;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.textScalerOf(context)
        .scale(MitlistSpacing.space24 + MitlistSpacing.md);
    return Semantics(
      container: true,
      label: label,
      child: SizedBox(
        width: width,
        child: TextField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          groupId: groupId,
          maxLines: 1,
          maxLength: maxLength,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          inputFormatters: numeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
              : null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint ?? label,
            prefixText: prefix,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.sm,
              vertical: MitlistSpacing.sm + MitlistSpacing.xs,
            ),
          ),
        ),
      ),
    );
  }
}

/// A square, 2px-outlined chip: an icon and a word, or the value it holds.
class _DetailChip extends StatelessWidget {
  const _DetailChip({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.hasValue = false,
    this.selected = false,
    this.iconOnly = false,
  });

  final String? icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool hasValue;
  final bool selected;

  /// Always just the icon. Otherwise a chip with an icon shows only the icon
  /// until it holds a value, then only the value: [tooltip] carries the
  /// meaning for touch and screen readers either way, and the row keeps
  /// amount, unit, price and note in view on a 360dp phone.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : hasValue
            ? scheme.onSurface
            : scheme.onSurfaceVariant;
    final maxLabel =
        MediaQuery.textScalerOf(context).scale(MitlistSpacing.space16);
    final showLabel = icon == null || (hasValue && !iconOnly);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : hasValue
                  ? scheme.surfaceContainerHigh
                  : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(
              color: hasValue || selected ? scheme.onSurface : scheme.outline,
              width: MitlistSpacing.space0_5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: MitlistSpacing.space11,
                minHeight: MitlistSpacing.space11,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showLabel
                      ? MitlistSpacing.xs + MitlistSpacing.space0_5
                      : MitlistSpacing.space0,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: showLabel
                      ? ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxLabel),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: foreground,
                            ),
                          ),
                        )
                      : AppIcon(name: icon!, size: 20, color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon-only, square, 2px-outlined button with a 44dp target.
class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.outlined = true,
  });

  final String icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  /// False inside a group that draws the outline itself (the stepper).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final foreground = color ?? scheme.onSurface;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(
        minWidth: MitlistSpacing.space11,
        minHeight: MitlistSpacing.space11,
      ),
      style: IconButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: outlined
            ? BorderSide(
                color: enabled ? scheme.outline : scheme.outlineVariant,
                width: MitlistSpacing.space0_5,
              )
            : BorderSide.none,
        backgroundColor: scheme.surface,
      ),
      icon: AppIcon(
        name: icon,
        size: 20,
        color: enabled
            ? foreground
            : scheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

/// The soft edge on a side of the row with more controls past it.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({super.key, required this.color, required this.towardsEnd});

  final Color color;
  final bool towardsEnd;

  @override
  Widget build(BuildContext context) {
    final clear = color.withValues(alpha: 0);
    return SizedBox(
      width: MitlistSpacing.lg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: towardsEnd ? [clear, color] : [color, clear],
          ),
        ),
      ),
    );
  }
}
