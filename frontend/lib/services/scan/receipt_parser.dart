import 'dart:math' as math;

import 'scan_models.dart';

/// One priced line of a receipt.
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.amountCents,
    this.isAdjustment = false,
  });

  /// The name as printed ("MLD WHT CHDR", "Apfelschorle").
  final String name;

  /// Negative for a discount.
  final int amountCents;

  /// A deposit, discount or coupon: money on the receipt, not a product.
  final bool isAdjustment;

  @override
  String toString() => '$name ${amountCents / 100}';
}

/// What a receipt photo says, as far as it could be read.
class ReceiptReading {
  const ReceiptReading({
    this.store,
    this.date,
    this.totalCents,
    this.items = const [],
  });

  /// A known chain named on the receipt, null when none was recognised.
  final String? store;
  final DateTime? date;

  /// The printed total ("Summe", "TOTAL", "zu zahlen").
  final int? totalCents;
  final List<ReceiptItem> items;

  int get itemsCents => items.fold(0, (sum, item) => sum + item.amountCents);

  /// True when the item lines add up to the printed total: every line was
  /// found and every price read right.
  bool get itemsMatchTotal =>
      totalCents != null && items.isNotEmpty && itemsCents == totalCents;

  /// What the receipt cost: the printed total, else the sum of its lines.
  int? get amountCents => totalCents ?? (items.isEmpty ? null : itemsCents);

  bool get isEmpty => totalCents == null && items.isEmpty && store == null;
}

/// Turns the lines OCR read from a till receipt into a store, a date, a total
/// and priced items.
///
/// A receipt is a table even when OCR returns it as loose boxes: the name on
/// the left, the price in a right-hand column, sometimes a tax column between.
/// Rows are rebuilt from box positions, and a price only counts when it sits
/// in the price column, so the "1.29" in "4 x 1.29" or the "0,22" in
/// "6 × 0,22" is never taken for an item. Weight and multi-buy lines
/// ("0.217 kg NET @ \$3.90/kg", "REDUCED PRICE") give their price to the
/// name printed above them.
/// How far apart, in box heights, two boxes' centres may be and still sit on
/// one printed row.
const double kReceiptRowTolerance = 0.5;

class ReceiptParser {
  const ReceiptParser();

  ReceiptReading parse(
    List<OcrLine> lines, {
    DateTime? now,
    bool monthFirst = false,
  }) {
    final rows = _rows(lines);
    if (rows.isEmpty) return const ReceiptReading();

    final priceColumn = _priceColumn(rows);
    _Money? columnPrice(_Row row) {
      final price = row.price;
      if (price == null) return null;
      if (priceColumn == null || row.priceRight == null) return price;
      return (row.priceRight! - priceColumn.right).abs() <=
              priceColumn.tolerance
          ? price
          : null;
    }

    // The total, and with it the end of the item lines.
    int? totalIndex;
    int? subtotalIndex;
    for (var i = 0; i < rows.length; i++) {
      if (columnPrice(rows[i]) == null) continue;
      final label = _compact(rows[i].label);
      if (totalIndex == null && _totalLabels.contains(label)) totalIndex = i;
      if (subtotalIndex == null && _subtotalLabels.contains(label)) {
        subtotalIndex = i;
      }
    }
    final totalRow = totalIndex ?? subtotalIndex;
    final itemsEnd = [totalIndex, subtotalIndex]
        .whereType<int>()
        .fold<int>(rows.length, math.min);

    final items = <ReceiptItem>[];
    String? pending;
    for (var i = 0; i < itemsEnd; i++) {
      final row = rows[i];
      final price = columnPrice(row);
      final label = _cleanLabel(row.label);
      final qualifier = _isQualifier(row.label);
      if (price == null) {
        if (!qualifier && _letters(label) >= 3) pending = label;
        continue;
      }
      if (qualifier || label.isEmpty || _isPriceModifier(label)) {
        // A weight, multi-buy or reduction line prices the name above it.
        if (pending != null) {
          items.add(_item(pending, price.cents));
        }
        pending = null;
        continue;
      }
      pending = null;
      if (_letters(label) < 2) continue;
      items.add(_item(label, price.cents));
    }

    return ReceiptReading(
      store: _store(rows, headerEnd: _firstItemRow(rows, columnPrice)),
      date: _date(rows, now: now ?? DateTime.now(), monthFirst: monthFirst),
      totalCents: totalRow == null ? null : columnPrice(rows[totalRow])!.cents,
      items: items,
    );
  }

  static ReceiptItem _item(String name, int cents) => ReceiptItem(
        name: name,
        amountCents: cents,
        isAdjustment: cents < 0 || _isAdjustmentLabel(name),
      );

