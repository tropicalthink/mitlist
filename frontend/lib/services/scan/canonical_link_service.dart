import 'package:flutter/foundation.dart';

import 'canonical_resolver_service.dart';

/// Applies the conservative acceptance rule used when linking ordinary typed
/// list text to the local canonical grocery graph.
///
/// Scan review can ask a person about uncertain matches. Background linking
/// cannot, so it only accepts candidates at the resolver's calibrated auto
/// threshold and leaves everything else unlinked.
class CanonicalLinkService {
  CanonicalLinkService(this._resolver);

  final CanonicalResolverService _resolver;

  Future<String?> resolveHighConfidence(
    String itemName,
    String groupId, {
    List<String> listContext = const [],
  }) async {
    final result = await _resolver.resolve(
      itemName,
      groupId,
      listContext: listContext,
    );
    return acceptedCanonicalId(result);
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
