import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/services/scan/routing_service.dart';
import 'package:mitlist/services/scan/scan_models.dart';

OcrLine _line(String text) => OcrLine(text: text);

void main() {
  final service = RoutingService();

  // Helper to build a list of OcrLines from strings.
  List<OcrLine> lines(List<String> texts) => texts.map(_line).toList();

  group('allowCloud: false — always on-device', () {
    test('empty lines → on-device (not cloud)', () {
      final decision = service.decide([], isOnline: true, allowCloud: false);
      expect(decision.useOnDevice, isTrue);
      expect(decision.reason, contains('cloud scan disabled'));
    });

    test('single line (would normally go cloud) → on-device', () {
      final decision = service.decide(
        lines(['milk']),
        isOnline: true,
        allowCloud: false,
      );
      expect(decision.useOnDevice, isTrue);
    });

    test('long line >80 chars (would normally go cloud) → on-device', () {
      final longText = 'A' * 90;
      final decision = service.decide(
        lines([longText, 'eggs']),
        isOnline: true,
        allowCloud: false,
      );
      expect(decision.useOnDevice, isTrue);
    });

    test('offline + empty → on-device', () {
      final decision =
          service.decide([], isOnline: false, allowCloud: false);
      expect(decision.useOnDevice, isTrue);
    });
  });

  group('allowCloud: true — reproduces old routing behavior', () {
    test('empty lines + online → cloud', () {
      final decision =
          service.decide([], isOnline: true, allowCloud: true);
      expect(decision.useOnDevice, isFalse);
      expect(decision.reason, contains('no text recognised'));
    });

    test('empty lines + offline → on-device (even old code kept on-device when offline)', () {
      final decision =
          service.decide([], isOnline: false, allowCloud: true);
      expect(decision.useOnDevice, isTrue);
      expect(decision.reason, contains('offline'));
    });

    test('single line + online → cloud', () {
      final decision = service.decide(
        lines(['milk']),
        isOnline: true,
        allowCloud: true,
      );
      expect(decision.useOnDevice, isFalse);
      expect(decision.reason, contains('too few lines'));
    });

    test('long line >80 chars + online → cloud', () {
      final longText = 'A' * 90;
      final decision = service.decide(
        lines([longText, 'eggs']),
        isOnline: true,
        allowCloud: true,
      );
      expect(decision.useOnDevice, isFalse);
      expect(decision.reason, contains('long lines'));
    });

    test('normal multi-line → on-device', () {
      final decision = service.decide(
        lines(['milk', 'eggs']),
        isOnline: true,
        allowCloud: true,
      );
      expect(decision.useOnDevice, isTrue);
    });

    test('offline + single line → on-device (no online check passes)', () {
      final decision = service.decide(
        lines(['milk']),
        isOnline: false,
        allowCloud: true,
      );
      // isOnline is false so cloud heuristic won't fire; falls through to on-device.
      expect(decision.useOnDevice, isTrue);
    });
  });
}
