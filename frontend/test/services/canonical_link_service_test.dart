import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/services/scan/canonical_link_service.dart';
import 'package:mitlist/services/scan/canonical_resolver_service.dart';

void main() {
  group('CanonicalLinkService acceptance', () {
    test('accepts a candidate at its calibrated auto threshold', () {
      const result = ResolveResult(
        canonicalItemId: 'milk',
        displayName: 'Milk',
        score: 0.91,
        autoThreshold: 0.91,
      );

      expect(CanonicalLinkService.acceptedCanonicalId(result), 'milk');
    });

    test('rejects a candidate below its calibrated auto threshold', () {
      const result = ResolveResult(
        canonicalItemId: 'milk',
        displayName: 'Milk',
        score: 0.90,
        autoThreshold: 0.91,
      );

      expect(CanonicalLinkService.acceptedCanonicalId(result), isNull);
    });

    test('uses the conservative default when calibration is absent', () {
      const uncertain = ResolveResult(
        canonicalItemId: 'milk',
        displayName: 'Milk',
        score: 0.84,
      );
      const confident = ResolveResult(
        canonicalItemId: 'milk',
        displayName: 'Milk',
        score: 0.85,
      );

      expect(CanonicalLinkService.acceptedCanonicalId(uncertain), isNull);
      expect(CanonicalLinkService.acceptedCanonicalId(confident), 'milk');
    });
  });
}
