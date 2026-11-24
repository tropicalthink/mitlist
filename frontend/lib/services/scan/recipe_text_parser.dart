import 'dart:math' as math;

import 'scan_models.dart';

/// A recipe as read from a photo: a draft for the person to check.
class RecipeDraft {
  const RecipeDraft({
    this.title,
    this.ingredients = const [],
    this.steps = const [],
  });

  final String? title;
  final List<String> ingredients;
  final List<String> steps;

  bool get isEmpty => title == null && ingredients.isEmpty && steps.isEmpty;
}

/// Turns the lines OCR read from a recipe card or cookbook page into a title,
/// ingredients and steps.
///
/// A printed recipe has a shape: a title, a block of short lines that start
/// with an amount (often in two columns), then prose. Section headings
/// ("Ingredients", "Zutaten", "Method") are used when present, but most cards
/// have none, so the shape is what the parser reads. Only the first recipe on
/// a page is taken: a short heading after the method starts the next one.
class RecipeTextParser {
  const RecipeTextParser();

  RecipeDraft parse(List<OcrLine> input) {
    final lines = [
      for (final line in input)
        if (_letters(line.text) >= 2) _Line.from(line),
    ];
    if (lines.isEmpty) return const RecipeDraft();

    final ingredientsHeading = lines.indexWhere((l) => _isHeading(
          l.text,
          _ingredientHeadings,
        ));
    final stepsHeading =
        lines.indexWhere((l) => _isHeading(l.text, _stepHeadings));

    // Where the ingredients begin: after their heading, else at the first
    // line that starts with an amount.
    var ingredientsStart = ingredientsHeading >= 0
        ? ingredientsHeading + 1
        : lines.indexWhere((l) => _startsWithAmount(l.text));
    final String? title;
    if (ingredientsStart < 0) {
      // No amounts and no headings: the first line names it, short lines
      // below it are the ingredients.
      title = lines.first.text;
      ingredientsStart = 1;
    } else {
      title = _title(lines.sublist(
        0,
        ingredientsHeading >= 0 ? ingredientsHeading : ingredientsStart,
      ));
    }

    // The ingredients run until the method begins.
    var stepsStart = stepsHeading >= 0 && stepsHeading >= ingredientsStart
        ? stepsHeading
        : lines.length;
    for (var i = ingredientsStart; i < stepsStart; i++) {
      if (_isProse(lines[i].text)) {
        stepsStart = i;
        break;
      }
    }
    final ingredients = _ingredients(
      lines.sublist(math.min(ingredientsStart, stepsStart), stepsStart),
    );

    final stepLines = <_Line>[];
    for (var i = stepsStart; i < lines.length; i++) {
      final line = lines[i];
      if (i == stepsHeading) continue;
      if (stepLines.isNotEmpty && _startsNextRecipe(line, stepLines.last)) {
        break;
      }
      stepLines.add(line);
    }

    return RecipeDraft(
      title: title == null || title.isEmpty ? null : title,
      ingredients: ingredients,
      steps: _steps(stepLines),
    );
  }

  // --------------------------------------------------------------- title ---

  /// The most prominent confidently read line above the ingredients: a
  /// stamp or a byline is smaller or less legible than the dish's name.
  static String? _title(List<_Line> candidates) {
    if (candidates.isEmpty) return null;
    final confident =
        candidates.where((l) => (l.confidence ?? 1) >= 0.9).toList();
    if (confident.isEmpty) return candidates.first.text;
    confident.sort((a, b) => b.height.compareTo(a.height));
    return confident.first.text;
  }

  // --------------------------------------------------------- ingredients ---

  static List<String> _ingredients(List<_Line> block) {
    if (block.isEmpty) return const [];
    // Two lines run together across a column gap ("…gelatine 12 cup cream")
    // are two ingredients.
    final pieces = <_Line>[
      for (final line in block)
        if (!_isHeading(line.text, _ingredientHeadings))
          ..._splitAtAmounts(line),
    ];
    // Read column by column: the left column top to bottom, then the right.
    final lefts = pieces.map((l) => l.left).toList()..sort();
    double? columnBreak;
    var widest = 0.0;
    final span = pieces.map((l) => l.right).fold(0.0, math.max) - lefts.first;
    for (var i = 1; i < lefts.length; i++) {
      final gap = lefts[i] - lefts[i - 1];
      if (gap > widest) {
        widest = gap;
        columnBreak = (lefts[i] + lefts[i - 1]) / 2;
      }
    }
    final twoColumns = span > 0 && widest > 0.25 * span;
    int column(_Line l) => twoColumns && l.left > columnBreak! ? 1 : 0;
    pieces.sort((a, b) {
      final byColumn = column(a).compareTo(column(b));
      return byColumn != 0 ? byColumn : a.top.compareTo(b.top);
    });

    final out = <String>[];
    _Line? previous;
    for (final piece in pieces) {
      final text = piece.text.trim();
      // "—more if needed", "(optional)", "or 1 quart stewed" finish the line
      // above them.
      if (out.isNotEmpty &&
          previous != null &&
          column(previous) == column(piece) &&
          RegExp(r'^(?:[—–\-(]|or\b|oder\b|ou\b|o\b)', caseSensitive: false)
              .hasMatch(text)) {
        out[out.length - 1] = '${out.last} $text';
      } else {
        out.add(_repairFractions(text));
      }
      previous = piece;
    }
    return out;
  }

