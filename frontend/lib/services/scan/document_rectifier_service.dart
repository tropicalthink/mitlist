import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'document_rectifier_cv_native.dart'
    if (dart.library.html) 'document_rectifier_cv_stub.dart';

/// Whether the boundary-crop fallback is active.
///
/// Defaults to FALSE — this flag stays off until Step-7 device verification
/// confirms the [sensorOrientation] rotation mapping is correct on the target
/// device. With this false, [DocumentRectifierService.rectifyWithHint] returns
/// exactly what [rectify()] returns: zero change to production scan behaviour.
const bool kEnableBoundaryCrop = false;

/// An isolate-sendable value type carrying the live-detected capture boundary.
///
/// Coordinates are normalized [0,1] over the camera stream plane
/// (sensor-native, usually landscape). [sensorOrientation] is the degrees
/// the JPEG is rotated clockwise relative to the stream (0, 90, 180, or 270).
class CaptureCropHint {
  const CaptureCropHint({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.sensorOrientation,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// Sensor orientation in degrees (0 | 90 | 180 | 270).
  final int sensorOrientation;
}

/// Maps a stream-space normalized rect into JPEG-space normalized rect.
///
/// For a back camera, the captured JPEG is the stream rotated clockwise by
/// [CaptureCropHint.sensorOrientation] degrees. A normalized point (x, y) in
/// [0,1]² rotated clockwise maps as:
///   0°  → (x, y)
///   90° → (1−y, x)
///   180°→ (1−x, 1−y)
///   270°→ (y, 1−x)
({double l, double t, double r, double b}) mapStreamRectToImage(
    CaptureCropHint h) {
  ({double x, double y}) rot(double x, double y) =>
      switch (h.sensorOrientation % 360) {
        90 => (x: 1 - y, y: x),
        180 => (x: 1 - x, y: 1 - y),
        270 => (x: y, y: 1 - x),
        _ => (x: x, y: y),
      };
  final p1 = rot(h.left, h.top);
  final p2 = rot(h.right, h.bottom);
  return (
    l: math.min(p1.x, p2.x),
    t: math.min(p1.y, p2.y),
    r: math.max(p1.x, p2.x),
    b: math.max(p1.y, p2.y),
  );
}

/// Crops [jpegBytes] to the normalized rect (in the JPEG's own coordinates)
/// with [pad] fraction of padding on each side.
///
/// Returns null on any error, degenerate rect, or when the crop would cover
/// nearly the whole frame (in which case cropping provides no benefit).
Uint8List? cropToNormalizedRect(
  Uint8List jpegBytes, {
  required double l,
  required double t,
  required double r,
  required double b,
  double pad = 0.06,
}) {
  try {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) return null;
    final lp = (l - pad).clamp(0.0, 1.0);
    final tp = (t - pad).clamp(0.0, 1.0);
    final rp = (r + pad).clamp(0.0, 1.0);
    final bp = (b + pad).clamp(0.0, 1.0);
    final boxW = rp - lp;
    final boxH = bp - tp;
    if (boxW < 0.25 || boxH < 0.25) return null; // too small → likely noise
    if (boxW > 0.97 && boxH > 0.97) return null; // ~whole frame → no benefit
    final x = (lp * decoded.width).round();
    final y = (tp * decoded.height).round();
    final w = (boxW * decoded.width).round();
    final h = (boxH * decoded.height).round();
    if (w < 32 || h < 32) return null;
    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  } catch (_) {
    return null;
  }
}

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
///
/// On web, OpenCV is unavailable; this always returns the original bytes with
/// [DocumentRectifyResult.rectified] == false.
class DocumentRectifierService {
  const DocumentRectifierService();

  DocumentRectifyResult rectify(Uint8List jpegBytes) {
    try {
      final warped = rectifyDocumentCv(jpegBytes);
      if (warped == null) {
        return DocumentRectifyResult(bytes: jpegBytes, rectified: false);
      }
      return DocumentRectifyResult(bytes: warped, rectified: true);
    } catch (_) {
      return DocumentRectifyResult(bytes: jpegBytes, rectified: false);
    }
  }

  /// Runs [rectify], and when it finds no document quad AND a [hint] is
  /// provided AND [kEnableBoundaryCrop] is true, falls back to cropping the
  /// image to the live-detected boundary.
  ///
  /// With [kEnableBoundaryCrop] == false (the shipped default), this method
  /// returns exactly what [rectify()] returns — zero change to production
  /// scan behaviour. Enable only after Step-7 device verification confirms
  /// the sensorOrientation mapping.
  DocumentRectifyResult rectifyWithHint(Uint8List jpegBytes,
      CaptureCropHint? hint) {
    final result = rectify(jpegBytes); // existing quad path, unchanged
    if (!kEnableBoundaryCrop || result.rectified || hint == null) return result;
    final m = mapStreamRectToImage(hint);
    final cropped =
        cropToNormalizedRect(jpegBytes, l: m.l, t: m.t, r: m.r, b: m.b);
    if (cropped == null) return result; // fail-soft → original frame
    return DocumentRectifyResult(bytes: cropped, rectified: true);
  }
}
