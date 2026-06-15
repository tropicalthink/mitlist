import 'dart:typed_data';

import 'capture_preprocessor_service.dart';

/// Applies light image enhancement before OCR: grayscale + contrast boost.
/// Returns the original bytes unchanged if decoding fails.
class EnhancementService {
  final CapturePreprocessorService _preprocessor;

  EnhancementService({
    CapturePreprocessorService preprocessor =
        const CapturePreprocessorService(),
  }) : _preprocessor = preprocessor;

  Uint8List enhance(Uint8List bytes) {
    try {
      return _preprocessor.preprocess(bytes).processedBytes;
    } catch (_) {
      return bytes;
    }
  }
}
