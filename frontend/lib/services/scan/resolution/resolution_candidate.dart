import '../../../storage/app_database.dart';

/// Plan 037 — one candidate canonical item proposed by one or more resolver
/// sources, carrying each source's raw signal. The scorer turns these signals
/// (plus the household prior, supplied separately) into a calibrated P(correct).
class ResolutionCandidate {
  final CanonicalItemsTableData item;

  /// Best `1 - normEdit` over this item's aliases against the query (1.0 exact).
  final double aliasStringSim;

  /// Classifier softmax probability for this item (0 if it didn't propose it).
  final double classifierProb;

  /// Embedder cosine for this item (0 if it didn't propose it).
  final double embedderCosine;

  /// Which sources proposed it: any of
  /// `household_alias` `global_alias` `fuzzy` `classifier` `embedder`.
  final Set<String> sources;

  /// The query exactly equals one of this item's aliases.
  final bool isExactAlias;

  /// A household-scoped alias/correction (not a global seed alias) maps here —
  /// i.e. this household has confirmed this mapping before.
  final bool isHouseholdAlias;

  const ResolutionCandidate({
    required this.item,
    required this.aliasStringSim,
    required this.classifierProb,
    required this.embedderCosine,
    required this.sources,
    required this.isExactAlias,
    required this.isHouseholdAlias,
  });

  String get canonicalItemId => item.id;
}
