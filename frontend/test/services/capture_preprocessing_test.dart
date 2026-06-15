import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mitlist/services/scan/capture_boundary_service.dart';
import 'package:mitlist/services/scan/capture_preprocessor_service.dart';
import 'package:mitlist/services/scan/capture_quality_service.dart';

void main() {
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
}

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
