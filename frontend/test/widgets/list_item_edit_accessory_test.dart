import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/list/list_item_edit_accessory.dart';

class _Harness {
  final quantity = TextEditingController(text: '1');
  final unit = TextEditingController();
  final price = TextEditingController();
  final note = TextEditingController();
  final quantityFocus = FocusNode();
  final unitFocus = FocusNode();
  final priceFocus = FocusNode();
  int notes = 0;
  int deletes = 0;
  int dones = 0;
  int returns = 0;
  int adds = 0;

  void dispose() {
    for (final c in [quantity, unit, price, note]) {
      c.dispose();
    }
    for (final f in [quantityFocus, unitFocus, priceFocus]) {
      f.dispose();
    }
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  String quantity = '1',
  String unit = '',
  String price = '',
  String note = '',
  bool hasPhoto = false,
  double width = 390,
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final h = _Harness()
    ..quantity.text = quantity
    ..unit.text = unit
    ..price.text = price
    ..note.text = note;
  addTearDown(h.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? MitlistTheme.light,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ListItemEditAccessory(
            itemName: 'Flour',
            quantityController: h.quantity,
            quantityFocusNode: h.quantityFocus,
            unitController: h.unit,
            unitFocusNode: h.unitFocus,
            priceController: h.price,
            priceFocusNode: h.priceFocus,
            noteController: h.note,
            currencySymbol: '€',
            onNote: () => h.notes++,
            onDelete: () => h.deletes++,
            onDone: () => h.dones++,
            onReturnFocus: () => h.returns++,
            hasPhoto: hasPhoto,
            onAddPhoto: () => h.adds++,
            onViewPhoto: () {},
            onRemovePhoto: () {},
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  return h;
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pump();
}

void main() {
  testWidgets('chips with a value show it', (tester) async {
    await _pump(tester, quantity: '2', unit: 'kg', price: '3', note: 'fine');

    expect(find.text('kg'), findsOneWidget);
    expect(find.text('€3.00'), findsOneWidget);
    expect(find.text('fine'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('list-edit-quantity')).controller!.text,
      '2',
    );
  });

  testWidgets('the stepper keeps decimals and stops at one', (tester) async {
    final h = await _pump(tester, quantity: '1.5');

    await _tap(tester, 'list-edit-more');
    expect(h.quantity.text, '2.5');
    await _tap(tester, 'list-edit-less');
    expect(h.quantity.text, '1.5');
    await _tap(tester, 'list-edit-less');
    expect(h.quantity.text, '1');
    final less = tester.widget<IconButton>(find.descendant(
      of: _key('list-edit-less'),
      matching: find.byType(IconButton),
    ));
    expect(less.onPressed, isNull);

    // The value is typeable too.
    await tester.enterText(_key('list-edit-quantity'), '0,5');
    expect(h.quantity.text, '0,5');
  });

  testWidgets('a common unit is one tap; any other can be typed',
      (tester) async {
    final h = await _pump(tester);

    await _tap(tester, 'list-edit-unit');
    expect(_key('list-edit-unit-field'), findsOneWidget);
    await _tap(tester, 'list-edit-unit-option-kg');
    expect(h.unit.text, 'kg');
    expect(h.returns, 1);
    expect(_key('list-edit-unit-field'), findsNothing);
    expect(find.text('kg'), findsOneWidget);

    await _tap(tester, 'list-edit-unit');
    await tester.enterText(_key('list-edit-unit-field'), 'sachet');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(h.unit.text, 'sachet');
    expect(h.dones, 1);
  });

  testWidgets('clearing the price empties the field', (tester) async {
    final h = await _pump(tester, price: '3.00');

    await _tap(tester, 'list-edit-price');
    expect(_key('list-edit-price-field'), findsOneWidget);
    await _tap(tester, 'list-edit-price-clear');
    expect(h.price.text, isEmpty);
    await _tap(tester, 'list-edit-back');
    expect(find.text('€3.00'), findsNothing);
  });

  testWidgets('note, photo and delete call back', (tester) async {
    final h = await _pump(tester);

    await _tap(tester, 'list-edit-note');
    await _tap(tester, 'list-edit-photo-add');
    await _tap(tester, 'list-edit-delete');
    expect((h.notes, h.adds, h.deletes), (1, 1, 1));
  });

  for (final dark in [false, true]) {
    testWidgets(
        'scrolls instead of overflowing at 320dp and 2x text '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await _pump(
        tester,
        quantity: '12.5',
        unit: 'bottle',
        price: '123.45',
        note: 'the big one from the shop on the corner',
        hasPhoto: true,
        width: 320,
        textScale: 2,
        theme: dark ? MitlistTheme.dark : MitlistTheme.light,
      );
      expect(tester.takeException(), isNull);

      await tester.dragUntilVisible(
        _key('list-edit-delete'),
        _key('list-edit-accessory-scroll'),
        const Offset(-120, 0),
      );
      expect(tester.takeException(), isNull);

      await _tap(tester, 'list-edit-price');
      expect(tester.takeException(), isNull);
      await _tap(tester, 'list-edit-back');
      await _tap(tester, 'list-edit-unit');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every control is labelled and at least 44dp', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, unit: 'kg', price: '2', hasPhoto: true, width: 1400);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(find.bySemanticsLabel('Unit: kg'), findsOneWidget);
    expect(find.bySemanticsLabel('Price: €2.00'), findsOneWidget);
    expect(find.byTooltip('Delete Flour'), findsOneWidget);
    expect(find.byTooltip('One more'), findsOneWidget);
    handle.dispose();
  });
}
