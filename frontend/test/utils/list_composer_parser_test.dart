import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/utils/list_composer_parser.dart';

void main() {
  group('parseComposerItem', () {
    test('plain name → quantity 1, no unit', () {
      final r = parseComposerItem('milk');
      expect(r.name, 'milk');
      expect(r.quantity, 1);
      expect(r.unit, '');
    });

    test('multi-word name with no leading number stays whole', () {
      final r = parseComposerItem('almond milk');
      expect(r.name, 'almond milk');
      expect(r.quantity, 1);
      expect(r.unit, '');
    });

    test('leading integer is parsed as quantity', () {
      final r = parseComposerItem('2 milk');
      expect(r.name, 'milk');
      expect(r.quantity, 2);
      expect(r.unit, '');
    });

    test('quantity + unit + name', () {
      final r = parseComposerItem('2 kg flour');
      expect(r.name, 'flour');
      expect(r.quantity, 2);
      expect(r.unit, 'kg');
    });

    test('comma decimals are accepted', () {
      final r = parseComposerItem('1,5 l water');
      expect(r.name, 'water');
      expect(r.quantity, 1.5);
      expect(r.unit, 'l');
    });

    test('multi-word name after quantity + unit', () {
      final r = parseComposerItem('3 cans black beans');
      expect(r.name, 'black beans');
      expect(r.quantity, 3);
      expect(r.unit, 'cans');
    });

    test('non-positive quantity falls back to whole string', () {
      final r = parseComposerItem('0 milk');
      expect(r.name, '0 milk');
      expect(r.quantity, 1);
      expect(r.unit, '');
    });

    test('over-long second token is not treated as a unit', () {
      final r = parseComposerItem('2 supercalifragilistic apples');
      expect(r.quantity, 2);
      expect(r.unit, '');
      expect(r.name, 'supercalifragilistic apples');
    });

    test('second token containing a digit is not a unit', () {
      final r = parseComposerItem('2 x3 widgets');
      expect(r.quantity, 2);
      expect(r.unit, '');
      expect(r.name, 'x3 widgets');
    });

    test('quantity with trailing whitespace and no name falls back', () {
      final r = parseComposerItem('5   ');
      expect(r.name, '5');
      expect(r.quantity, 1);
    });
  });
}
