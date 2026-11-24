import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/scan_line_filter.dart';
import 'package:mitlist/services/scan/scan_models.dart';

OcrLine _line(String text, double height) =>
    OcrLine(text: text, bbox: OcrBBox(0, 0, 200, height));

void main() {
  test('handwritten entries stay, dates and small print are set aside', () {
    final lines = [
      _line('Milch', 60),
      _line('Brot', 55),
      _line('2x Eier', 58),
      _line('16.03', 40), // a date stamp
      _line('7', 50), // a stray digit
      _line('info@engelbert-strauss.com', 18), // letterhead footer
      _line('Ei', 60), // two letters: not enough to name anything
    ];
    expect(likelyNotListLines(lines), {3, 4, 5, 6});
  });

  test('a list of short words is not mistaken for print', () {
    final lines = [
      _line('Tee', 40),
      _line('Eis', 42),
      _line('Reis', 41),
    ];
    expect(likelyNotListLines(lines), isEmpty);
  });

  test('lines without boxes are judged on letters alone', () {
    expect(
      likelyNotListLines(
          [const OcrLine(text: 'Milch'), const OcrLine(text: '07:17')]),
      {1},
    );
  });
}
