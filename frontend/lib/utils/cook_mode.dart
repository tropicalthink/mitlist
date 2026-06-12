import '../models/recipe_models.dart';

/// A match between a substring of a step's text and a recipe ingredient.
class IngredientMatch {
  /// The matched ingredient.
  final RecipeIngredient ingredient;

  /// Start byte offset in the original step text.
  final int start;

  /// End byte offset (exclusive) in the original step text.
  final int end;

  const IngredientMatch({
    required this.ingredient,
    required this.start,
    required this.end,
  });
}

/// Returns the scale factor: [selectedServings] / [baseServings].
///
/// Guards against [baseServings] < 1 by returning 1.0 (no scaling).
double cookScale(int baseServings, int selectedServings) {
  if (baseServings < 1) return 1.0;
  return selectedServings / baseServings;
}

/// Formats a scaled quantity for display.
///
/// Rules:
///  - Multiply [quantity] by [scale].
///  - Round to 2 decimal places, strip trailing zeros.
///  - Exact fractional parts of .5 → ½, .25 → ¼, .75 → ¾.
String formatScaledQuantity(double quantity, double scale) {
  final scaled = quantity * scale;

  final intPart = scaled.truncate();
  final frac = scaled - intPart;

  // Check for exact vulgar fractions.
  const epsilon = 1e-9;
  String? fracSymbol;
  if ((frac - 0.5).abs() < epsilon) {
    fracSymbol = '½';
  } else if ((frac - 0.25).abs() < epsilon) {
    fracSymbol = '¼';
  } else if ((frac - 0.75).abs() < epsilon) {
    fracSymbol = '¾';
  }

  if (fracSymbol != null) {
    if (intPart == 0) return fracSymbol;
    return '$intPart$fracSymbol';
  }

  // Round to 2dp, strip trailing zeros.
  String s = scaled.toStringAsFixed(2);
  // Strip trailing zeros after decimal point.
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// Parses time durations from step text.
///
/// Handles:
///  - `10 min` / `10 minutes` / `10 mins`
///  - `1 hour` / `1 hours` / `1 hr` / `1 hrs`
///  - `90 seconds` / `90 second` / `90 sec`
///  - `1 hr 30 min` → Duration(minutes: 90)
///  - `1–2 hours` → 1 hour (lower bound of range)
///
/// Adjacent hour+minute pairs (e.g. "1 hour 30 minutes") are combined into
/// one Duration. Returns all Durations found in [text].
List<Duration> parseStepDurations(String text) {
  // Normalise en-dash/em-dash ranges: "1–2 hours" → we want lower bound
  // Replace "N–M" or "N-M" range prefix with just N
  final normalised = text
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('−', '-');

  // Tokenise: find number (possibly ranged) followed by unit word.
  // Regex captures: optional leading range lower bound (we keep the first number).
  final tokenRe = RegExp(
    r'(\d+(?:\.\d+)?)'         // number (group 1)
    r'(?:\s*-\s*\d+(?:\.\d+)?)?'  // optional upper bound of range (ignored)
    r'\s+'
    r'(hours?|hrs?|minutes?|mins?|seconds?|secs?)',
    caseSensitive: false,
  );

  final tokens = tokenRe.allMatches(normalised).toList();

  final result = <Duration>[];
  int i = 0;
  while (i < tokens.length) {
    final match = tokens[i];
    final value = double.parse(match.group(1)!);
    final unit = match.group(2)!.toLowerCase();

    Duration dur;
    if (unit.startsWith('hour') || unit.startsWith('hr')) {
      dur = Duration(minutes: (value * 60).round());

      // Look ahead: is the very next token a minute unit and immediately
      // following in the string (no unrelated text between)?
      if (i + 1 < tokens.length) {
        final next = tokens[i + 1];
        final gap = normalised.substring(match.end, next.start).trim();
        final nextUnit = next.group(2)!.toLowerCase();
        final isMinute = nextUnit.startsWith('min') || nextUnit.startsWith('sec');
        // Only combine if there is only whitespace between the two tokens.
        if (gap.isEmpty && isMinute) {
          final nextValue = double.parse(next.group(1)!);
          if (nextUnit.startsWith('min')) {
            dur = Duration(minutes: (value * 60).round() + nextValue.round());
          } else {
            dur = Duration(
                minutes: (value * 60).round(),
                seconds: nextValue.round());
          }
          i += 2;
          result.add(dur);
          continue;
        }
      }
      result.add(dur);
    } else if (unit.startsWith('min')) {
      dur = Duration(minutes: value.round());
      result.add(dur);
    } else {
      // seconds
      dur = Duration(seconds: value.round());
      result.add(dur);
    }
    i++;
  }

  return result;
}

/// Returns matches of ingredient names within [stepText].
///
/// Rules:
///  - Case-insensitive.
///  - Whole-word match only (word boundaries).
///  - Ingredients with names shorter than 3 characters are skipped.
///  - `name` and `name + 's'` are matched (cheap plural).
///  - Longest name wins when multiple ingredients overlap.
///  - Each text region is matched at most once.
List<IngredientMatch> matchIngredients(
    String stepText, List<RecipeIngredient> ingredients) {
  // Filter out short names.
  final eligible = ingredients.where((ing) => ing.name.length >= 3).toList();

  // Sort by name length descending (longest first) so longest match wins.
  eligible.sort((a, b) => b.name.length.compareTo(a.name.length));

  // Track which character offsets are already matched.
  final matched = <int>{};
  final results = <IngredientMatch>[];

  for (final ing in eligible) {
    final base = RegExp.escape(ing.name);
    // Match name or name+'s' as whole word.
    final pattern = RegExp(
      r'\b(' + base + r's?)\b',
      caseSensitive: false,
    );

    for (final m in pattern.allMatches(stepText)) {
      final start = m.start;
      final end = m.end;
      // Check no overlap with already matched regions.
      bool overlaps = false;
      for (int k = start; k < end; k++) {
        if (matched.contains(k)) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;
      // Register.
      for (int k = start; k < end; k++) {
        matched.add(k);
      }
      results.add(IngredientMatch(ingredient: ing, start: start, end: end));
    }
  }

  // Sort by start offset so callers can build spans in order.
  results.sort((a, b) => a.start.compareTo(b.start));
  return results;
}
