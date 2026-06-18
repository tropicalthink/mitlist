import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'capture_preprocessor_cv_native.dart'
    if (dart.library.html) 'capture_preprocessor_cv_stub.dart';
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
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: cvResult,
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
          quality: quality,
          enhanced: false,
        );
      }
      final out = Uint8List.fromList(img.encodeJpg(_enhanceLegacy(decoded), quality: 92));
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: out,
        quality: quality,
        enhanced: true,
      );
    } catch (_) {
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: bytes,
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
