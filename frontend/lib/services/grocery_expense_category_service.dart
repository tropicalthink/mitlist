import 'package:flutter/foundation.dart';

import 'scan/canonical_link_service.dart';

typedef GroceryLinkResolver = Future<String?> Function(
  String text,
  String groupId,
);

/// Conservative expense categorisation backed by the grocery resolver.
///
/// It only claims the `groceries` category. Other finance categories remain a
/// user decision because the bundled models were trained for grocery identity,
/// not general-purpose transaction classification.
class GroceryExpenseCategoryService {
  GroceryExpenseCategoryService(CanonicalLinkService links)
      : _resolve =
            ((text, groupId) => links.resolveHighConfidence(text, groupId));

  @visibleForTesting
  GroceryExpenseCategoryService.withResolver(this._resolve);

  final GroceryLinkResolver _resolve;

  static final RegExp _merchantPattern = RegExp(
    r'\b(grocer(?:y|ies)|supermarket|rewe|aldi|lidl|edeka|kaufland|tesco|carrefour|costco|whole foods|trader joe.?s)\b',
    caseSensitive: false,
  );

  /// Chains whose names are also ordinary words ("penny stocks", "netto" is
  /// German for "net"): only the bare store name counts.
  static final RegExp _ambiguousMerchantPattern = RegExp(
    r'^(penny|netto)(\s+markt)?$',
    caseSensitive: false,
  );

  /// Words that mark spending as something other than a grocery shop, even
  /// when the rest names food: a water bill, a coffee at a café, beers at a
  /// bar. The resolver only knows what items are, not where they were bought.
  static final RegExp _notGroceriesPattern = RegExp(
    r'\b(bill|rent|utilit(?:y|ies)|electricity|internet|phone|insurance|'
    r'subscription|restaurant|cafe|bar|pub|dinner|lunch|breakfast|brunch|'
    // Not "delivery": a milk round or grocery delivery is groceries.
    r'takeaway|takeout|tip|ticket|cinema|movie|fuel|petrol|gas|'
    r'taxi|uber|flight|hotel|gift|present|party|'
    r'strom|handy|abo|kneipe|essen gehen|kino|benzin|flug|feier)\b'
    // German compounds put the telling word last ("Wasserrechnung",
    // "Kfz-Versicherung", "Pizzalieferung"), so these match as word endings.
    r'|(rechnung|miete|nebenkosten|versicherung|trinkgeld|'
    r'abendessen|mittagessen|frühstück|tanken|geschenk)\b'
    // Dart's \b only knows ASCII letters, so it never fires after "é".
    r'|\bcafé(?![a-z])',
    caseSensitive: false,
  );

  Future<String?> suggest(String description, String groupId) async {
    final trimmed = description.trim();
    if (trimmed.length < 2) return null;
    if (_notGroceriesPattern.hasMatch(trimmed)) return null;
    if (_merchantPattern.hasMatch(trimmed) ||
        _ambiguousMerchantPattern.hasMatch(trimmed)) {
      return 'groceries';
    }

    // Try the full description first, then a small bounded set of receipt-like
    // fragments ("milk & bread", "apples, yogurt"). Never model-scan an
    // unbounded note.
    final candidates = <String>{trimmed};
    candidates.addAll(
      trimmed
          .split(RegExp(r'[,;&+/]'))
          .map((part) => part.trim())
          .where((part) => part.length >= 2)
          .take(6),
    );
    for (final candidate in candidates.take(7)) {
      if (await _resolve(candidate, groupId) != null) return 'groceries';
    }
    return null;
  }
}
