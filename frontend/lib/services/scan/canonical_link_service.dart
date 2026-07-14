import 'package:flutter/foundation.dart';

import 'canonical_resolver_service.dart';
import 'resolution/resolution_features.dart';

/// Applies the conservative acceptance rule used when linking ordinary typed
/// list text to the local canonical grocery graph.
///
/// Scan review can ask a person about uncertain matches. Background linking
/// cannot, so it only accepts candidates at the resolver's calibrated auto
/// threshold and leaves everything else unlinked.
class CanonicalLinkService {
  CanonicalLinkService(this._resolver);

  final CanonicalResolverService _resolver;

  Future<ResolutionContext?> prepareContext(
    String groupId, {
    List<String> listContext = const [],
  }) {
    return _resolver.prepareContext(groupId, listContext: listContext);
  }

  Future<String?> resolveHighConfidence(
    String itemName,
    String groupId, {
    List<String> listContext = const [],
    ResolutionContext? context,
  }) async {
    final result = await resolveHighConfidenceResult(
      itemName,
      groupId,
      listContext: listContext,
      context: context,
    );
    return result?.canonicalItemId;
  }

  Future<ResolveResult?> resolveHighConfidenceResult(
    String itemName,
    String groupId, {
    List<String> listContext = const [],
    ResolutionContext? context,
  }) async {
    final result = await _resolver.resolve(
      itemName,
      groupId,
      listContext: listContext,
      context: context,
    );
    return acceptedCanonicalId(result) == null ? null : result;
  }

  @visibleForTesting
  static String? acceptedCanonicalId(ResolveResult result) {
    final id = result.canonicalItemId;
    if (id == null || result.score < (result.autoThreshold ?? 0.85)) {
      return null;
    }
    return id;
  }
}
