import 'dart:typed_data';

import 'document_rectifier_cv_native.dart'
    if (dart.library.html) 'document_rectifier_cv_stub.dart';

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
}
