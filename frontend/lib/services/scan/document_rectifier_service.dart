import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Result of document quad detection and perspective rectification.
class DocumentRectifyResult {
  const DocumentRectifyResult({
    required this.bytes,
    required this.rectified,
  });

  /// Rectified (perspective-corrected) JPEG bytes, or original bytes on failure.
  final Uint8List bytes;

  /// True when the CV pipeline ran successfully and produced a warped crop.
  final bool rectified;
}

/// Detects the largest near-rectangular contour in an image and applies a
/// perspective warp to produce a flat, axis-aligned crop.
///
/// All errors are caught and trigger fail-soft: the original bytes are
/// returned with [DocumentRectifyResult.rectified] == false.
class DocumentRectifierService {
  const DocumentRectifierService();

  DocumentRectifyResult rectify(Uint8List jpegBytes) {
    try {
      return _rectify(jpegBytes);
    } catch (_) {
      return DocumentRectifyResult(bytes: jpegBytes, rectified: false);
    }
  }

  DocumentRectifyResult _rectify(Uint8List jpegBytes) {
    final scratch = <cv.Mat>[];
    void track(cv.Mat m) => scratch.add(m);
    cv.Contours? contours;
    try {
      final src = cv.imdecode(jpegBytes, cv.IMREAD_COLOR); track(src);
      if (src.isEmpty) {
        return DocumentRectifyResult(bytes: jpegBytes, rectified: false);
      }

      final h = src.rows;
      final w = src.cols;

      // Step 1 – Shrink to a working resolution to speed up contour detection.
      // We keep the original for the final warp.
      const maxDim = 800.0;
      final scale = (maxDim / math.max(w, h)).clamp(0.0, 1.0);
      final wSmall = (w * scale).round();
      final hSmall = (h * scale).round();
      final small = cv.resize(src, (wSmall, hSmall)); track(small);

      // Step 2 – Grayscale + blur + Canny.
      final gray = cv.cvtColor(small, cv.COLOR_BGR2GRAY); track(gray);
      final blurred = cv.gaussianBlur(gray, (5, 5), 0); track(blurred);
      final edges = cv.canny(blurred, 50, 150); track(edges);

      // Dilate edges slightly to close gaps.
      final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3)); track(kernel);
      final dilated = cv.dilate(edges, kernel); track(dilated);

      // Step 3 – Find contours and pick the largest one that approximates a quad.
      final (foundContours, _) = cv.findContours(
        dilated,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      contours = foundContours;

      final quad = _findDocumentQuad(contours, wSmall, hSmall);

      if (quad == null) {
        // No clear document boundary found — return unchanged.
        return DocumentRectifyResult(bytes: jpegBytes, rectified: false);
      }

      // Step 4 – Warp the ORIGINAL-resolution image using the scaled quad.
      final srcFull = cv.imdecode(jpegBytes, cv.IMREAD_COLOR);
      try {
        final warpedBytes = _warpToRect(srcFull, quad, scale, w, h);
        return DocumentRectifyResult(bytes: warpedBytes, rectified: true);
      } finally {
        srcFull.dispose();
      }
    } finally {
      contours?.dispose();
      for (final m in scratch) {
        try { m.dispose(); } catch (_) {}
      }
    }
  }

  /// Find the largest quadrilateral contour that covers a meaningful area.
  /// Returns 4 corners in [tl, tr, br, bl] order at SMALL-image scale.
  List<cv.Point2f>? _findDocumentQuad(
    cv.Contours contours,
    int width,
    int height,
  ) {
    final totalArea = width * height.toDouble();
    List<cv.Point2f>? best;
    var bestArea = totalArea * 0.10; // must cover at least 10% of frame

    for (var i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final area = cv.contourArea(contour);
      if (area < bestArea) continue;

      final perimeter = cv.arcLength(contour, true);
      final approx = cv.approxPolyDP(contour, 0.02 * perimeter, true);

      if (approx.length == 4) {
        // Valid quad.
        final pts = [for (var j = 0; j < 4; j++) approx[j]];
        final ordered = _orderQuad(
          pts.map((p) => cv.Point2f(p.x.toDouble(), p.y.toDouble())).toList(),
        );
        if (ordered != null) {
          bestArea = area;
          best = ordered;
        }
      }
    }

    return best;
  }

  /// Orders 4 points as [tl, tr, br, bl].
  List<cv.Point2f>? _orderQuad(List<cv.Point2f> pts) {
    if (pts.length != 4) return null;

    // Sort by y first to get top/bottom pairs.
    final sorted = List.of(pts)..sort((a, b) => a.y.compareTo(b.y));
    final top = [sorted[0], sorted[1]]..sort((a, b) => a.x.compareTo(b.x));
    final bottom = [sorted[2], sorted[3]]..sort((a, b) => a.x.compareTo(b.x));

    return [top[0], top[1], bottom[1], bottom[0]]; // tl, tr, br, bl
  }

  /// Warp the source image using the quad (given in small-image coordinates)
  /// back to full-image coordinates and output as JPEG.
  Uint8List _warpToRect(
    cv.Mat src,
    List<cv.Point2f> quad,
    double scale,
    int origW,
    int origH,
  ) {
    cv.VecPoint2f? srcPts;
    cv.VecPoint2f? dstPts;
    cv.Mat? M;
    cv.Mat? warped;
    try {
      // Scale quad back to full-resolution coordinates.
      final invScale = 1.0 / scale;
      srcPts = cv.VecPoint2f.fromList(
        quad.map((p) => cv.Point2f(p.x * invScale, p.y * invScale)).toList(),
      );

      // Compute the output size from the warp dimensions.
      final tl = quad[0];
      final tr = quad[1];
      final br = quad[2];
      final bl = quad[3];

      final widthA = math.sqrt(math.pow(br.x - bl.x, 2) + math.pow(br.y - bl.y, 2));
      final widthB = math.sqrt(math.pow(tr.x - tl.x, 2) + math.pow(tr.y - tl.y, 2));
      final heightA = math.sqrt(math.pow(tr.x - br.x, 2) + math.pow(tr.y - br.y, 2));
      final heightB = math.sqrt(math.pow(tl.x - bl.x, 2) + math.pow(tl.y - bl.y, 2));

      final maxWidth = math.max(widthA, widthB);
      final maxHeight = math.max(heightA, heightB);

      // Scale the output size by invScale so we work at full resolution.
      final outW = (maxWidth * invScale).round().clamp(64, origW);
      final outH = (maxHeight * invScale).round().clamp(64, origH);

      dstPts = cv.VecPoint2f.fromList([
        cv.Point2f(0, 0),
        cv.Point2f(outW.toDouble() - 1, 0),
        cv.Point2f(outW.toDouble() - 1, outH.toDouble() - 1),
        cv.Point2f(0, outH.toDouble() - 1),
      ]);

      M = cv.getPerspectiveTransform2f(srcPts, dstPts);
      warped = cv.warpPerspective(src, M, (outW, outH));

      final (_, encoded) = cv.imencode('.jpg', warped, params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 92]));
      return encoded;
    } finally {
      warped?.dispose();
      M?.dispose();
      srcPts?.dispose();
      dstPts?.dispose();
    }
  }
}
