import 'resolution_candidate.dart';
import 'string_sim.dart';

/// Plan 037 — the household-specific signals the scorer fuses on top of the
/// per-candidate source scores. Supplied once per `resolve` (not per candidate).
///
/// Build it from the DB in production (purchase history + co-occurrence) or
/// from explicit data in tests/eval. All maps are keyed by canonical item id.
class ResolutionContext {
  /// How many times this household has bought each item.
  final Map<String, int> purchaseCounts;

  /// Whole days since this household last bought each item.
  final Map<String, int> daysSinceLastPurchase;

  /// Co-occurrence affinity in [0,1] between each item and the items currently
  /// on the list (how often it's bought alongside them).
  final Map<String, double> cooccurrence;

  /// Largest value in [purchaseCounts] — the normaliser for frequency.
  final int maxPurchaseCount;

  ResolutionContext({
    this.purchaseCounts = const {},
    this.daysSinceLastPurchase = const {},
    this.cooccurrence = const {},
  }) : maxPurchaseCount =
            purchaseCounts.values.fold(0, (a, b) => a > b ? a : b);

  static final empty = ResolutionContext();
}

/// Fixed feature order — MUST match the build-time fitter
/// (`intelligence/ml/eval/resolution_eval.py`). Changing this list is a
/// breaking change to the weights bundle; regenerate the weights + golden file.
const List<String> kResolutionFeatureNames = [
  'aliasStringSim', // 0
  'canonicalNameSim', // 1 — query vs the candidate's OWN canonical name
  'classifierProb', // 2
  'embedderCosine', // 3
  'sourceAgreement', // 4 — sources / 5
  'isHouseholdAlias', // 5
  'householdFreq', // 6 — purchaseCount / maxPurchaseCount
  'recency', // 7 — 1 / (1 + daysSinceLastPurchase)
  'listCooccurrence', // 8
  'isExactAlias', // 9
];

int get kResolutionFeatureCount => kResolutionFeatureNames.length;

/// Builds the fixed-length feature vector for one candidate. Pure: no DB, no
/// async, no Flutter widgets. [query] is the normalised raw text.
List<double> buildResolutionFeatures(
  ResolutionCandidate c,
  String query,
  ResolutionContext ctx,
) {
  final id = c.canonicalItemId;

  // Similarity of the query to the candidate's OWN canonical name (DE or EN,
  // whichever is closer). This is what tells "spaghetti" apart from
  // egg_spaghetti when the word collides as an alias of both.
  final nameSim = [
    if (c.item.nameDe.isNotEmpty)
      stringSimilarity(query, normaliseText(c.item.nameDe)),
    if (c.item.nameEn.isNotEmpty)
      stringSimilarity(query, normaliseText(c.item.nameEn)),
  ].fold<double>(0.0, (a, b) => a > b ? a : b);

  final freq = ctx.maxPurchaseCount > 0
      ? (ctx.purchaseCounts[id] ?? 0) / ctx.maxPurchaseCount
      : 0.0;

  final days = ctx.daysSinceLastPurchase[id];
  final recency = days == null ? 0.0 : 1.0 / (1.0 + days);

  return [
    c.aliasStringSim,
    nameSim,
    c.classifierProb,
    c.embedderCosine,
    c.sources.length / 5.0,
    c.isHouseholdAlias ? 1.0 : 0.0,
    freq,
    recency,
    ctx.cooccurrence[id] ?? 0.0,
    c.isExactAlias ? 1.0 : 0.0,
  ];
}
