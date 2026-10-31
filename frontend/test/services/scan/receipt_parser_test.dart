import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/receipt_parser.dart';
import 'package:mitlist/services/scan/scan_models.dart';

/// What the on-device OCR read from a Commons receipt photo
/// (`samples/receipts/`, regenerated when the OCR changes).
List<OcrLine> _ocrFixture(String id) {
  final json = jsonDecode(
    File('test/fixtures/receipts/$id.ocr.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final line in (json['lines'] as List).cast<Map<String, dynamic>>())
      OcrLine(
        text: line['text'] as String,
        confidence: (line['confidence'] as num?)?.toDouble(),
        bbox: () {
          final b = (line['bbox'] as List).cast<num>();
          return OcrBBox(
            b[0].toDouble(),
            b[1].toDouble(),
            b[2].toDouble(),
            b[3].toDouble(),
          );
        }(),
      ),
  ];
}

String _norm(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

OcrLine _line(String text, double left, double top, {double height = 40}) =>
    OcrLine(
      text: text,
      bbox: OcrBBox(left, top, text.length * 20.0, height),
    );

void main() {
  const parser = ReceiptParser();
  final now = DateTime(2026, 10, 31);

  group('Commons receipts', () {
    final manifest = jsonDecode(
      File('test/fixtures/receipts/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final receipts =
        (manifest['receipts'] as List).cast<Map<String, dynamic>>();

    var exactItems = 0;
    var expectedItems = 0;
    var balanced = 0;

    for (final receipt in receipts) {
      final id = receipt['id'] as String;
      test(id, () {
        final reading = parser.parse(_ocrFixture(id), now: now);

        expect(reading.totalCents, receipt['total'], reason: 'total');
        expect(reading.store, receipt['store'], reason: 'store');
        final date = receipt['date'] as String?;
        expect(
          reading.date,
          date == null ? isNull : DateTime.parse(date),
          reason: 'date',
        );

        final expected = [
          for (final item in (receipt['items'] as List).cast<List>())
            '${_norm(item[0] as String)} ${item[1]}',
        ];
        final read = [
          for (final item in reading.items)
            '${_norm(item.name)} ${item.amountCents}',
        ];
        final unmatched = [...read];
        var exact = 0;
        for (final item in expected) {
          if (unmatched.remove(item)) exact++;
        }
        exactItems += exact;
        expectedItems += expected.length;
        if (reading.itemsMatchTotal) balanced++;
        // ignore: avoid_print
        print('$id: $exact/${expected.length} items exact, '
            '${reading.itemsMatchTotal ? 'adds up' : 'does not add up'}'
            '${unmatched.isEmpty ? '' : ', extra: $unmatched'}');

        // A receipt whose lines add up was read completely; one that does
        // not is shown to the person as such.
        if (reading.itemsMatchTotal) {
          expect(exact, expected.length, reason: 'balanced but wrong items');
        }
      });
    }

    tearDownAll(() {
      // ignore: avoid_print
      print('receipts: $exactItems/$expectedItems items exact, '
          '$balanced/${receipts.length} add up to their total');
      // Tesco 1994 has a faded price and a misread 0.85, so it cannot
      // balance; every other receipt is read line for line.
      expect(balanced, greaterThanOrEqualTo(receipts.length - 1));
      expect(exactItems, greaterThanOrEqualTo(expectedItems - 3));
    });
  });

  test('a multi-buy line above an item is not an item', () {
    final reading = parser.parse([
      _line('Müsli Riegel', 0, 100),
      _line('0.99', 600, 100),
      _line('4 x', 0, 150),
      _line('1.29', 300, 150),
      _line('Direktsaft Premium', 0, 200),
      _line('5.16', 600, 200),
      _line('Summe', 0, 300),
      _line('6.15', 600, 300),
    ], now: now);
    expect(reading.items.map((i) => i.name),
        ['Müsli Riegel', 'Direktsaft Premium']);
    expect(reading.itemsMatchTotal, isTrue);
  });

  test('a weight line below a name prices that name', () {
    final reading = parser.parse([
      _line('BANANA CAVENDISH', 0, 100),
      _line('0.572 kg NET @ \$2.50/kg', 20, 150),
      _line('1.43', 600, 150),
      _line('TOTAL', 0, 250),
      _line('1.43', 600, 250),
    ], now: now);
    expect(reading.items.single.name, 'BANANA CAVENDISH');
    expect(reading.items.single.amountCents, 143);
    expect(reading.totalCents, 143);
  });

  test('deposits and discounts are money but not products', () {
    final reading = parser.parse([
      _line('Apfelschorle', 0, 100),
      _line('1.39 B', 600, 100),
      _line('Pfand 6 x 0,25 EUR', 0, 150),
      _line('1.50 B', 600, 150),
      _line('PANCAKE OFFER', 0, 200),
      _line('-0.50', 600, 200),
      _line('zu zahlen', 0, 300),
      _line('2,39', 600, 300),
    ], now: now);
    expect(
        [for (final i in reading.items) i.isAdjustment], [false, true, true]);
    expect(reading.totalCents, 239);
    expect(reading.itemsMatchTotal, isTrue);
  });

  test('dates: dotted is day first, slashed follows the locale', () {
    ReceiptReading read(String text, {bool monthFirst = false}) =>
        parser.parse([OcrLine(text: text)], now: now, monthFirst: monthFirst);
    expect(read('18.12.06 17:12').date, DateTime(2006, 12, 18));
    expect(read('10/23/10').date, DateTime(2010, 10, 23));
    expect(read('19/04/94').date, DateTime(1994, 4, 19));
    expect(read('03/04/2025').date, DateTime(2025, 4, 3));
    expect(read('03/04/2025', monthFirst: true).date, DateTime(2025, 3, 4));
    expect(read('2026-10-30').date, DateTime(2026, 10, 30));
    // A two-digit year ahead of today is last century; a full one is a
    // misread. A phone number is not a date.
    expect(read('12.12.27').date, DateTime(1927, 12, 12));
    expect(read('12.12.2027').date, isNull);
    expect(read('831-373-7381').date, isNull);
  });

  test('nothing priced reads as empty', () {
    final reading = parser.parse([
      const OcrLine(text: 'Milch'),
      const OcrLine(text: 'Brot'),
    ], now: now);
    expect(reading.totalCents, isNull);
    expect(reading.amountCents, isNull);
  });
}