  static final RegExp _midLineAmount = RegExp(
    r'\s(?=(?:\d+(?:[/.,]\d+)?|[½¼¾⅓⅔⅛])\s?'
    r'(?:cups?|c|tablespoons?|tbsps?|tbl|teaspoons?|tsps?|t|lbs?|pounds?|oz|'
    r'ounces?|g|kg|ml|l|el|tl|pints?|quarts?|qt|cans?|cloves?|eggs?)\b\.?\s)',
    caseSensitive: false,
  );

  static List<_Line> _splitAtAmounts(_Line line) {
    final text = line.text;
    final cuts = <int>[0];
    for (final match in _midLineAmount.allMatches(text)) {
      final before = text.substring(cuts.last, match.start).trim();
      final previousWord = before.split(RegExp(r'\s+')).last.toLowerCase();
      if (before.split(RegExp(r'\s+')).length < 2) continue;
      if (const {'or', 'oder', 'ou', 'o', 'to', 'bis', '-', 'and', 'und', 'of'}
          .contains(previousWord)) {
        continue;
      }
      cuts.add(match.start + 1);
    }
    if (cuts.length == 1) return [line];
    cuts.add(text.length);
    return [
      for (var i = 0; i + 1 < cuts.length; i++)
        _Line(
          text: text.substring(cuts[i], cuts[i + 1]).trim(),
          // Where the piece sat, estimated from its share of the characters.
          left: line.left + line.width * cuts[i] / math.max(1, text.length),
          right: line.right,
          top: line.top,
          height: line.height,
          confidence: line.confidence,
        ),
    ];
  }

  static const _units =
      r'(?:cups?|tablespoons?|teaspoons?|tbsps?|tsps?|pints?|quarts?|'
      r'pounds?|lbs?|ounces?|oz|c|t)\b';

  /// OCR drops the fraction bar of a printed "½": "1½" comes out as "112"
  /// or "11/2", "½ cup" as "12 cup". Twelve of a singular "cup" is a half.
  static String _repairFractions(String text) {
    var out = text.replaceFirstMapped(
      RegExp(r'^(\d)([1-7])/([2-8])\b'),
      (m) => int.parse(m[2]!) < int.parse(m[3]!)
          ? '${m[1]} ${m[2]}/${m[3]}'
          : m[0]!,
    );
    out = out.replaceFirstMapped(
      RegExp('^1([1-7])([2-8])\\s+(?=$_units)', caseSensitive: false),
      (m) => int.parse(m[1]!) < int.parse(m[2]!) ? '1 ${m[1]}/${m[2]} ' : m[0]!,
    );
    out = out.replaceFirstMapped(
      RegExp(
        r'^([1-7])([2-8])\s+(?=(?:cup|tablespoon|teaspoon|pint|quart|pound|ounce)\b)',
        caseSensitive: false,
      ),
      (m) => int.parse(m[1]!) < int.parse(m[2]!) ? '${m[1]}/${m[2]} ' : m[0]!,
    );
    return out;
  }

  // --------------------------------------------------------------- steps ---

  static List<String> _steps(List<_Line> lines) {
    if (lines.isEmpty) return const [];
    final blockLeft = lines.map((l) => l.left).reduce(math.min);
    final paragraphs = <String>[];
    _Line? previous;
    for (final line in lines) {
      var text = line.text.trim();
      final numbered = _stepNumber.firstMatch(text);
      if (numbered != null) text = text.substring(numbered.end).trim();
      final startsParagraph = previous == null ||
          numbered != null ||
          line.top - previous.bottom >
              0.8 * math.min(line.height, previous.height) ||
          (RegExp(r'[.!?]$').hasMatch(previous.text.trim()) &&
              line.left - blockLeft > 0.5 * line.height);
      if (startsParagraph || paragraphs.isEmpty) {
        paragraphs.add(text);
      } else if (RegExp(r'\p{L}-$', unicode: true).hasMatch(paragraphs.last)) {
        paragraphs[paragraphs.length - 1] = '${paragraphs.last}$text';
      } else {
        paragraphs[paragraphs.length - 1] = '${paragraphs.last} $text';
      }
      previous = line;
    }
    return [
      for (final paragraph in paragraphs) ..._sentences(paragraph),
    ];
  }

