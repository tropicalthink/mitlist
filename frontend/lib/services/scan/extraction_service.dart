import 'scan_models.dart';

/// Parses qty / unit / price / item name from a raw OCR line.
/// Handles DE+EN grocery shorthand, metric units, and € prices.
class ExtractionService {
  static final _qtyPrefix = RegExp(
    r'^(\d+[,.]?\d*)\s*[xX×]?\s*',
  );

  static final _metricUnits = {
    'g', 'kg', 'ml', 'l', 'liter', 'ltr',
    'stück', 'stk', 'st', 'dose', 'pkg', 'pckg', 'pack',
    'flasche', 'fl', 'becher', 'beutel', 'pck',
    // English equivalents
    'oz', 'lb', 'lbs', 'pcs', 'piece', 'pieces',
    'bottle', 'can', 'jar', 'bag', 'box',
  };

  // e.g. "3.49", "€3,49", "3,49€", "$3.99" — but not a date like "10.12.".
  static final _pricePattern = RegExp(
    r'(?<![\d.,])(?:€|\$|EUR)?\s*(\d+)[,.](\d{2})(?![\d.,])\s*(?:€|EUR)?',
    caseSensitive: false,
  );

  // List furniture written before the item: bullets, dashes, check boxes.
  static final _leadingBullet = RegExp(
    r'^(?:[\-–—•·∙◦▪▫□☐■●○>+*~]+|\[\s?\]|\(\s?\))\s*',
  );

  // "1. Milch", "2) Eier": a layout number, not a quantity.
  static final _listNumber = RegExp(r'^\d{1,2}[.)]\s*(?=\D)');

  // Quantities written after the name: "milk x2", "Milch 2x", "Eier (10)",
  // "Eier 10".
  static final _qtySuffix = RegExp(
    r'\s+(?:[xX×]\s?(\d{1,3})|(\d{1,3})\s?[xX×]|\((\d{1,3})\)|(\d{1,2}))$',
  );

  static final _leadingPunctuation = RegExp(r'^[\s.,:;)\]\-–—]+');

  // Simple strikethrough heuristic: OCR sometimes renders struck-out text with
  // dashes or brackets around it, e.g. "-milk-", "[milk]", "~~milk~~".
  static final _crossedOutPattern = RegExp(
    r'^[\-~]+(.+?)[\-~]+$|^\[(.+?)\]$',
  );

  ParsedItem extract(OcrLine line) {
    var text = line.text.trim();

    // Crossed-out detection.
    final crossMatch = _crossedOutPattern.firstMatch(text);
    MarkStatus markStatus = line.markStatus;
    if (crossMatch != null) {
      text = (crossMatch.group(1) ?? crossMatch.group(2) ?? text).trim();
      markStatus = MarkStatus.crossedOut;
    }

    // Bullets and layout numbering carry no meaning, and a leading "-" or "•"
    // defeats every lookup keyed on the item's first character.
    text = text.replaceFirst(_leadingBullet, '');
    text = text.replaceFirst(_listNumber, '').trim();

    // Price extraction (strip from text before further parsing).
    int? priceCents;
    text = text.replaceAllMapped(_pricePattern, (m) {
      final euros = int.tryParse(m.group(1)!) ?? 0;
      final cents = int.tryParse(m.group(2)!) ?? 0;
      priceCents = euros * 100 + cents;
      return '';
    }).trim();

    // Quantity prefix: "2x ", "3 ", "500g" at start.
    double quantity = 1;
    String unit = '';

    final qtyMatch = _qtyPrefix.firstMatch(text);
    if (qtyMatch != null) {
      final raw = qtyMatch.group(1)!.replaceAll(',', '.');
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed > 0 && parsed < 1000) {
        quantity = parsed;
        text = text.substring(qtyMatch.end).trim();
      }
    }

    // Unit right after quantity or at the start of the remainder.
    if (text.isNotEmpty) {
      final parts = text.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        final candidate = parts.first.toLowerCase().replaceAll('.', '');
        if (_metricUnits.contains(candidate)) {
          unit = parts.first;
          text = parts.skip(1).join(' ').trim();
        }
      }
    }

    // Inline size like "500g" or "1,5l" attached to item name — extract unit
    // and scale quantity if needed.
    text = text.replaceAllMapped(
      RegExp(r'(\d+[,.]?\d*)\s*(g|kg|ml|l|oz|lb)\b', caseSensitive: false),
      (m) {
        if (unit.isEmpty) {
          quantity =
              double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? quantity;
          unit = m.group(2)!;
        }
        return '';
      },
    ).trim();

    if (quantity == 1 && unit.isEmpty) {
      final suffix = _qtySuffix.firstMatch(text);
      if (suffix != null) {
        final raw = suffix.group(1) ??
            suffix.group(2) ??
            suffix.group(3) ??
            suffix.group(4)!;
        final parsed = double.tryParse(raw);
        final remainder = text.substring(0, suffix.start).trim();
        if (parsed != null && parsed > 0 && remainder.isNotEmpty) {
          quantity = parsed;
          text = remainder;
        }
      }
    }

    text = text.replaceFirst(_leadingPunctuation, '').trim();
    final itemName = text.isEmpty ? line.text.trim() : text;

    return ParsedItem(
      rawText: line.text.trim(),
      itemName: itemName,
      bbox: line.bbox,
      quantity: quantity,
      unit: unit,
      priceCents: priceCents,
      markStatus: markStatus,
      ocrConfidence: line.confidence,
      alternatives: [
        for (final alternative in line.alternatives)
          OcrAlternative(
            text: extract(OcrLine(
              text: alternative.text,
              markStatus: line.markStatus,
            )).itemName,
            relativeScore: alternative.relativeScore,
          ),
      ],
    );
  }

  List<ParsedItem> extractAll(List<OcrLine> lines) =>
      lines.map(extract).where((p) => p.itemName.isNotEmpty).toList();
}