  // ---------------------------------------------------------------- rows ---

  static List<_Row> _rows(List<OcrLine> lines) {
    if (!lines.every((line) => line.bbox != null)) {
      return [
        for (final line in lines)
          if (line.text.trim().isNotEmpty) _Row()..add(line),
      ];
    }
    final sorted = [...lines]
      ..sort((a, b) => _centerY(a.bbox!).compareTo(_centerY(b.bbox!)));
    // Boxes of one printed row share a centre line, though the price box is
    // often a few pixels higher or lower than the name.
    final groups = <List<OcrLine>>[];
    for (final line in sorted) {
      final box = line.bbox!;
      List<OcrLine>? target;
      var best = double.infinity;
      for (final group in groups.reversed.take(3)) {
        final distance = (_centerY(box) - _meanCenter(group)).abs();
        final limit = kReceiptRowTolerance *
            group.map((l) => l.bbox!.height).fold(box.height, math.min);
        if (distance <= limit && distance < best) {
          best = distance;
          target = group;
        }
      }
      (target ?? (groups..add(<OcrLine>[])).last).add(line);
    }
    // A box first grouped with the row above can sit nearer the row below
    // once that row exists ("PRODUCE-GARDEN" / "3.99 F" / "APPLES FUJI"):
    // move it to the row whose other boxes it is closest to.
    for (var i = 0; i < groups.length; i++) {
      for (final line in [...groups[i]]) {
        if (groups[i].length < 2) break;
        final center = _centerY(line.bbox!);
        final rest = [...groups[i]]..remove(line);
        var distance = (center - _meanCenter(rest)).abs();
        List<OcrLine>? better;
        for (final j in [i - 1, i + 1]) {
          if (j < 0 || j >= groups.length || groups[j].isEmpty) continue;
          final other = (center - _meanCenter(groups[j])).abs();
          if (other < distance &&
              other <=
                  kReceiptRowTolerance *
                      math.min(
                          line.bbox!.height,
                          groups[j]
                              .map((l) => l.bbox!.height)
                              .reduce(math.min))) {
            distance = other;
            better = groups[j];
          }
        }
        if (better != null) {
          groups[i].remove(line);
          better.add(line);
        }
      }
    }
    return [
      for (final group in groups)
        if (group.isNotEmpty) _Row()..addAll(group),
    ].where((row) => row.text.isNotEmpty).toList();
  }

  static double _meanCenter(List<OcrLine> group) =>
      group.map((l) => _centerY(l.bbox!)).reduce((a, b) => a + b) /
      group.length;

  static double _centerY(OcrBBox box) => box.top + box.height / 2;

  /// The right edge prices line up on, from the rows that carry one.
  static _PriceColumn? _priceColumn(List<_Row> rows) {
    final rights = <double>[
      for (final row in rows)
        if (row.priceRight != null) row.priceRight!,
    ]..sort();
    final heights = <double>[
      for (final row in rows)
        if (row.minHeight.isFinite) row.minHeight,
    ]..sort();
    if (rights.length < 2 || heights.isEmpty) return null;
    return _PriceColumn(
      rights[rights.length ~/ 2],
      2.5 * heights[heights.length ~/ 2],
    );
  }

  static int _firstItemRow(List<_Row> rows, _Money? Function(_Row) price) {
    for (var i = 0; i < rows.length; i++) {
      if (price(rows[i]) != null && _letters(_cleanLabel(rows[i].label)) >= 2) {
        return i;
      }
    }
    return rows.length;
  }

  // --------------------------------------------------------------- money ---

  /// A price at the end of a row: "1.39 B", "\$16.48", "-1.98", "2,85",
  /// "1.234,56". A tax rate ("22,00%") is not a price.
  static final RegExp _trailingPrice = RegExp(
    r'(?:^|[\s:])(-?)\s?[$€£]?\s?(-?)(\d{1,3}(?:[.,]\d{3})*|\d+)[.,](\d{2})'
    r'(?:\s?(?:€|EUR|eur))?(?:\s?[A-Z]{1,2}\*?|\s?\*)?$',
  );

  static _Money? _priceIn(String text) {
    final match = _trailingPrice.firstMatch(text.trim());
    if (match == null) return null;
    final whole = int.parse(match.group(3)!.replaceAll(RegExp(r'[.,]'), ''));
    final cents = whole * 100 + int.parse(match.group(4)!);
    final negative = match.group(1)!.isNotEmpty || match.group(2)!.isNotEmpty;
    return _Money(negative ? -cents : cents, match.start);
  }

  // -------------------------------------------------------------- labels ---

  static final RegExp _percent = RegExp(r'\d{1,2}(?:[.,]\d{1,2})?\s?%');

