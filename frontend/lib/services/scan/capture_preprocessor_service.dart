import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'capture_preprocessor_cv_native.dart'
    if (dart.library.html) 'capture_preprocessor_cv_stub.dart';
import 'capture_quality_service.dart';

/// Runs [CapturePreprocessorService.preprocess] on a background isolate so
/// the heavy CV work (decode, adaptive threshold, Hough deskew) never blocks
/// the UI thread. On web, [compute] degrades to running in place.
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

  /// Binarized + deskewed image — used for the human-facing enhanced preview.
  final Uint8List processedBytes;

  /// Natural (non-binarized) image for OCR — the rectified/original image.
  ///
  /// Modern neural OCR engines (ML Kit, etc.) are trained on natural
  /// photographs; feeding them a hard binary image is out-of-distribution and
  /// degrades recognition quality. This field carries the non-binarized form
  /// so [ScanPipelineService] can pass a natural image to OCR while the
  /// preview still uses the binarized [processedBytes].
  final Uint8List ocrBytes;

  final CaptureQualityResult quality;
  final bool enhanced;
}

/// Preprocesses a captured image frame before OCR.
///
/// Pipeline (each step is fail-soft; any CV exception falls back to the
/// previous result rather than crashing):
///
/// 1. Quality assessment (always runs, never throws to caller).
/// 2. Downscale if >2200 px on the long edge.
/// 3. Grayscale conversion.
/// 4. Illumination normalisation — divide by a heavily blurred version to
///    suppress shadow gradients.
/// 5. Adaptive threshold (Gaussian, 11-pixel block, C=4) → binary image.
/// 6. Deskew — estimate dominant text angle via HoughLinesP on the binary
///    image and rotate to correct it (limited to ±10°).
///
/// If any CV step throws, the last successfully processed image is used.
/// If even grayscale fails, the original JPEG bytes are returned.
///
/// On web, OpenCV is unavailable; the legacy pure-Dart path (grayscale /
/// contrast / unsharp mask) is used instead.
class CapturePreprocessorService {
  const CapturePreprocessorService({
    this.qualityService = const CaptureQualityService(),
  });

  final CaptureQualityService qualityService;

  /// Entry point — synchronous, but callers should run this inside
  /// [compute()] to keep the main isolate free (see [EnhancementService]).
  CapturePreprocessResult preprocess(Uint8List bytes) {
    final quality = qualityService.assess(bytes);

    Uint8List? cvResult;
    try {
      cvResult = enhanceCv(bytes); // opencv on native, null on web/failure
    } catch (_) {
      // Native library unavailable or CV failed — fall through to legacy path.
    }
    if (cvResult != null) {
      // ocrBytes: feed OCR the original (non-binarized) bytes so the neural
      // OCR engine sees a natural image rather than a hard binary threshold.
      // processedBytes: keep the binarized result for the enhanced preview.
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: cvResult,
        ocrBytes: bytes,
        quality: quality,
        enhanced: true,
      );
    }

    // Legacy pure-Dart fallback (also the web path).
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
      // In the legacy path the enhanced image is a natural grayscale (no binary
      // threshold), so it is safe to use directly for OCR.
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: out,
        ocrBytes: out,
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
  // Legacy fallback pipeline (image package — no OpenCV)
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
