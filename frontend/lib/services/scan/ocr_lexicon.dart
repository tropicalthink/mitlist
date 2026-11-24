import 'dart:math' as math;

import 'ppocr_processor.dart';
import 'resolution/string_sim.dart';

/// Prior mass the decoder gives to "this line is something the household has
/// written before", to a catalog name it has not, and to a word in neither.
/// Measured on the sample photos, the decoder is insensitive to these within
/// a tenfold range; the visual-gap guard is what keeps it safe.
const double kHouseholdLexiconMass = 0.7;
const double kCatalogLexiconMass = 0.2;
const double kUnknownWordMass = 0.1;

/// Character bigram model over catalog names: how much an unknown reading
/// costs. Without it every raw reading would look as likely as a known word,
/// and the lexicon could never win.
class CharacterBigramModel {
  CharacterBigramModel._(this._counts, this._contexts, this._alphabetSize);

  factory CharacterBigramModel.train(Iterable<String> words) {
    final counts = <String, Map<String, int>>{};
    final contexts = <String, int>{};
    final alphabet = <String>{};
    for (final word in words) {
      final text = '^${word.toLowerCase()}\$';
      for (var i = 0; i + 1 < text.length; i++) {
        final a = text[i];
        final b = text[i + 1];
        final row = counts.putIfAbsent(a, () => {});
        row[b] = (row[b] ?? 0) + 1;
        contexts[a] = (contexts[a] ?? 0) + 1;
        alphabet.add(b);
      }
    }
    return CharacterBigramModel._(
        counts, contexts, math.max(1, alphabet.length));
  }

  final Map<String, Map<String, int>> _counts;
  final Map<String, int> _contexts;
  final int _alphabetSize;

  static const double _smoothing = 0.5;

  double logProbability(String text) {
    final padded = '^${text.toLowerCase()}\$';
    var total = 0.0;
    for (var i = 0; i + 1 < padded.length; i++) {
      final count = (_counts[padded[i]]?[padded[i + 1]] ?? 0) + _smoothing;
      total += math.log(
          count / ((_contexts[padded[i]] ?? 0) + _smoothing * _alphabetSize));
    }
    return total;
  }
}

/// Catalog names close in spelling to a raw reading: the cold-start
/// vocabulary for words the household has never written.
class CatalogShortlist {
  CatalogShortlist(Iterable<String> names)
      : _names = [
          for (final name in names.toSet())
            if (name.trim().isNotEmpty) (name, normaliseText(name)),
        ];

  final List<(String, String)> _names;

  List<OcrLexiconEntry> near(String rawText, {int limit = 30}) {
    final query =
        normaliseText(rawText.replaceFirst(RegExp(r'^[\s\-–—•*]+'), ''));
    if (query.length < 3) return const [];
    final maxDelta = math.max(3, query.length ~/ 2);
    final scored = <(String, double)>[];
    for (final (name, normalized) in _names) {
      if ((normalized.length - query.length).abs() > maxDelta) continue;
      final similarity = stringSimilarity(query, normalized);
      if (similarity >= 0.45) scored.add((name, similarity));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final prior = math.log(kCatalogLexiconMass / limit);
    return [
      for (final (name, _) in scored.take(limit)) OcrLexiconEntry(name, prior),
    ];
  }
}

/// Turns a household's vocabulary (what it has written or bought, with how
/// often) into decoder entries. Frequent words get more of the household
/// mass, so "Rapsöl" bought every week beats a one-off look-alike.
List<OcrLexiconEntry> householdLexiconEntries(Map<String, int> vocabulary) {
  final total = vocabulary.values.fold<int>(0, (sum, count) => sum + count);
  if (total == 0) return const [];
  return [
    for (final entry in vocabulary.entries)
      if (entry.key.trim().isNotEmpty && entry.value > 0)
        OcrLexiconEntry(
          entry.key.trim(),
          math.log(kHouseholdLexiconMass * entry.value / total),
        ),
  ];
}
