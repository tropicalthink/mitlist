import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'capture_quality_service.dart';

/// Runs [CapturePreprocessorService.preprocess] on a background isolate so
/// image decoding and preview enhancement never block the UI thread.
Future<CapturePreprocessResult> preprocessCaptureInBackground(
        Uint8List bytes) =>
    compute(_preprocessEntry, bytes);

CapturePreprocessResult _preprocessEntry(Uint8List bytes) =>
    const CapturePreprocessorService().preprocess(bytes);

class CapturePreprocessResult {
  const CapturePreprocessResult({
    required this.originalBytes,
    required this.processedBytes,
    required this.ocrBytes,
    required this.quality,
    required this.enhanced,
  });

  final Uint8List originalBytes;

  /// Portable grayscale enhancement used for the human-facing preview.
  final Uint8List processedBytes;

  /// Natural (non-binarized) image for OCR — the rectified/original image.
  ///
  /// PP-OCRv6 is trained on natural photographs. This is therefore kept as the
  /// original color image while [processedBytes] is preview-only.
  final Uint8List ocrBytes;

  final CaptureQualityResult quality;
  final bool enhanced;
}

/// Preprocesses a captured image frame before OCR.
///
/// Portable pipeline (each step is fail-soft):
///
/// 1. Quality assessment (always runs, never throws to caller).
/// 2. Downscale if >2200 px on the long edge.
/// 3. Grayscale, contrast, and a small unsharp mask for the preview.
///
/// OCR always receives the original color bytes and performs its own model-
/// specific normalization. No native or platform image-recognition API is
/// used.
class CapturePreprocessorService {
  const CapturePreprocessorService({
    this.qualityService = const CaptureQualityService(),
  });

  final CaptureQualityService qualityService;

  /// Entry point — synchronous, but callers should run this inside
  /// [compute()] to keep the main isolate free (see [EnhancementService]).
  CapturePreprocessResult preprocess(Uint8List bytes) {
    final quality = qualityService.assess(bytes);

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return CapturePreprocessResult(
          originalBytes: bytes,
          processedBytes: bytes,
          ocrBytes: bytes,
          quality: quality,
          enhanced: false,
        );
      }
      final out = Uint8List.fromList(
          img.encodeJpg(_enhanceLegacy(decoded), quality: 92));
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: out,
        ocrBytes: bytes,
        quality: quality,
        enhanced: true,
      );
    } catch (_) {
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: bytes,
        ocrBytes: bytes,
        quality: quality,
        enhanced: false,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Preview pipeline (package:image only)
  // ---------------------------------------------------------------------------

  img.Image _enhanceLegacy(img.Image source) {
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
