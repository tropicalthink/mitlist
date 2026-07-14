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
    r'\b(grocer(?:y|ies)|supermarket|rewe|aldi|lidl|edeka|kaufland|penny|netto|tesco|carrefour|costco|whole foods|trader joe.?s)\b',
    caseSensitive: false,
  );

  Future<String?> suggest(String description, String groupId) async {
    final trimmed = description.trim();
    if (trimmed.length < 2) return null;
    if (_merchantPattern.hasMatch(trimmed)) return 'groceries';

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
