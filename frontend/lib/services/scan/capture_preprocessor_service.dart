import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;

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
      final processed = _enhanceWithCv(bytes);
      return CapturePreprocessResult(
        originalBytes: bytes,
        processedBytes: processed,
        quality: quality,
        enhanced: true,
      );
    } catch (_) {
      // CV entirely failed — try the legacy image-package path.
    }

    // Legacy fallback.
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
      final prepared = _enhanceLegacy(decoded);
      final out = Uint8List.fromList(img.encodeJpg(prepared, quality: 92));
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
  // CV pipeline (OpenCV via opencv_dart / dartcv4)
  // ---------------------------------------------------------------------------

  Uint8List _enhanceWithCv(Uint8List jpegBytes) {
    final src = cv.imdecode(jpegBytes, cv.IMREAD_COLOR);
    if (src.isEmpty) throw StateError('imdecode returned empty Mat');

    try {
      final result = _runCvPipeline(src);
      final (_, encoded) = cv.imencode(
        '.jpg',
        result,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 92]),
      );
      result.dispose();
      return encoded;
    } finally {
      src.dispose();
    }
  }

  cv.Mat _runCvPipeline(cv.Mat src) {
    // Step 1 – Downscale if too large (keeps memory/speed manageable).
    final downscaled = _maybeDownscale(src, maxDim: 2200);

    // Step 2 – Grayscale.
    final cv.Mat gray;
    try {
      gray = cv.cvtColor(downscaled, cv.COLOR_BGR2GRAY);
    } finally {
      if (!identical(downscaled, src)) downscaled.dispose();
    }

    // Step 3 – Illumination normalisation.
    // Divide the gray image by a heavily blurred version (background estimate).
    // This suppresses uneven lighting and shadow gradients without OCR impact.
    final illuminNorm = _normaliseIllumination(gray);
    gray.dispose();

    // Step 4 – Adaptive threshold → binary image suitable for OCR.
    final cv.Mat binarised;
    try {
      binarised = cv.adaptiveThreshold(
        illuminNorm,
        255,
        cv.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv.THRESH_BINARY,
        11,
        4,
      );
    } catch (_) {
      // Adaptive threshold failed (e.g. already binary); keep illumination
      // normalised grayscale.
      final fallback = illuminNorm.clone();
      illuminNorm.dispose();
      return fallback;
    }
    illuminNorm.dispose();

    // Step 5 – Deskew.
    final deskewed = _deskew(binarised);
    binarised.dispose();

    return deskewed;
  }

  cv.Mat _maybeDownscale(cv.Mat src, {required int maxDim}) {
    final w = src.cols;
    final h = src.rows;
    if (w <= maxDim && h <= maxDim) return src;
    final scale = maxDim / math.max(w, h);
    return cv.resize(src, ((w * scale).round(), (h * scale).round()));
  }

  cv.Mat _normaliseIllumination(cv.Mat gray) {
    // Large Gaussian blur estimates the "background brightness".
    // A kernel sized to ~1/8 of the shorter edge (min 31×31, always odd)
    // captures slow illumination gradients while leaving text edges intact.
    final kernelSize = _nearestOdd(math.min(gray.rows, gray.cols) ~/ 8, min: 31);
    final cv.Mat bg;
    try {
      bg = cv.gaussianBlur(gray, (kernelSize, kernelSize), 0);
    } catch (_) {
      return gray.clone();
    }

    // Convert both to float32 for accurate division.
    // CV_32FC1 = single-channel 32-bit float.
    final grayF = gray.convertTo(cv.MatType.CV_32FC1);
    final bgF = bg.convertTo(cv.MatType.CV_32FC1);
    bg.dispose();

    // Add 1.0 to every background pixel to prevent divide-by-zero.
    // convertScaleAbs(alpha=1, beta=1) → bgF_u8 + 1; then convert back to float.
    final bgAbs = cv.convertScaleAbs(bgF, alpha: 1, beta: 1);
    final bgFplus1 = bgAbs.convertTo(cv.MatType.CV_32FC1);
    bgF.dispose();
    bgAbs.dispose();

    // Divide gray by (background + 1) to flatten illumination.
    final divided = cv.divide(grayF, bgFplus1);
    grayF.dispose();
    bgFplus1.dispose();

    // Normalise the ratio to full 0–255 uint8 range using NORM_MINMAX.
    // dtype = CV_8UC1.value = 0 (single-channel 8-bit unsigned).
    final out = cv.Mat.empty();
    cv.normalize(
      divided,
      out,
      alpha: 0,
      beta: 255,
      normType: cv.NORM_MINMAX,
      dtype: cv.MatType.CV_8UC1.value,
    );
    divided.dispose();
    return out;
  }

  /// Returns the nearest odd integer >= [value], but at least [min].
  int _nearestOdd(int value, {int min = 3}) {
    var v = math.max(value, min);
    if (v % 2 == 0) v++;
    return v;
  }

  /// Estimates the dominant text angle in a binary image via Hough line
  /// detection and rotates to correct skew (capped at ±10° to avoid
  /// over-rotation on non-text scenes).
  cv.Mat _deskew(cv.Mat binary) {
    const maxSkewDeg = 10.0;

    try {
      // Use a working copy at up to 800px to speed up Hough.
      final workScale = 800.0 / math.max(binary.rows, binary.cols);
      final working = workScale < 1.0
          ? cv.resize(
              binary,
              (
                (binary.cols * workScale).round(),
                (binary.rows * workScale).round()
              ),
            )
          : binary.clone();

      // Invert so text is white on black (better for Hough).
      final inverted = cv.bitwiseNOT(working);
      working.dispose();

      final lines = cv.HoughLinesP(
        inverted,
        1,
        math.pi / 180,
        50, // accumulator threshold
        minLineLength: 40,
        maxLineGap: 8,
      );
      inverted.dispose();

      if (lines.rows == 0) {
        lines.dispose();
        return binary.clone();
      }

      // Compute median angle of near-horizontal lines (likely text baselines).
      final angles = <double>[];
      for (var i = 0; i < lines.rows; i++) {
        final x1 = lines.at<int>(i, 0);
        final y1 = lines.at<int>(i, 1);
        final x2 = lines.at<int>(i, 2);
        final y2 = lines.at<int>(i, 3);
        if (x2 == x1) continue;
        final angle = math.atan2(
              (y2 - y1).toDouble(),
              (x2 - x1).toDouble(),
            ) *
            (180.0 / math.pi);
        // Keep only near-horizontal lines (|angle| < 45°).
        if (angle.abs() < 45.0) angles.add(angle);
      }
      lines.dispose();

      if (angles.isEmpty) return binary.clone();
      angles.sort();
      final medianAngle = angles[angles.length ~/ 2];

      // Cap correction — avoid over-rotating on non-text content.
      if (medianAngle.abs() > maxSkewDeg) return binary.clone();

      // Rotate around image centre.
      final cx = binary.cols / 2.0;
      final cy = binary.rows / 2.0;
      final M = cv.getRotationMatrix2D(cv.Point2f(cx, cy), medianAngle, 1.0);
      final rotated = cv.warpAffine(
        binary,
        M,
        (binary.cols, binary.rows),
        borderMode: cv.BORDER_REPLICATE,
      );
      M.dispose();
      return rotated;
    } catch (_) {
      return binary.clone();
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
