import 'dart:typed_data';

/// Pure-Dart TF-IDF helpers shared by the classifier facade and native inference.
class GroceryClassifierMath {
  GroceryClassifierMath._();

  /// Converts [text] to a character-trigram string, matching the Python
  /// `char_trigrams` function in `train.py`.
  ///
  /// `text.lower()[:maxLen-4]` → join consecutive triples with spaces.
  static String charTrigrams(String text, {int maxLen = 64}) {
    final t = text.toLowerCase();
    final cut = t.length > (maxLen - 4) ? t.substring(0, maxLen - 4) : t;
    if (cut.length <= 2) return cut;
    final grams = <String>[];
    for (var i = 0; i <= cut.length - 3; i++) {
      grams.add(cut.substring(i, i + 3));
    }
    return grams.join(' ');
  }

  /// Builds a TF-IDF vector from a trigram string, matching the Keras
  /// `TextVectorization(output_mode="tf_idf")` layer.
  static Float32List buildTfidf(
    String trigramString, {
    required Map<String, int> vocabIndex,
    required List<double> idf,
    required String stripChars,
  }) {
    final stripSet = stripChars.codeUnits.toSet();
    final tokens = trigramString
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) {
          final buf = StringBuffer();
          for (final cu in t.codeUnits) {
            if (!stripSet.contains(cu)) buf.writeCharCode(cu);
          }
          return buf.toString();
        })
        .where((t) => t.isNotEmpty)
        .toList();

    final counts = List<double>.filled(idf.length, 0.0);
    for (final token in tokens) {
      final idx = vocabIndex[token] ?? 1;
      if (idx < counts.length) counts[idx]++;
    }

    final out = Float32List(idf.length);
    for (var i = 0; i < idf.length; i++) {
      out[i] = counts[i] * idf[i];
    }
    return out;
  }
}
