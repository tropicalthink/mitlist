import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/confidence_service.dart';
import 'package:mitlist/services/scan/scan_models.dart';

void main() {
  test('uses supplied calibrated thresholds when assigning confidence', () {
    final service = ConfidenceService();

    expect(
      service.level(0.8, autoThreshold: 0.75, reviewThreshold: 0.4),
      ConfidenceLevel.autoAccept,
    );
    expect(
      service.level(0.8, autoThreshold: 0.9, reviewThreshold: 0.4),
      ConfidenceLevel.review,
    );
    expect(
      service.level(0.35, autoThreshold: 0.9, reviewThreshold: 0.4),
      ConfidenceLevel.ask,
    );
  });
}