  static final RegExp _stepNumber = RegExp(
    r'^\s*(?:(?:step|schritt|étape|paso|stap)\s*)?\d{1,2}\s*[.):]\s+',
    caseSensitive: false,
  );

  static const _abbreviations = {
    'tsp',
    'tsps',
    'tbsp',
    'tbl',
    'lbs',
    'lb',
    'oz',
    'mrs',
    'mr',
    'dr',
    'st',
    'no',
    'approx',
    'ca',
    'vs',
    'bzw',
    'ggf',
    'evtl',
    'min',
    'std',
  };

  /// One action per step: a cookbook paragraph is split at its sentences.
  static List<String> _sentences(String paragraph) {
    final out = <String>[];
    var start = 0;
    for (final match
        in RegExp(r'[.!?]\s+(?=[A-ZÄÖÜÀ-Ý])').allMatches(paragraph)) {
      final before = paragraph.substring(start, match.start);
      final lastWord = RegExp(r'(\p{L}+)$', unicode: true)
          .firstMatch(before)
          ?.group(1)
          ?.toLowerCase();
      if (lastWord != null &&
          (_abbreviations.contains(lastWord) ||
              (lastWord.length == 1 && lastWord != 'f'))) {
        continue;
      }
      out.add(paragraph.substring(start, match.start + 1).trim());
      start = match.end;
    }
    out.add(paragraph.substring(start).trim());
    return out.where((s) => _letters(s) >= 2).toList();
  }

  /// A short heading set apart below the method is the next recipe on the
  /// page ("Apricot Cobbler"), not more method.
  static bool _startsNextRecipe(_Line line, _Line previous) {
    final text = line.text.trim();
    final words = text.split(RegExp(r'\s+'));
    return words.length <= 4 &&
        !RegExp(r'[.,;:!?]$').hasMatch(text) &&
        RegExp(r'^\p{Lu}', unicode: true).hasMatch(text) &&
        !_startsWithAmount(text) &&
        line.top - previous.bottom > 0.8 * line.height;
  }

  // ---------------------------------------------------------- line kinds ---

  static final RegExp _amount = RegExp(
    r'^\s*(?:[-•*·]\s*)?(?:\d|[½¼¾⅓⅔⅛]|(?:one|two|three|zwei|drei|pinch|prise|dash|handful)\s)',
    caseSensitive: false,
  );

  static bool _startsWithAmount(String text) =>
      _amount.hasMatch(text) && !_stepNumber.hasMatch(text);

  /// A line of method rather than an ingredient: a sentence.
  static bool _isProse(String text) {
    if (_stepNumber.hasMatch(text)) return true;
    final words = text.trim().split(RegExp(r'\s+')).length;
    if (_startsWithAmount(text)) return false;
    return words >= 7 ||
        (words >= 5 && RegExp(r'[.!?]$').hasMatch(text.trim()));
  }

  static const _ingredientHeadings = [
    'ingredients',
    'you will need',
    'zutaten',
    'ingrédients',
    'ingredientes',
    'ingrediënten',
    'ingredienti',
  ];

  static const _stepHeadings = [
    'method',
    'instructions',
    'directions',
    'preparation',
    'steps',
    'zubereitung',
    'anleitung',
    'préparation',
    'preparación',
    'bereiding',
    'preparazione',
    'procedimento',
  ];

  /// "Ingredients", "Zutaten für 4 Personen:", "METHOD".
  static bool _isHeading(String text, List<String> headings) {
    final lower = text.trim().toLowerCase().replaceAll(RegExp(r'[:.]$'), '');
    return headings.any((h) =>
        lower == h ||
        (lower.startsWith('$h ') && lower.split(RegExp(r'\s+')).length <= 5));
  }

  static int _letters(String text) =>
      RegExp(r'\p{L}', unicode: true).allMatches(text).length;
}

class _Line {
  const _Line({
    required this.text,
    required this.left,
    required this.right,
    required this.top,
    required this.height,
    this.confidence,
  });

  factory _Line.from(OcrLine line) {
    final box = line.bbox;
    return _Line(
      text: line.text.trim(),
      left: box?.left ?? 0,
      right: box == null ? 0 : box.left + box.width,
      top: box?.top ?? 0,
      height: box?.height ?? 0,
      confidence: line.confidence,
    );
  }

  final String text;
  final double left;
  final double right;
  final double top;
  final double height;
  final double? confidence;

  double get width => right - left;
  double get bottom => top + height;
}
