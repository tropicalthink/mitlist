import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'capture_quality_service.dart';

class CapturePreprocessResult {
  const CapturePreprocessResult({
    required this.originalBytes,
    required this.processedBytes,
    required this.quality,
    required this.enhanced,
  });

  final Uint8List originalBytes;
  final Uint8List processedBytes;
  final CaptureQualityResult quality;
  final bool enhanced;
}

class CapturePreprocessorService {
  const CapturePreprocessorService({
    this.qualityService = const CaptureQualityService(),
  });

  final CaptureQualityService qualityService;

  CapturePreprocessResult preprocess(Uint8List bytes) {
    final quality = qualityService.assess(bytes);
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: bytes,
        quality: quality,
        enhanced: false,
      );
    }

    final prepared = _enhance(decoded);
    final out = Uint8List.fromList(img.encodeJpg(prepared, quality: 92));
    return CapturePreprocessResult(
      originalBytes: bytes,
      processedBytes: out,
      quality: quality,
      enhanced: true,
    );
  }

  img.Image _enhance(img.Image source) {
    var image = source;
    if (source.width > 2200 || source.height > 2200) {
      image = img.copyResize(
        source,
        width: source.width >= source.height ? 2200 : null,
        height: source.height > source.width ? 2200 : null,
        interpolation: img.Interpolation.average,
      );
    }

    image = img.grayscale(image);
    image = img.adjustColor(
      image,
      contrast: 1.35,
      brightness: 1.04,
      saturation: 0,
    );
    image = _unsharpMask(image);
    return image;
  }

  img.Image _unsharpMask(img.Image image) {
    final blurred = img.gaussianBlur(image, radius: 1);
    final out = img.Image.from(image);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        final v = (p.r + ((p.r - b.r) * 0.65)).round();
        final clamped = math.max(0, math.min(255, v));
        out.setPixelRgb(x, y, clamped, clamped, clamped);
      }
    }
    return out;
  }
}
