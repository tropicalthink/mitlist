import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/recipe_text_parser.dart';
import 'package:mitlist/services/scan/scan_models.dart';

/// What the on-device OCR read from a Commons recipe photo (see
/// `samples/recipes/ATTRIBUTION.md`).
List<OcrLine> _ocrFixture(String id) {
  final json = jsonDecode(
    File('test/fixtures/recipes/$id.ocr.json').readAsStringSync(),
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

void main() {
  const parser = RecipeTextParser();

  test('a typed recipe card: title, ingredients, then method', () {
    final draft = parser.parse(_ocrFixture('lemon_sponge_card'));
    expect(draft.title, 'LEMON SPONGE CAKE');
    expect(draft.ingredients, [
      '2 t butter',
      '1 c sugar',
      '3 eggs -seperated',
      '1/4 c flour',
      'Pinch salt',
      'Rind of 1 lemon',
      '5 T fresh lemon juice',
      '1 c milk', // the card says 1½; OCR lost the ½
    ]);
    expect(
        draft.steps.first,
        'Cream butter and sugar, add 3 egg yolks, flour, salt, lemon rind '
        'and juice, and 1/2 c milk.');
  });

  test('two ingredient columns read column by column', () {
    final draft = parser.parse(_ocrFixture('pedernales_chili_card'));
    // Not the stamp above it, not the byline below it.
    expect(draft.title, 'Pedernales River Chili');
    expect(draft.ingredients, [
      '4 lbs. chili meat',
      '1 large onion',
      '2 cloves garlic',
      'tsp, ground oregano',
      'tsp. comino seed',
      '6 tsps. chili powder —more if needed',
      '2 cans Ro-tel tomatoes',
      'Salt to taste',
      '2 cups of hot water',
    ]);
    // The method, a sentence per step; "NOCHE SPECIALS" is another recipe.
    expect(draft.steps, [
      'Put chili meat, onions and garlic in large heavy boiler or skillet.',
      'Sear until light colored.',
      'Add oregano, comino, chili powder, tomatoes and hot water.',
      'Bring to a boil, lower heat and simmer about one hour.',
      'As fat cooks out—skim.',
    ]);
  });

  test('a cookbook page: fractions repaired, the second recipe left out', () {
    final draft = parser.parse(_ocrFixture('rumford_apricot_page'));
    expect(draft.title, 'Apricot Bavarian');
    expect(draft.ingredients, [
      '1 pint milk',
      '2 eggs',
      '1/2 cup sugar',
      '1 1/2 tablespoons granulated gelatine',
      '1/2 cup cold water',
      '1 cup apricot pulp',
      '1 teaspoon lemon extract',
      '1/2 cup cream',
    ]);
    expect(draft.steps, hasLength(4));
    expect(draft.steps.first, startsWith('Scald the milk'));
    expect(
        draft.steps.last,
        'Turn into a mold previously dipped into cold water; chill, unmold '
        'and serve plain or with additional fruit.');
  });

  test('a handwritten card still gives a draft to correct', () {
    final draft = parser.parse(_ocrFixture('pound_cake_handwritten'));
    expect(draft.isEmpty, isFalse);
    expect(draft.title, isNotNull);
  });

  test('headings and numbered steps are followed', () {
    final draft = parser.parse([
      const OcrLine(text: 'Pfannkuchen'),
      const OcrLine(text: 'Zutaten für 4 Personen:'),
      const OcrLine(text: '250 g Mehl'),
      const OcrLine(text: '3 Eier'),
      const OcrLine(text: 'Salz'),
      const OcrLine(text: 'Zubereitung'),
      const OcrLine(text: '1. Mehl und Eier verrühren.'),
      const OcrLine(text: '2. In der Pfanne'),
      const OcrLine(text: 'goldbraun backen.'),
    ]);
    expect(draft.title, 'Pfannkuchen');
    expect(draft.ingredients, ['250 g Mehl', '3 Eier', 'Salz']);
    expect(draft.steps,
        ['Mehl und Eier verrühren.', 'In der Pfanne goldbraun backen.']);
  });

  test('without amounts the first line is the title', () {
    final draft = parser.parse([
      const OcrLine(text: 'Green salad'),
      const OcrLine(text: 'Lettuce'),
      const OcrLine(text: 'Olive oil'),
      const OcrLine(text: 'Toss the leaves with the oil and a pinch of salt.'),
    ]);
    expect(draft.title, 'Green salad');
    expect(draft.ingredients, ['Lettuce', 'Olive oil']);
    expect(draft.steps, hasLength(1));
  });

  test('fraction repairs leave real quantities alone', () {
    List<String> read(String line) => parser
        .parse([const OcrLine(text: 'Cake'), OcrLine(text: line)]).ingredients;
    expect(read('11/2 teaspoons baking powder'),
        ['1 1/2 teaspoons baking powder']);
    expect(read('12 cup milk'), ['1/2 cup milk']);
    expect(read('12 cups flour'), ['12 cups flour']);
    expect(read('12 eggs'), ['12 eggs']);
  });
}
