import 'dart:ui' as ui;

import '../storage/app_database.dart';

/// The 2-letter language the grocery UI labels canonical items in.
///
/// The seed ships four markets (de/en/fr/es). Resolution services are built in
/// many places — some without a Riverpod `ref`, plus the nested scan pipeline —
/// so rather than thread the locale through every constructor we keep one
/// app-wide value (the same pattern as `Intl.defaultLocale`). It is set from
/// `localeProvider` in `app.dart` and defaults to the platform locale.
String groceryDisplayLang = _platformLang();

String _platformLang() {
  final code = ui.PlatformDispatcher.instance.locale.languageCode;
  return code.isEmpty ? 'en' : code;
}

/// Sets [groceryDisplayLang] from a possibly-null locale code (null = follow the
/// device). Called from `app.dart` whenever the app locale changes.
void setGroceryDisplayLang(String? langCode) {
  groceryDisplayLang =
      (langCode == null || langCode.isEmpty) ? _platformLang() : langCode;
}

/// Picks the best raw display name for [item] in [lang] (defaults to the
/// app-wide [groceryDisplayLang]), falling back across the shipped markets so a
/// non-empty label is always returned when one exists. Casing is the caller's
/// responsibility (sites differ: capitalise-first vs. title-case).
String canonicalDisplayName(CanonicalItemsTableData item, {String? lang}) {
  final ordered = _orderFor(lang ?? groceryDisplayLang, item);
  for (final name in ordered) {
    if (name.isNotEmpty) return name;
  }
  return item.id;
}

List<String> _orderFor(String lang, CanonicalItemsTableData i) {
  switch (lang) {
    case 'fr':
      return [i.nameFr, i.nameEn, i.nameDe, i.nameEs];
    case 'es':
      return [i.nameEs, i.nameEn, i.nameDe, i.nameFr];
    case 'de':
      return [i.nameDe, i.nameEn, i.nameFr, i.nameEs];
    case 'en':
      return [i.nameEn, i.nameDe, i.nameFr, i.nameEs];
    default:
      // Unshipped UI languages (e.g. nl) get the most universal label.
      return [i.nameEn, i.nameDe, i.nameFr, i.nameEs];
  }
}
