// Pure-math tests for GroceryClassifierService.
//
// These tests exercise only the static helper functions (charTrigrams,
// buildTfidf) which have no native-lib or asset dependencies.  They use
// the synthetic fixture in test/support/grocery_classifier_fixture.json
// as reference data for the vocabulary and IDF weights.

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/grocery_classifier_service.dart';

void main() {
  // Fixture vocab/IDF matching test/support/grocery_classifier_fixture.json
  // vocab: ["", "[UNK]", "mil", "ilc", "lch"]
  // idf:   [0.0,  1.0,   2.0,  3.0,  4.0]
  const fixtureVocab = <String, int>{
    '': 0,
    '[UNK]': 1,
    'mil': 2,
    'ilc': 3,
    'lch': 4,
  };
  const fixtureIdf = [0.0, 1.0, 2.0, 3.0, 4.0];
  // strip_chars is Python string.punctuation — use an empty string for these
  // tests since none of the tokens contain punctuation.
  const fixtureStrip = '!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~';

  group('GroceryClassifierService.charTrigrams', () {
    test('milch → mil ilc lch', () {
      expect(
        GroceryClassifierService.charTrigrams('milch'),
        equals('mil ilc lch'),
      );
    });

    test('two-char input → returned as-is (no trigrams)', () {
      expect(GroceryClassifierService.charTrigrams('ab'), equals('ab'));
    });

    test('uppercased input is lowercased', () {
      final result = GroceryClassifierService.charTrigrams('AB CDE');
      expect(result, equals(result.toLowerCase()));
    });

    test('long input is truncated to maxLen-4', () {
      // Default maxLen=64; cut = first 60 chars.
      final longText = 'a' * 80;
      final trigrams = GroceryClassifierService.charTrigrams(longText);
      // Each trigram is 'aaa'; result is "aaa" joined by spaces.
      // Cut length = 60; trigrams = 60-2 = 58 items.
      final parts = trigrams.split(' ');
      expect(parts.length, equals(58));
    });
  });

  group('GroceryClassifierService.buildTfidf', () {
    test('mil ilc lch → correct TF-IDF values', () {
      final vec = GroceryClassifierService.buildTfidf(
        'mil ilc lch',
        vocabIndex: fixtureVocab,
        idf: fixtureIdf,
        stripChars: fixtureStrip,
      );
      // idx 0 ('') → count=0 * 0.0 = 0
      // idx 1 ('[UNK]') → count=0 * 1.0 = 0
      // idx 2 ('mil') → count=1 * 2.0 = 2.0
      // idx 3 ('ilc') → count=1 * 3.0 = 3.0
      // idx 4 ('lch') → count=1 * 4.0 = 4.0
      expect(vec.length, equals(5));
      expect(vec[0], closeTo(0.0, 1e-6));
      expect(vec[1], closeTo(0.0, 1e-6));
      expect(vec[2], closeTo(2.0, 1e-6));
      expect(vec[3], closeTo(3.0, 1e-6));
      expect(vec[4], closeTo(4.0, 1e-6));
    });

    test('repeated token doubles its count', () {
      // 'mil' appears twice → count=2; idx 2 = 2 * 2.0 = 4.0
      final vec = GroceryClassifierService.buildTfidf(
        'mil mil',
        vocabIndex: fixtureVocab,
        idf: fixtureIdf,
        stripChars: fixtureStrip,
      );
      expect(vec[2], closeTo(4.0, 1e-6));
    });

    test('OOV token maps to index 1', () {
      // 'zzz' is not in vocab → OOV → index 1; score = 1 * 1.0 = 1.0
      final vec = GroceryClassifierService.buildTfidf(
        'zzz',
        vocabIndex: fixtureVocab,
        idf: fixtureIdf,
        stripChars: fixtureStrip,
      );
      expect(vec[1], closeTo(1.0, 1e-6));
    });
  });
}
