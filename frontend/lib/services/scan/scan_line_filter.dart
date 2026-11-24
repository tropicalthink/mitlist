import 'scan_models.dart';

/// Letters a line needs before it can be a list item; below this it is a
/// date, a time, a page number or a smudge ("16.03", "07:17", "2").
const int kMinItemLetters = 3;

/// A line whose text is this much smaller than the list's own handwriting is
/// print around the list (a letterhead footer, a label), not an entry.
const double kMinRelativeLineHeight = 0.45;

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

/// Indexes of [lines] that are probably not part of the handwritten list:
/// too few letters to name anything, or far smaller than the list's typical
/// line. They go to the review's Ignored section, one tap from restored, so a
/// wrong call costs a tap rather than a phantom item on the list.
Set<int> likelyNotListLines(List<OcrLine> lines) {
  final heights = <double>[
    for (final line in lines)
      if (line.bbox != null && _letters(line.text) >= kMinItemLetters)
        line.bbox!.height,
  ]..sort();
  final typical = heights.isEmpty ? null : heights[heights.length ~/ 2];
  return {
    for (var i = 0; i < lines.length; i++)
      if (_letters(lines[i].text) < kMinItemLetters ||
          (typical != null &&
              lines[i].bbox != null &&
              lines[i].bbox!.height < typical * kMinRelativeLineHeight))
        i,
  };
}

int _letters(String text) => _letter.allMatches(text).length;
