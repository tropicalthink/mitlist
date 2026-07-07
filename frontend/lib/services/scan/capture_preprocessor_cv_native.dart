import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Returns the CV-processed (binarized/deskewed) JPEG bytes for [jpegBytes],
/// or `null` on any CV failure.
///
/// Native (OpenCV / dart:ffi) implementation. The web stub always returns null.
Uint8List? enhanceCv(Uint8List jpegBytes) {
  final src = cv.imdecode(jpegBytes, cv.IMREAD_COLOR);
  if (src.isEmpty) {
    src.dispose();
    return null;
  }

  try {
    final result = _runCvPipeline(src);
    try {
      final (_, encoded) = cv.imencode(
        '.jpg',
        result,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 92]),
      );
      return encoded;
    } finally {
      result.dispose();
    }
  } finally {
    src.dispose();
  }
}

cv.Mat _runCvPipeline(cv.Mat src) {
  final scratch = <cv.Mat>[];
  void track(cv.Mat m) => scratch.add(m);
  cv.Mat? result;
  try {
    // Step 1 – Downscale if too large (keeps memory/speed manageable).
    final downscaled = _maybeDownscale(src, maxDim: 2200);
    if (!identical(downscaled, src)) track(downscaled);

    // Step 2 – Grayscale.
    final gray = cv.cvtColor(downscaled, cv.COLOR_BGR2GRAY);
    track(gray);

    // Step 3 – Illumination normalisation.
    // Divide the gray image by a heavily blurred version (background estimate).
    // This suppresses uneven lighting and shadow gradients without OCR impact.
    final illuminNorm = _normaliseIllumination(gray);
    track(illuminNorm);

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
      track(binarised);
    } catch (_) {
      // Adaptive threshold failed (e.g. already binary); keep illumination
      // normalised grayscale.
      result = illuminNorm.clone();
      return result;
    }

    // Step 5 – Deskew.
    final deskewed = _deskew(binarised);
    result = deskewed;
    return deskewed;
  } finally {
    for (final m in scratch) {
      // Do not dispose the Mat we are returning.
      if (!identical(m, result)) {
        try {
          m.dispose();
        } catch (_) {}
      }
    }
  }
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
  final scratch = <cv.Mat>[];
  void track(cv.Mat m) => scratch.add(m);
  cv.Mat? result;
  try {
    final cv.Mat bg;
    try {
      bg = cv.gaussianBlur(gray, (kernelSize, kernelSize), 0);
    } catch (_) {
      result = gray.clone();
      return result;
    }
    track(bg);

    // Convert both to float32 for accurate division.
    // CV_32FC1 = single-channel 32-bit float.
    final grayF = gray.convertTo(cv.MatType.CV_32FC1);
    track(grayF);
    final bgF = bg.convertTo(cv.MatType.CV_32FC1);
    track(bgF);

    // Add 1.0 to every background pixel to prevent divide-by-zero.
    // convertScaleAbs(alpha=1, beta=1) → bgF_u8 + 1; then convert back to float.
    final bgAbs = cv.convertScaleAbs(bgF, alpha: 1, beta: 1);
    track(bgAbs);
    final bgFplus1 = bgAbs.convertTo(cv.MatType.CV_32FC1);
    track(bgFplus1);

    // Divide gray by (background + 1) to flatten illumination.
    final divided = cv.divide(grayF, bgFplus1);
    track(divided);

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
    result = out;
    return out;
  } finally {
    for (final m in scratch) {
      if (!identical(m, result)) {
        try {
          m.dispose();
        } catch (_) {}
      }
    }
  }
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
