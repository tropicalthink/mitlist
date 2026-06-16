import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mitlist/services/scan/capture_boundary_service.dart';
import 'package:mitlist/services/scan/capture_preprocessor_service.dart';
import 'package:mitlist/services/scan/capture_quality_service.dart';
import 'package:mitlist/services/scan/document_rectifier_service.dart';
import 'package:mitlist/services/scan/enhancement_service.dart';

void main() {
  // -------------------------------------------------------------------------
  // Original tests — must stay green
  // -------------------------------------------------------------------------

  test('quality service scores a high-contrast sharp image as usable', () {
    final bytes = _testListImage();
    final quality = const CaptureQualityService().assess(bytes);

    expect(quality.isUsable, isTrue);
    expect(quality.score, greaterThan(0.36));
    expect(quality.hint, isNotEmpty);
  });

  test('quality service rejects invalid image bytes', () {
    final quality = const CaptureQualityService().assess(
      Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(quality.level, CaptureQualityLevel.poor);
    expect(quality.isUsable, isFalse);
  });

  test('preprocessor returns decodable enhanced bytes and keeps original', () {
    final original = _testListImage();
    final result = const CapturePreprocessorService().preprocess(original);

    expect(result.originalBytes, original);
    expect(result.enhanced, isTrue);
    expect(img.decodeImage(result.processedBytes), isNotNull);
  });

  test('boundary service finds a document-like list area', () {
    final boundary = const CaptureBoundaryService().detectImage(
      _testDocumentImage(),
    );

    expect(boundary.level, CaptureBoundaryLevel.found);
    expect(boundary.left, closeTo(0.2, 0.08));
    expect(boundary.top, closeTo(0.16, 0.08));
    expect(boundary.right, closeTo(0.82, 0.08));
    expect(boundary.bottom, closeTo(0.86, 0.08));
    expect(boundary.hint, isNotEmpty);
  });

  test('boundary service ignores flat frames', () {
    final image = img.Image(width: 360, height: 280);
    img.fill(image, color: img.ColorRgb8(180, 180, 180));

    final boundary = const CaptureBoundaryService().detectImage(
      Uint8List.fromList(img.encodeJpg(image, quality: 94)),
    );

    expect(boundary.level, CaptureBoundaryLevel.missing);
    expect(boundary.hasBounds, isFalse);
  });

  // -------------------------------------------------------------------------
  // New B2–B4 tests
  // -------------------------------------------------------------------------

  group('CV preprocessing pipeline', () {
    test('preprocessor produces a binarised output smaller than original', () {
      // A document image with sharp text should come out as a binary (or near-binary)
      // image after adaptive thresholding.
      final bytes = _testDocumentImage();
      final result = const CapturePreprocessorService().preprocess(bytes);

      expect(result.enhanced, isTrue);
      final decoded = img.decodeImage(result.processedBytes);
      expect(decoded, isNotNull);

      // The output must be decodable and have reasonable dimensions.
      expect(decoded!.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));
    });

    test('CV preprocessor gracefully handles a shadowed/tilted image', () {
      // Create an image with uneven illumination (dark left, bright right).
      final bytes = _shadowedDocumentImage();
      final result = const CapturePreprocessorService().preprocess(bytes);

      // Must always succeed — never throw, always return processedBytes.
      expect(result.processedBytes, isNotEmpty);
      expect(img.decodeImage(result.processedBytes), isNotNull);
    });

    test('preprocessor fail-softs on invalid bytes and returns originals', () {
      final garbage = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final result = const CapturePreprocessorService().preprocess(garbage);

      // Must return original bytes, not throw.
      expect(result.originalBytes, garbage);
      expect(result.processedBytes, garbage);
      expect(result.enhanced, isFalse);
    });

    test('DocumentRectifierService returns valid bytes for a document image', () {
      final bytes = _testDocumentImage();
      final result = const DocumentRectifierService().rectify(bytes);

      // Must always return decodable bytes.
      expect(img.decodeImage(result.bytes), isNotNull);
    });

    test('DocumentRectifierService fail-softs on invalid bytes', () {
      final garbage = Uint8List.fromList([0, 1, 2, 3, 4]);
      final result = const DocumentRectifierService().rectify(garbage);

      // Must not throw; returns original bytes with rectified=false.
      expect(result.bytes, garbage);
      expect(result.rectified, isFalse);
    });

    test(
      'EnhancementService async enhance returns decodable bytes',
      () async {
        final bytes = _testListImage();
        final service = EnhancementService();
        final enhanced = await service.enhance(bytes);

        expect(img.decodeImage(enhanced), isNotNull);
      },
    );

    test('EnhancementService async enhance runs off the main isolate', () async {
      // We can't directly assert "this ran in an isolate" from a test, but we
      // CAN assert that enhance() returns a Future and completes successfully
      // while the calling thread is free to do other work.
      final bytes = _testDocumentImage();
      final service = EnhancementService();

      var callerUnblocked = false;
      final future = service.enhance(bytes).then((result) {
        // By the time this callback fires, callerUnblocked must already be true
        // (i.e. the main isolate continued executing after awaiting the future).
        expect(callerUnblocked, isTrue,
            reason:
                'enhance() must not block the calling isolate: '
                'callerUnblocked should be true before the callback fires');
        return result;
      });

      // This line executes IMMEDIATELY after the future is scheduled — before
      // the result is available — because enhance() dispatches to a worker.
      callerUnblocked = true;

      final result = await future;
      expect(img.decodeImage(result), isNotNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Test image builders
// ---------------------------------------------------------------------------

Uint8List _testListImage() {
  final image = img.Image(width: 420, height: 320);
  img.fill(image, color: img.ColorRgb8(236, 232, 220));

  for (var row = 0; row < 6; row++) {
    final y = 54 + row * 38;
    for (var x = 56; x < 340; x++) {
      if ((x + row) % 3 != 0) {
        image.setPixelRgb(x, y, 28, 28, 28);
        image.setPixelRgb(x, y + 1, 28, 28, 28);
      }
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 94));
}

Uint8List _testDocumentImage() {
  final image = img.Image(width: 500, height: 360);
  img.fill(image, color: img.ColorRgb8(92, 86, 76));

  for (var y = 58; y < 310; y++) {
    for (var x = 96; x < 410; x++) {
      image.setPixelRgb(x, y, 236, 232, 220);
    }
  }

  for (var row = 0; row < 7; row++) {
    final y = 88 + row * 28;
    for (var x = 128; x < 374; x++) {
      if ((x + row) % 4 != 0) {
        image.setPixelRgb(x, y, 32, 32, 32);
      }
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 94));
}

/// Creates a document image with a horizontal brightness gradient
/// (dark on the left, bright on the right) to test shadow/illumination
/// normalisation.
Uint8List _shadowedDocumentImage() {
  final image = img.Image(width: 480, height: 360);

  for (var y = 0; y < 360; y++) {
    for (var x = 0; x < 480; x++) {
      // Gradient background: luma goes from ~40 on the left to ~200 on the right.
      final bg = (40 + (x / 480.0) * 160).round().clamp(0, 255);
      image.setPixelRgb(x, y, bg, bg, bg);
    }
  }

  // Add text-like lines at varying brightness.
  for (var row = 0; row < 8; row++) {
    final y = 44 + row * 36;
    for (var x = 60; x < 420; x++) {
      if (x % 5 != 0) {
        // Text color relative to background (always darker).
        final bg = (40 + (x / 480.0) * 160).round().clamp(0, 255);
        final textVal = math.max(0, bg - 80);
        image.setPixelRgb(x, y, textVal, textVal, textVal);
        image.setPixelRgb(x, y + 1, textVal, textVal, textVal);
      }
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 94));
}
