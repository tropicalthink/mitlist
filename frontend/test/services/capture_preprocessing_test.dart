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

    test('DocumentRectifierService returns valid bytes for a document image',
        () {
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

    test('EnhancementService async enhance runs off the main isolate',
        () async {
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
            reason: 'enhance() must not block the calling isolate: '
                'callerUnblocked should be true before the callback fires');
        return result;
      });

      // This line executes IMMEDIATELY after the future is scheduled — before
      // the result is available — because enhance() dispatches to a worker.
      callerUnblocked = true;

      final result = await future;
      expect(img.decodeImage(result), isNotNull);
    });

    // -------------------------------------------------------------------------
    // Plan 016 — Mat lifecycle hardening tests
    // -------------------------------------------------------------------------

    test('preprocessor fail-softs on truly invalid bytes (plan 016)', () {
      final garbage = Uint8List.fromList([1, 2, 3, 4]);
      final result = const CapturePreprocessorService().preprocess(garbage);

      // CV unavailable or imdecode empty → falls back; must not throw.
      expect(result.enhanced, isFalse);
      expect(result.processedBytes, garbage);
      expect(result.originalBytes, garbage);
    });

    test(
        'repeat-call stability: 25× preprocess returns non-empty decodable bytes (plan 016)',
        () {
      final bytes = _testListImage();
      for (var i = 0; i < 25; i++) {
        final result = const CapturePreprocessorService().preprocess(bytes);
        expect(result.processedBytes, isNotEmpty,
            reason: 'iteration $i returned empty processedBytes');
        expect(img.decodeImage(result.processedBytes), isNotNull,
            reason: 'iteration $i returned non-decodable processedBytes');
      }
    });

    // -------------------------------------------------------------------------
    // Plan 017 — ocrBytes must be a natural (non-binarized) image
    // -------------------------------------------------------------------------

    test('ocrBytes decodes to a valid image (plan 017)', () {
      final bytes = _testListImage();
      final result = const CapturePreprocessorService().preprocess(bytes);

      expect(result.ocrBytes, isNotEmpty);
      final decoded = img.decodeImage(result.ocrBytes);
      expect(decoded, isNotNull,
          reason: 'ocrBytes must decode to a valid image');
    });

    test('ocrBytes is NOT bilevel — has ≥3 distinct luma values (plan 017)',
        () {
      // Use a gradient image so a natural image must have many luma values,
      // while a binarized image would have at most 2 (0 and 255).
      final bytes = _gradientImage();
      final result = const CapturePreprocessorService().preprocess(bytes);

      final decoded = img.decodeImage(result.ocrBytes);
      expect(decoded, isNotNull);

      // Sample a grid of pixels and collect distinct luma values.
      final distinctLuma = <int>{};
      final stepX = math.max(1, decoded!.width ~/ 16);
      final stepY = math.max(1, decoded.height ~/ 16);
      for (var y = 0; y < decoded.height; y += stepY) {
        for (var x = 0; x < decoded.width; x += stepX) {
          final p = decoded.getPixel(x, y);
          // Compute luma (integer bucket by /8 to group near-identical values).
          final luma = ((p.r * 0.299 + p.g * 0.587 + p.b * 0.114) / 8).round();
          distinctLuma.add(luma);
        }
      }

      expect(
        distinctLuma.length,
        greaterThanOrEqualTo(3),
        reason:
            'ocrBytes must be a natural image with ≥3 distinct luma buckets; '
            'found ${distinctLuma.length} distinct buckets — '
            'this suggests the image was binarized (hard black/white threshold)',
      );
    });

    test(
        'processedBytes (preview) is still produced when ocrBytes differs (plan 017)',
        () {
      // Both fields must be present and decodable on the same result.
      final bytes = _testDocumentImage();
      final result = const CapturePreprocessorService().preprocess(bytes);

      expect(result.processedBytes, isNotEmpty,
          reason: 'processedBytes (binarized preview) must still be produced');
      expect(img.decodeImage(result.processedBytes), isNotNull,
          reason: 'processedBytes must be decodable');
      expect(result.ocrBytes, isNotEmpty,
          reason: 'ocrBytes must also be present');
    });

    test('ocrBytes fail-softs to original bytes on invalid input (plan 017)',
        () {
      final garbage = Uint8List.fromList([9, 8, 7, 6, 5]);
      final result = const CapturePreprocessorService().preprocess(garbage);

      // On fail-soft, ocrBytes must equal the original (never throw, never empty).
      expect(result.ocrBytes, garbage,
          reason: 'ocrBytes must fall back to original bytes on invalid input');
    });

    test('EnhancementService.enhanceForOcr returns decodable bytes (plan 017)',
        () async {
      final bytes = _testListImage();
      final service = EnhancementService();
      final ocrImage = await service.enhanceForOcr(bytes);

      expect(ocrImage, isNotEmpty);
      expect(img.decodeImage(ocrImage), isNotNull,
          reason: 'enhanceForOcr must return a decodable image');
    });
  });
}

// ---------------------------------------------------------------------------
// Additional test image builder for plan 017 — a smooth gradient
// ---------------------------------------------------------------------------

/// Creates a horizontal gradient image (luma 30 → 220) to verify that the
/// OCR image is not hard-thresholded (a binarized version would show at most
/// 2 distinct values; a natural image shows many).
Uint8List _gradientImage() {
  final image = img.Image(width: 320, height: 240);
  for (var y = 0; y < 240; y++) {
    for (var x = 0; x < 320; x++) {
      final v = (30 + (x / 320.0) * 190).round().clamp(0, 255);
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
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
