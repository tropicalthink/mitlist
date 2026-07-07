import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/canonical_display.dart';
import 'package:mitlist/storage/app_database.dart';

// canonical_display — proves the grocery UI labels a canonical item in the
// user's locale (de/en/fr/es shipped) with a sensible fallback chain.

CanonicalItemsTableData _item({
  String de = '',
  String en = '',
  String fr = '',
  String es = '',
}) {
  final now = DateTime(2020);
  return CanonicalItemsTableData(
    id: 'strawberry',
    groupId: '__global__',
    nameDe: de,
    nameEn: en,
    nameFr: fr,
    nameEs: es,
    category: 'produce',
    defaultUnit: 'g',
    isGlobal: true,
    version: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final full =
      _item(de: 'Erdbeere', en: 'Strawberry', fr: 'Fraise', es: 'Fresa');

  test('each locale picks its own market name', () {
    expect(canonicalDisplayName(full, lang: 'de'), 'Erdbeere');
    expect(canonicalDisplayName(full, lang: 'en'), 'Strawberry');
    expect(canonicalDisplayName(full, lang: 'fr'), 'Fraise');
    expect(canonicalDisplayName(full, lang: 'es'), 'Fresa');
  });

  test('fr falls back across markets when fr name is missing', () {
    final noFr = _item(de: 'Erdbeere', en: 'Strawberry', es: 'Fresa');
    // fr → en → de → es: English wins as the first available fallback.
    expect(canonicalDisplayName(noFr, lang: 'fr'), 'Strawberry');
  });

  test('es falls back to en then de', () {
    final onlyDe = _item(de: 'Erdbeere');
    expect(canonicalDisplayName(onlyDe, lang: 'es'), 'Erdbeere');
  });

  test('unshipped UI language (nl) gets the most universal label (en first)',
      () {
    expect(canonicalDisplayName(full, lang: 'nl'), 'Strawberry');
  });

  test('falls back to id when no name exists', () {
    expect(canonicalDisplayName(_item(), lang: 'en'), 'strawberry');
  });

  test('uses the app-wide groceryDisplayLang when lang omitted', () {
    final saved = groceryDisplayLang;
    addTearDown(() => groceryDisplayLang = saved);

    setGroceryDisplayLang('fr');
    expect(canonicalDisplayName(full), 'Fraise');
    setGroceryDisplayLang('es');
    expect(canonicalDisplayName(full), 'Fresa');
  });

  test('setGroceryDisplayLang(null) follows the device, not crashes', () {
    final saved = groceryDisplayLang;
    addTearDown(() => groceryDisplayLang = saved);
    setGroceryDisplayLang(null); // platform locale
    // Just assert it returns a non-empty shipped name (device locale varies).
    expect(canonicalDisplayName(full), isNotEmpty);
  });
}