  static String _cleanLabel(String label) => label
      .replaceAll(_percent, ' ')
      .replaceAll(RegExp(r'^[\s*#]+|[\s*#]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// "4 x 1.29", "2x 0,49", "6 × 0,22", "0.217 kg NET @ \$3.90/kg",
  /// "0,5484kg × E 2,79/kg": how the line above was priced.
  static bool _isQualifier(String label) =>
      label.contains('@') ||
      RegExp(r'/\s?(?:kg|lb|100\s?g|l)\b', caseSensitive: false)
          .hasMatch(label) ||
      RegExp(
        r'^\s*\d+(?:[.,]\d+)?\s*(?:kg|g|lb|st|stk|pcs|pc)?\s*[x×*]\s*(?:[\d€$£E]|$)',
        caseSensitive: false,
      ).hasMatch(label);

  static const _priceModifiers = {
    'reducedprice',
    'pricereduced',
    'preisreduziert',
    'reduziert',
    'prezzoridotto',
    'prixreduit',
  };

  static bool _isPriceModifier(String label) =>
      _priceModifiers.contains(_compact(label));

  static const _adjustmentWords = [
    'pfand',
    'leergut',
    'deposit',
    'statiegeld',
    'rabatt',
    'discount',
    'coupon',
    'offer',
    'sconto',
    'remise',
    'korting',
    'savings',
    'preisvorteil',
  ];

  static bool _isAdjustmentLabel(String label) {
    final compact = _compact(label);
    return _adjustmentWords.any(compact.contains);
  }

  static const _totalLabels = {
    'summe',
    'total',
    'totale',
    'totalecomplessivo',
    'zuzahlen',
    'gesamt',
    'gesamtsumme',
    'gesamtbetrag',
    'endsumme',
    'totaal',
    'tebetalen',
    'montant',
    'totalttc',
    'totalapagar',
    'importetotal',
    'grandtotal',
    'amountdue',
    'balancedue',
    'totaldue',
    'totaleur',
    'summeeur',
    'totaleuro',
    'summeeuro',
  };

  static const _subtotalLabels = {
    'subtotal',
    'zwischensumme',
    'subtotale',
    'soustotal',
    'subtotaal',
  };

  /// Letters only, lower case: "S u m m e" and "6 SUBTOTAL" compare as
  /// "summe" and "subtotal".
  static String _compact(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');

  static int _letters(String text) =>
      RegExp(r'\p{L}', unicode: true).allMatches(text).length;

  // --------------------------------------------------------------- store ---

  static const _chains = <String, String>{
    'aldi': 'ALDI',
    'lidl': 'Lidl',
    'rewe': 'REWE',
    'edeka': 'EDEKA',
    'penny': 'PENNY',
    'netto': 'Netto',
    'kaufland': 'Kaufland',
    'norma': 'NORMA',
    'globus': 'Globus',
    'tegut': 'tegut',
    'rossmann': 'Rossmann',
    'tesco': 'Tesco',
    'sainsburys': "Sainsbury's",
    'asda': 'Asda',
    'morrisons': 'Morrisons',
    'waitrose': 'Waitrose',
    'iceland': 'Iceland',
    'woolworths': 'Woolworths',
    'coles': 'Coles',
    'safeway': 'Safeway',
    'kroger': 'Kroger',
    'walmart': 'Walmart',
    'target': 'Target',
    'costco': 'Costco',
    'wholefoods': 'Whole Foods',
    'traderjoes': "Trader Joe's",
    'savemart': 'Save Mart',
    'publix': 'Publix',
    'albertheijn': 'Albert Heijn',
    'jumbo': 'Jumbo',
    'carrefour': 'Carrefour',
    'auchan': 'Auchan',
    'leclerc': 'E.Leclerc',
    'intermarche': 'Intermarché',
    'monoprix': 'Monoprix',
    'esselunga': 'Esselunga',
    'conad': 'Conad',
    'mercadona': 'Mercadona',
    'migros': 'Migros',
    'billa': 'BILLA',
    'spar': 'SPAR',
    'coop': 'Coop',
    'hofer': 'HOFER',
    'delhaize': 'Delhaize',
    'colruyt': 'Colruyt',
  };

  /// A known chain named on the receipt. Logos come out of OCR mangled
  /// ("L+DL"), so the header, above the first item, also accepts a name one
  /// letter off; below it only an exact name counts ("FOR SHOPPING AT
  /// TESCO").
  static String? _store(List<_Row> rows, {required int headerEnd}) {
    for (var i = 0; i < rows.length; i++) {
      final header = i < headerEnd;
      final compactRow = _compact(rows[i].text);
      for (final entry in _chains.entries) {
        if (compactRow == entry.key) return entry.value;
      }
      for (final word in rows[i].text.split(RegExp(r'\s+'))) {
        final compact = _compact(word);
        if (compact.isEmpty) continue;
        for (final entry in _chains.entries) {
          if (compact == entry.key) return entry.value;
          if (header &&
              entry.key.length >= 4 &&
              compact.length >= 3 &&
              (compact.length - entry.key.length).abs() <= 1 &&
              _editDistance(compact, entry.key) <= 1) {
            return entry.value;
          }
        }
      }
    }
    return null;
  }

  static int _editDistance(String a, String b) {
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
      }
      previous = current;
    }
    return previous[b.length];
  }

  // ---------------------------------------------------------------- date ---

  static final RegExp _isoDate =
      RegExp(r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)');
  static final RegExp _shortDate = RegExp(
      r'(?<![\d/.-])(\d{1,2})([./-])(\d{1,2})\2(\d{4}|\d{2})(?![\d/.-])');

  /// The first plausible date on the receipt. Dotted dates are day first;
  /// a slashed one is month first when its second part cannot be a month,
  /// or when [monthFirst] says this is how dates are written here.
  static DateTime? _date(
    List<_Row> rows, {
    required DateTime now,
    required bool monthFirst,
  }) {
    final latest = now.add(const Duration(days: 1));
    for (final row in rows) {
      for (final match in _isoDate.allMatches(row.text)) {
        final date = _validDate(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
        if (date != null && !date.isAfter(latest)) return date;
      }
      for (final match in _shortDate.allMatches(row.text)) {
        final first = int.parse(match.group(1)!);
        final second = int.parse(match.group(3)!);
        final separator = match.group(2)!;
        final yearText = match.group(4)!;
        var year = int.parse(yearText);
        if (yearText.length == 2) {
          year += 2000;
          if (DateTime(year).isAfter(latest)) year -= 100;
        }
        final bool isMonthFirst;
        if (separator == '.') {
          isMonthFirst = false;
        } else if (second > 12) {
          isMonthFirst = true;
        } else if (first > 12) {
          isMonthFirst = false;
        } else {
          isMonthFirst = monthFirst;
        }
        final date = isMonthFirst
            ? _validDate(year, first, second)
            : _validDate(year, second, first);
        if (date != null && !date.isAfter(latest)) return date;
      }
    }
    return null;
  }

  static DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    return date.month == month ? date : null;
  }
}

class _Money {
  const _Money(this.cents, this.start);
  final int cents;

