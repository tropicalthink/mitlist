import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../app_bottom_sheet.dart';
import '../app_button.dart';
import '../app_icon.dart';

/// What the edit sheet asks the screen to do once it closes, besides saving
/// the fields.
enum ListItemSheetAction { viewPhoto, photo, removePhoto, delete }

/// The fields as the sheet left them. Text is raw: the screen parses and
/// decides what changed.
class ListItemDraft {
  const ListItemDraft({
    required this.name,
    required this.amount,
    required this.unit,
    required this.note,
    required this.price,
  });

  final String name;
  final String amount;
  final String unit;
  final String note;
  final String price;
}

class ListItemSheetResult {
  const ListItemSheetResult({required this.draft, this.action});

  final ListItemDraft draft;
  final ListItemSheetAction? action;
}

/// An item's details: amount and unit, note, price and photo, in one place,
/// so "make it two" is one tap on + instead of a menu, a dialog and a Save.
/// The name is edited in place on the list line itself. Whatever is in the fields when the sheet
/// closes, by Done, a tap outside or a swipe down, is what the screen saves.
///
/// Delete is here as well as behind the row's swipe so screen-reader and
/// keyboard users have a path to it that is not a gesture.
class ListItemEditSheet {
  ListItemEditSheet._();

  static Future<ListItemSheetResult> show(
    BuildContext context, {
    required ListItem item,
    required bool hasPhoto,
    required String currencySymbol,
  }) async {
    ListItemDraft? last;
    final action = await showAppBottomSheet<ListItemSheetAction>(
      context: context,
      title: item.name,
      body: _ListItemEditBody(
        item: item,
        hasPhoto: hasPhoto,
        currencySymbol: currencySymbol,
        onChanged: (draft) => last = draft,
      ),
    );
    return ListItemSheetResult(
      draft: last ?? draftOf(item),
      action: action,
    );
  }

  /// The draft an untouched sheet reports for [item].
  static ListItemDraft draftOf(ListItem item) => ListItemDraft(
        name: item.name,
        amount: formatAmount(item.quantity),
        unit: item.unit,
        note: item.note,
        price: item.priceCents != null && item.priceCents! > 0
            ? (item.priceCents! / 100).toStringAsFixed(2)
            : '',
      );

  static String formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _ListItemEditBody extends StatefulWidget {
  const _ListItemEditBody({
    required this.item,
    required this.hasPhoto,
    required this.currencySymbol,
    required this.onChanged,
  });

  final ListItem item;
  final bool hasPhoto;
  final String currencySymbol;
  final ValueChanged<ListItemDraft> onChanged;

  @override
  State<_ListItemEditBody> createState() => _ListItemEditBodyState();
}

class _ListItemEditBodyState extends State<_ListItemEditBody> {
  // Owned by this State so they outlive the sheet's closing animation; the
  // old dialogs disposed theirs while the route was still fading out.
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _unit;
  late final TextEditingController _note;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final draft = ListItemEditSheet.draftOf(widget.item);
    _name = TextEditingController(text: draft.name);
    _amount = TextEditingController(text: draft.amount);
    _unit = TextEditingController(text: draft.unit);
    _note = TextEditingController(text: draft.note);
    _price = TextEditingController(text: draft.price);
    for (final c in [_name, _amount, _unit, _note, _price]) {
      c.addListener(_report);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _amount, _unit, _note, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  void _report() {
    widget.onChanged(ListItemDraft(
      name: _name.text,
      amount: _amount.text,
      unit: _unit.text,
      note: _note.text,
      price: _price.text,
    ));
    // Rebuild so the minus button tracks the amount.
    setState(() {});
  }

  double? get _parsedAmount =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  void _step(int delta) {
    final current = _parsedAmount ?? 1;
    final next = (current + delta).clamp(1, 9999).toDouble();
    if (next == current) return;
    unawaited(Haptics.light());
    _amount.text = ListItemEditSheet.formatAmount(next);
  }

  void _close([ListItemSheetAction? action]) =>
      Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final amount = _parsedAmount;
    final canDecrease = amount != null && amount > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppButton(
              key: const ValueKey('item-edit-less'),
              icon: const AppIcon(name: 'minus'),
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              tooltip: l10n.listItemOneLess,
              onPressed: canDecrease ? () => _step(-1) : null,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            SizedBox(
              width: MitlistSpacing.space20,
              child: TextField(
                key: const ValueKey('item-edit-amount'),
                controller: _amount,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.listItemQuantityAmount,
                ),
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            AppButton(
              key: const ValueKey('item-edit-more'),
              icon: AppIcon(name: 'plus', color: colorScheme.onPrimary),
              tooltip: l10n.listItemOneMore,
              onPressed: () => _step(1),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: TextField(
                key: const ValueKey('item-edit-unit'),
                controller: _unit,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.listItemUnit,
                  counterText: '',
                ),
                onSubmitted: (_) => _close(),
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        TextField(
          key: const ValueKey('item-edit-note'),
          controller: _note,
          minLines: 1,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.listItemNoteLabel,
            counterText: '',
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        TextField(
          key: const ValueKey('item-edit-price'),
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.listDetailPriceInput,
            prefixText: widget.currencySymbol,
            hintText: l10n.listDetailPriceHint,
          ),
          onSubmitted: (_) => _close(),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            if (widget.hasPhoto)
              AppButton(
                text: l10n.listItemViewPhoto,
                icon: const AppIcon(name: 'eye'),
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.neutral,
                size: AppButtonSize.sm,
                onPressed: () => _close(ListItemSheetAction.viewPhoto),
              ),
            AppButton(
              text: widget.hasPhoto
                  ? l10n.listItemReplacePhoto
                  : l10n.listItemAddPhoto,
              icon: const AppIcon(name: 'camera'),
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.neutral,
              size: AppButtonSize.sm,
              onPressed: () => _close(ListItemSheetAction.photo),
            ),
            if (widget.hasPhoto)
              AppButton(
                text: l10n.listItemRemovePhoto,
                icon: const AppIcon(name: 'imageNotSupportedOutline'),
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.neutral,
                size: AppButtonSize.sm,
                onPressed: () => _close(ListItemSheetAction.removePhoto),
              ),
            AppButton(
              key: const ValueKey('item-edit-delete'),
              text: l10n.commonDelete,
              icon: AppIcon(name: 'trash', color: colorScheme.error),
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.error,
              size: AppButtonSize.sm,
              onPressed: () => _close(ListItemSheetAction.delete),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppButton(
          key: const ValueKey('item-edit-done'),
          text: l10n.commonDone,
          onPressed: _close,
        ),
        const SizedBox(height: MitlistSpacing.sm),
      ],
    );
  }
}
