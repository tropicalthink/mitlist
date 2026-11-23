import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/utils/list_item_edit.dart';

ListItem _item({
  String name = 'Flour',
  double quantity = 1,
  String unit = '',
  String note = '',
  int? priceCents,
}) =>
    ListItem(
      id: 'a',
      listId: 'l',
      name: name,
      quantity: quantity,
      unit: unit,
      note: note,
      checked: false,
      position: 0,
      priceCents: priceCents,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

ListItemEdit _diff(
  ListItem item, {
  String? name,
  String? amount,
  String? unit,
  String? note,
  String? price,
}) =>
    ListItemEdit.diff(
      item,
      name: name ?? item.name,
      amount: amount ?? formatItemAmount(item.quantity),
      unit: unit ?? item.unit,
      note: note ?? item.note,
      price: price ?? formatPriceInput(item.priceCents),
    );

void main() {
  test('nothing changed is no change', () {
    final item = _item(quantity: 2, unit: 'kg', note: 'x', priceCents: 300);
    expect(_diff(item).hasChanges, isFalse);
  });

  test('only the changed fields are sent', () {
    final edit = _diff(_item(), amount: '1,5', price: '2.5');
    expect(edit.quantity, 1.5);
    expect(edit.priceCents, 250);
    expect(edit.name, isNull);
    expect(edit.unit, isNull);
    expect(edit.note, isNull);
  });

  test('an emptied price clears it; an unreadable one is left alone', () {
    final item = _item(priceCents: 899);
    expect(_diff(item, price: '').priceCents, 0);
    final bad = _diff(item, price: '1.2.3');
    expect(bad.priceCents, isNull);
    expect(bad.priceUnreadable, isTrue);
  });

  test('an amount typed into a changed name is read like the add line', () {
    final edit = _diff(_item(name: 'Flour'), name: '2 kg flour');
    expect(edit.name, 'flour');
    expect(edit.quantity, 2);
    expect(edit.unit, 'kg');
  });

  test('an unchanged name that looks like an amount is kept', () {
    expect(_diff(_item(name: '7 Up')).hasChanges, isFalse);
  });

  test('clearing unit and note sends empty strings', () {
    final edit = _diff(_item(unit: 'kg', note: 'x'), unit: '', note: ' ');
    expect(edit.unit, '');
    expect(edit.note, '');
  });

  test('an amount shown rounded and left alone is no change', () {
    // The field shows "0.33"; reading that back must not write 0.33.
    expect(_diff(_item(quantity: 1 / 3)).hasChanges, isFalse);
    expect(_diff(_item(quantity: 1 / 3), amount: '2').quantity, 2);
  });

  test('an untouched name with stray spaces is no change', () {
    expect(_diff(_item(name: 'Flour ')).hasChanges, isFalse);
  });

  test('formatting', () {
    expect(formatItemAmount(2), '2');
    expect(formatItemAmount(1.5), '1.5');
    expect(formatPriceInput(350), '3.50');
    expect(formatPriceInput(null), '');
    expect(parseItemAmount('0'), isNull);
  });
}