  /// Where the price starts in the text it was found in.
  final int start;
}

class _PriceColumn {
  const _PriceColumn(this.right, this.tolerance);
  final double right;
  final double tolerance;
}

/// One printed row: the boxes OCR returned for it, left to right.
class _Row {
  final List<OcrLine> _lines = [];
  double _centerSum = 0;
  int _boxed = 0;

  double minHeight = double.infinity;

  double get centerY => _boxed == 0 ? 0 : _centerSum / _boxed;

  void add(OcrLine line) {
    _lines.add(line);
    final box = line.bbox;
    if (box != null) {
      _centerSum += box.top + box.height / 2;
      _boxed++;
      minHeight = math.min(minHeight, box.height);
      _lines.sort((a, b) => (a.bbox?.left ?? 0).compareTo(b.bbox?.left ?? 0));
    }
    _parsed = false;
  }

  void addAll(Iterable<OcrLine> lines) => lines.forEach(add);

  String get text => _lines.map((line) => line.text.trim()).join(' ').trim();

  bool _parsed = false;
  _Money? _price;
  double? _priceRight;
  String _label = '';

  /// The price at the end of the row, if any.
  _Money? get price {
    _parse();
    return _price;
  }

  /// The right edge of the box the price was read from.
  double? get priceRight {
    _parse();
    return _priceRight;
  }

  /// The row without its price.
  String get label {
    _parse();
    return _label;
  }

  void _parse() {
    if (_parsed) return;
    _parsed = true;
    // The price is the last box, or the one before a lone tax code ("B").
    var index = _lines.length - 1;
    while (index > 0 && _taxCode.hasMatch(_lines[index].text.trim())) {
      index--;
    }
    final last = index < 0 ? null : _lines[index];
    final price = last == null ? null : ReceiptParser._priceIn(last.text);
    if (last == null || price == null) {
      _label = text;
      return;
    }
    _price = price;
    final box = last.bbox;
    _priceRight = box == null ? null : box.left + box.width;
    _label = [
      for (final line in _lines.take(index)) line.text.trim(),
      last.text.substring(0, price.start).trim(),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  static final RegExp _taxCode = RegExp(r'^[A-Z]{1,2}\*?$|^\*$');
}
