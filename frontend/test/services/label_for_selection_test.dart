import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';

// labelForSelection — brand-preserve logic (plan 012 D). Pure function, no DB:
// the brand the user typed is kept ("Pringles") while the canonical item
// ("Chips") is linked underneath; only fragments/typos get corrected.

void main() {
  String label(String typed, String canonical) =>
      GrocerySuggestionService.labelForSelection(typed, canonical);

  test('distinct brand is preserved (canonical linked underneath)', () {
    expect(label('Pringles', 'Chips'), 'Pringles');
    expect(label('Coca Cola', 'Soft Drink'), 'Coca Cola');
  });

  test('lower-cased brand keeps internal casing, first letter capitalised', () {
    expect(label('pringles', 'Chips'), 'Pringles');
  });

  test('typo is corrected to the canonical name', () {
    expect(label('mlch', 'Milch'), 'Milch');
    expect(label('banann', 'Banane'), 'Banane');
  });

  test('prefix fragment is corrected to the canonical name', () {
    expect(label('toma', 'Tomate'), 'Tomate');
    expect(label('milc', 'Milch'), 'Milch');
  });

  test('exact match (any case) uses canonical casing', () {
    expect(label('milch', 'Milch'), 'Milch');
    expect(label('FRAISE', 'Fraise'), 'Fraise');
  });

  test('empty typed text falls back to canonical', () {
    expect(label('   ', 'Milch'), 'Milch');
  });
}
