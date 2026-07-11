import '../../models/list_models.dart';
import '../restock_service.dart';
import 'grocery_suggestion_service.dart';
import 'resolution/string_sim.dart';

enum HouseholdSuggestionSource {
  restock,
  catalog,
  bundled,
  product,
}

class HouseholdSuggestion {
  const HouseholdSuggestion({
    required this.name,
    required this.sources,
    this.canonicalItemId,
    this.category = '',
    this.unit = '',
  });

  final String? canonicalItemId;
  final String name;
  final String category;
  final String unit;
  final Set<HouseholdSuggestionSource> sources;

  bool get hasIntelligence =>
      sources.any((source) => source != HouseholdSuggestionSource.product);
}

/// Owns cross-source identity reconciliation and ranking for the list composer.
/// Async source loading stays outside this class; callers progressively replace
/// source snapshots and read one stable, deduplicated candidate list.
class HouseholdSuggestionEngine {
  String _query = '';
  final Map<HouseholdSuggestionSource, List<_SourceSuggestion>> _sources = {};

  void beginQuery(String query) {
    _query = normaliseText(query);
    _sources.clear();
  }

  void setGrocerySuggestions(
    HouseholdSuggestionSource source,
    List<GrocerySuggestion> suggestions,
  ) {
    assert(source != HouseholdSuggestionSource.product);
    _sources[source] = [
      for (var i = 0; i < suggestions.length; i++)
        _SourceSuggestion(
          source: source,
          sourceIndex: i,
          canonicalItemId: suggestions[i].canonicalItemId,
          name: suggestions[i].name,
          category: suggestions[i].category,
          unit: suggestions[i].unit,
        ),
    ];
  }

  void setRestockSuggestions(List<RestockSuggestion> suggestions) {
    _sources[HouseholdSuggestionSource.restock] = [
      for (var i = 0; i < suggestions.length; i++)
        _SourceSuggestion(
          source: HouseholdSuggestionSource.restock,
          sourceIndex: i,
          canonicalItemId: suggestions[i].canonicalItemId,
          name: suggestions[i].name,
        ),
    ];
  }

  void setProducts(List<Product> products) {
    _sources[HouseholdSuggestionSource.product] = [
      for (var i = 0; i < products.length; i++)
        _SourceSuggestion(
          source: HouseholdSuggestionSource.product,
          sourceIndex: i,
          name: products[i].name,
          unit: products[i].unit,
        ),
    ];
  }

  List<HouseholdSuggestion> get suggestions {
    final merged = <_MergedSuggestion>[];
    final byCanonicalId = <String, _MergedSuggestion>{};
    final byName = <String, _MergedSuggestion>{};

    for (final source in const [
      HouseholdSuggestionSource.restock,
      HouseholdSuggestionSource.catalog,
      HouseholdSuggestionSource.bundled,
      HouseholdSuggestionSource.product,
    ]) {
      for (final suggestion in _sources[source] ?? const []) {
        final normalizedName = normaliseText(suggestion.name);
        if (normalizedName.isEmpty) continue;
        var candidate = suggestion.canonicalItemId == null
            ? null
            : byCanonicalId[suggestion.canonicalItemId!];
        candidate ??= byName[normalizedName];
        if (candidate == null) {
          candidate = _MergedSuggestion.fromSource(suggestion);
          merged.add(candidate);
        } else {
          candidate.merge(suggestion);
        }
        byName[normalizedName] = candidate;
        final canonicalId = candidate.canonicalItemId;
        if (canonicalId != null) byCanonicalId[canonicalId] = candidate;
      }
    }

    merged.sort((a, b) {
      final queryRankA = _queryRank(a);
      final queryRankB = _queryRank(b);
      if (queryRankA != queryRankB) return queryRankA.compareTo(queryRankB);
      final sourceRankA = _sourceRank(a);
      final sourceRankB = _sourceRank(b);
      if (sourceRankA != sourceRankB) return sourceRankA.compareTo(sourceRankB);
      if (a.bestSourceIndex != b.bestSourceIndex) {
        return a.bestSourceIndex.compareTo(b.bestSourceIndex);
      }
      return a.name.compareTo(b.name);
    });

    return merged
        .take(8)
        .map((candidate) => HouseholdSuggestion(
              canonicalItemId: candidate.canonicalItemId,
              name: candidate.name,
              category: candidate.category,
              unit: candidate.unit,
              sources: Set.unmodifiable(candidate.sources),
            ))
        .toList(growable: false);
  }

  int _queryRank(_MergedSuggestion candidate) {
    if (_query.isEmpty) {
      return candidate.sources.contains(HouseholdSuggestionSource.restock)
          ? 0
          : 1;
    }
    return normaliseText(candidate.name).startsWith(_query) ? 0 : 1;
  }

  static int _sourceRank(_MergedSuggestion candidate) {
    if (candidate.sources.contains(HouseholdSuggestionSource.restock)) return 0;
    if (candidate.sources.contains(HouseholdSuggestionSource.catalog)) return 1;
    if (candidate.sources.contains(HouseholdSuggestionSource.bundled)) return 2;
    return 3;
  }
}

class _SourceSuggestion {
  const _SourceSuggestion({
    required this.source,
    required this.sourceIndex,
    required this.name,
    this.canonicalItemId,
    this.category = '',
    this.unit = '',
  });

  final HouseholdSuggestionSource source;
  final int sourceIndex;
  final String? canonicalItemId;
  final String name;
  final String category;
  final String unit;
}

class _MergedSuggestion {
  _MergedSuggestion.fromSource(_SourceSuggestion source)
      : canonicalItemId = source.canonicalItemId,
        name = source.name,
        category = source.category,
        unit = source.unit,
        sources = {source.source},
        bestSourceIndex = source.sourceIndex;

  String? canonicalItemId;
  String name;
  String category;
  String unit;
  final Set<HouseholdSuggestionSource> sources;
  int bestSourceIndex;

  void merge(_SourceSuggestion source) {
    canonicalItemId ??= source.canonicalItemId;
    if (category.isEmpty && source.category.isNotEmpty) {
      category = source.category;
    }
    if (unit.isEmpty && source.unit.isNotEmpty) unit = source.unit;
    sources.add(source.source);
    if (source.sourceIndex < bestSourceIndex) {
      bestSourceIndex = source.sourceIndex;
    }
  }
}
