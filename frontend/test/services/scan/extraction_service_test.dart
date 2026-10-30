import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/extraction_service.dart';
import 'package:mitlist/services/scan/scan_models.dart';

void main() {
  final extraction = ExtractionService();
  ParsedItem parse(String text, {double? confidence}) =>
      extraction.extract(OcrLine(text: text, confidence: confidence));

  group('list furniture', () {
    for (final (input, name) in [
      ('-banana', 'banana'),
      ('- banana', 'banana'),
      ('• Eier', 'Eier'),
      ('* Brot', 'Brot'),
      ('□ Butter', 'Butter'),
      ('[ ] Käse', 'Käse'),
      ('1) Milch', 'Milch'),
      ('2.Milch', 'Milch'),
    ]) {
      test('"$input" reads as "$name"', () {
        final item = parse(input);
        expect(item.itemName, name);
        expect(item.quantity, 1);
      });
    }

    test('layout numbering is not a quantity', () {
      final item = parse('3. Pringles');
      expect(item.itemName, 'Pringles');
      expect(item.quantity, 1);
    });

    test('a hyphenated name keeps its hyphen', () {
      expect(parse('WC-Ente').itemName, 'WC-Ente');
    });

    test('a dash-wrapped line is still crossed out', () {
      final item = parse('-milk-');
      expect(item.itemName, 'milk');
      expect(item.markStatus, MarkStatus.crossedOut);
    });
  });

  group('quantities', () {
    for (final (input, name, qty, unit) in [
      ('2 Milch', 'Milch', 2.0, ''),
      ('12 Eier', 'Eier', 12.0, ''),
      ('milk x2', 'milk', 2.0, ''),
      ('Milch 2x', 'Milch', 2.0, ''),
      ('Zwiebeln (3)', 'Zwiebeln', 3.0, ''),
      ('Eier 10', 'Eier', 10.0, ''),
      ('- 2 Milch', 'Milch', 2.0, ''),
      ('1,5l Wasser', 'Wasser', 1.5, 'l'),
      ('Tomaten 500g', 'Tomaten', 500.0, 'g'),
    ]) {
      test('"$input" → $qty $unit $name', () {
        final item = parse(input);
        expect(item.itemName, name);
        expect(item.quantity, qty);
        expect(item.unit, unit);
      });
    }

    test('a trailing number alone is not an item', () {
      expect(parse('12').itemName, '12');
    });
  });

  group('prices', () {
    test('a price is lifted out of the name', () {
      final item = parse('Butter 2,49€');
      expect(item.itemName, 'Butter');
      expect(item.priceCents, 249);
    });

    test('a date is not a price', () {
      expect(parse('10.12. Party').priceCents, isNull);
    });
  });

  test('carries the recognizer confidence', () {
    expect(parse('Milch', confidence: 0.42).ocrConfidence, 0.42);
  });

  group('GroceryPrediction list rule', () {
    GroceryPrediction prediction(
      ConfidenceLevel level, {
      bool confirmed = false,
    }) =>
        GroceryPrediction(
          id: 'p',
          rawText: '- Pringles',
          itemName: 'Pringles',
          displayName: 'Pork Kidneys',
          canonicalItemId: 'pork_kidneys',
          confidenceLevel: level,
          userConfirmed: confirmed,
        );

    test('an unconfirmed ask keeps what was written and no link', () {
      final p = prediction(ConfidenceLevel.ask);
      expect(p.listName, 'Pringles');
      expect(p.listCanonicalItemId, isNull);
    });

    test('a confirmed ask takes the chosen match', () {
      final p = prediction(ConfidenceLevel.ask, confirmed: true);
      expect(p.listName, 'Pork Kidneys');
      expect(p.listCanonicalItemId, 'pork_kidneys');
    });

    test('review and auto-accept add the shown match', () {
      for (final level in [
        ConfidenceLevel.review,
        ConfidenceLevel.autoAccept
      ]) {
        final p = prediction(level);
        expect(p.listName, 'Pork Kidneys');
        expect(p.listCanonicalItemId, 'pork_kidneys');
      }
    });
  });
}
