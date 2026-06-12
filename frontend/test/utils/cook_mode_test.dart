import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/cook_mode.dart';
import 'package:mitlist/models/recipe_models.dart';

void main() {
  // ---------------------------------------------------------------------------
  // cookScale
  // ---------------------------------------------------------------------------
  group('cookScale', () {
    test('base 0 returns 1.0', () {
      expect(cookScale(0, 4), 1.0);
    });

    test('base -1 returns 1.0', () {
      expect(cookScale(-1, 4), 1.0);
    });

    test('base 4, selected 4 returns 1.0', () {
      expect(cookScale(4, 4), 1.0);
    });

    test('base 4, selected 6 returns 1.5', () {
      expect(cookScale(4, 6), 1.5);
    });

    test('base 2, selected 1 returns 0.5', () {
      expect(cookScale(2, 1), 0.5);
    });
  });

  // ---------------------------------------------------------------------------
  // formatScaledQuantity
  // ---------------------------------------------------------------------------
  group('formatScaledQuantity', () {
    test('300 × 1.0 → "300"', () {
      expect(formatScaledQuantity(300, 1.0), '300');
    });

    test('300 × 1.5 → "450"', () {
      expect(formatScaledQuantity(300, 1.5), '450');
    });

    test('0.5 × 1 → "½"', () {
      expect(formatScaledQuantity(0.5, 1.0), '½');
    });

    test('1.25 × 1 → "1¼"', () {
      expect(formatScaledQuantity(1.25, 1.0), '1¼');
    });

    test('1.5 × 1 → "1½"', () {
      expect(formatScaledQuantity(1.5, 1.0), '1½');
    });

    test('1.75 × 1 → "1¾"', () {
      expect(formatScaledQuantity(1.75, 1.0), '1¾');
    });

    test('0.25 × 1 → "¼"', () {
      expect(formatScaledQuantity(0.25, 1.0), '¼');
    });

    test('0.75 × 1 → "¾"', () {
      expect(formatScaledQuantity(0.75, 1.0), '¾');
    });

    test('0.33 × 1 → "0.33"', () {
      expect(formatScaledQuantity(0.33, 1.0), '0.33');
    });

    test('trailing zeros stripped: 1.20 × 1 → "1.2"', () {
      expect(formatScaledQuantity(1.20, 1.0), '1.2');
    });

    test('trailing .00 stripped: 5.00 × 2 → "10"', () {
      expect(formatScaledQuantity(5.0, 2.0), '10');
    });

    test('2 × 0.5 → "1"', () {
      expect(formatScaledQuantity(2.0, 0.5), '1');
    });
  });

  // ---------------------------------------------------------------------------
  // parseStepDurations
  // ---------------------------------------------------------------------------
  group('parseStepDurations', () {
    test('simmer 10 min → 10 minutes', () {
      final result = parseStepDurations('simmer for 10 min');
      expect(result, [const Duration(minutes: 10)]);
    });

    test('bake 1 hour → 60 minutes', () {
      final result = parseStepDurations('bake for 1 hour');
      expect(result, [const Duration(hours: 1)]);
    });

    test('1 hr 30 min → 90 minutes', () {
      final result = parseStepDurations('cook for 1 hr 30 min');
      expect(result, [const Duration(minutes: 90)]);
    });

    test('1–2 hours → 60 minutes (lower bound)', () {
      final result = parseStepDurations('rest for 1–2 hours');
      expect(result, [const Duration(hours: 1)]);
    });

    test('90 seconds → 90 seconds', () {
      final result = parseStepDurations('blanch for 90 seconds');
      expect(result, [const Duration(seconds: 90)]);
    });

    test('no duration → empty list', () {
      final result = parseStepDurations('stir the mixture well');
      expect(result, isEmpty);
    });

    test('two durations in one step → two entries', () {
      final result =
          parseStepDurations('cook 10 minutes then rest 5 minutes');
      expect(result.length, 2);
      expect(result[0], const Duration(minutes: 10));
      expect(result[1], const Duration(minutes: 5));
    });

    test('case insensitive: 30 MIN', () {
      final result = parseStepDurations('wait 30 MIN');
      expect(result, [const Duration(minutes: 30)]);
    });

    test('1 hour 30 minutes combined → 90 minutes', () {
      final result = parseStepDurations('braise for 1 hour 30 minutes');
      expect(result, [const Duration(minutes: 90)]);
    });
  });

  // ---------------------------------------------------------------------------
  // matchIngredients
  // ---------------------------------------------------------------------------

  RecipeIngredient _ing(String id, String name,
          {double qty = 100, String unit = 'g'}) =>
      RecipeIngredient(
        id: id,
        recipeId: 'r1',
        name: name,
        quantity: qty,
        unit: unit,
        rawText: '',
      );

  group('matchIngredients', () {
    test('basic hit', () {
      final ings = [_ing('1', 'flour')];
      final matches = matchIngredients('Add the flour and stir.', ings);
      expect(matches.length, 1);
      expect(matches.first.ingredient.name, 'flour');
    });

    test('case-insensitive match', () {
      final ings = [_ing('1', 'Flour')];
      final matches = matchIngredients('Add the flour', ings);
      expect(matches.length, 1);
    });

    test('longest-first wins: "red onion" over "onion"', () {
      final ings = [_ing('1', 'onion'), _ing('2', 'red onion')];
      final matches =
          matchIngredients('Dice the red onion finely.', ings);
      expect(matches.length, 1);
      expect(matches.first.ingredient.name, 'red onion');
    });

    test('plural match: "eggs" matches ingredient "egg"', () {
      final ings = [_ing('1', 'egg')];
      final matches = matchIngredients('Beat the eggs well.', ings);
      expect(matches.length, 1);
    });

    test('no partial-word hit: "flour" must not match "flourish"', () {
      final ings = [_ing('1', 'flour')];
      final matches = matchIngredients('Let your creativity flourish.', ings);
      expect(matches, isEmpty);
    });

    test('each region matched once', () {
      final ings = [_ing('1', 'flour'), _ing('2', 'flour')];
      final matches =
          matchIngredients('Add flour and more flour.', ings);
      // Two occurrences, two matches (different positions).
      expect(matches.length, 2);
    });

    test('ingredients shorter than 3 chars skipped', () {
      final ings = [_ing('1', 'og')]; // 2 chars
      final matches = matchIngredients('Add og to the pot.', ings);
      expect(matches, isEmpty);
    });

    test('matches returned in order of start offset', () {
      final ings = [_ing('1', 'butter'), _ing('2', 'sugar')];
      final matches =
          matchIngredients('Mix the sugar and butter.', ings);
      expect(matches.length, 2);
      expect(matches[0].ingredient.name, 'sugar');
      expect(matches[1].ingredient.name, 'butter');
    });
  });
}
