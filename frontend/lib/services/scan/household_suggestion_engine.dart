import '../../models/list_models.dart';
import '../restock_service.dart';
import 'grocery_suggestion_service.dart';
import 'resolution/string_sim.dart';

enum HouseholdSuggestionSource {
  /// An item that is already on the list being composed — usually one that was
  /// checked off. Re-adding it restores it instead of creating a duplicate, so
  /// it is offered first.
  listItem,
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
    this.onListChecked = false,
  });

  final String? canonicalItemId;
  final String name;
  final String category;
  final String unit;
  final Set<HouseholdSuggestionSource> sources;

  /// Only meaningful when [isOnList]: the matching row is currently checked
  /// off, so adding this restores it rather than doing nothing.
  final bool onListChecked;

  /// This name already has a row on the list being composed.
  bool get isOnList => sources.contains(HouseholdSuggestionSource.listItem);

  bool get hasIntelligence => sources.any((source) =>
      source != HouseholdSuggestionSource.product &&
      source != HouseholdSuggestionSource.listItem);
}

/// Owns cross-source identity reconciliation and ranking for the list composer.
/// Async source loading stays outside this class; callers progressively replace
/// source snapshots and read one stable, deduplicated candidate list.
class HouseholdSuggestionEngine {
  final Map<HouseholdSuggestionSource, List<_SourceSuggestion>> _sources = {};
  bool _emptyQuery = true;

  void beginQuery(String query) {
    _sources.clear();
    _emptyQuery = normaliseText(query).isEmpty;
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

  /// Rows already on the list being composed, most relevant first. Callers
  /// pass only rows matching the current query — an empty query has nothing to
  /// re-add.
  void setListItemSuggestions(List<ListItem> items) {
    _sources[HouseholdSuggestionSource.listItem] = [
      for (var i = 0; i < items.length; i++)
        _SourceSuggestion(
          source: HouseholdSuggestionSource.listItem,
          sourceIndex: i,
          canonicalItemId: items[i].canonicalItemId,
          name: items[i].name,
          unit: items[i].unit,
          checked: items[i].checked,
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
      HouseholdSuggestionSource.listItem,
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
              onListChecked: candidate.onListChecked,
              sources: Set.unmodifiable(candidate.sources),
            ))
        .toList(growable: false);
  }

  int _sourceRank(_MergedSuggestion candidate) {
    // A row already on the list outranks everything: it is the one candidate
    // whose add is guaranteed not to duplicate what the user is looking at.
    if (candidate.sources.contains(HouseholdSuggestionSource.listItem)) {
      return 0;
    }
    if (_emptyQuery &&
        candidate.sources.contains(HouseholdSuggestionSource.restock)) {
      return 1;
    }
    if (candidate.sources.contains(HouseholdSuggestionSource.catalog)) return 2;
    if (candidate.sources.contains(HouseholdSuggestionSource.bundled)) return 3;
    if (candidate.sources.contains(HouseholdSuggestionSource.product)) return 4;
    return 5;
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
    this.checked = false,
  });

  final HouseholdSuggestionSource source;
  final int sourceIndex;
  final String? canonicalItemId;
  final String name;
  final String category;
  final String unit;
  final bool checked;
}

class _MergedSuggestion {
  _MergedSuggestion.fromSource(_SourceSuggestion source)
      : canonicalItemId = source.canonicalItemId,
        name = source.name,
        category = source.category,
        unit = source.unit,
        sources = {source.source},
        onListChecked = source.checked,
        bestSourceIndex = source.sourceIndex;

  String? canonicalItemId;
  String name;
  String category;
  String unit;
  bool onListChecked;
  final Set<HouseholdSuggestionSource> sources;
  int bestSourceIndex;

  void merge(_SourceSuggestion source) {
    canonicalItemId ??= source.canonicalItemId;
    if (category.isEmpty && source.category.isNotEmpty) {
      category = source.category;
    }
    if (unit.isEmpty && source.unit.isNotEmpty) unit = source.unit;
    onListChecked = onListChecked || source.checked;
    sources.add(source.source);
    if (source.sourceIndex < bestSourceIndex) {
      bestSourceIndex = source.sourceIndex;
    }
  }
}
