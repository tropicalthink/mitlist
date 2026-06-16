import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'capture_preprocessor_service.dart';

/// Applies image enhancement before OCR.
///
/// The heavy preprocessing (illumination normalisation, adaptive threshold,
/// deskew via OpenCV) runs on a worker isolate via [compute()] so the UI
/// thread stays responsive during capture.
///
/// Returns the original bytes unchanged if decoding or enhancement fails.
class EnhancementService {
  final CapturePreprocessorService _preprocessor;

  EnhancementService({
    CapturePreprocessorService preprocessor =
        const CapturePreprocessorService(),
  }) : _preprocessor = preprocessor;

  /// Synchronous variant — kept for use inside an isolate or test contexts
  /// where [compute()] is already handled externally.
  Uint8List enhanceSync(Uint8List bytes) {
    try {
      return _preprocessor.preprocess(bytes).processedBytes;
    } catch (_) {
      return bytes;
    }
  }

  /// Asynchronous variant — runs enhancement on a worker isolate so the
  /// main/UI isolate is never blocked by the CV hot loops.
  Future<Uint8List> enhance(Uint8List bytes) async {
    try {
      return await compute(_enhanceIsolate, bytes);
    } catch (_) {
      return bytes;
    }
  }
}

/// Top-level function required by [compute()] — must be a free function or
/// static method so Dart can spawn it in a fresh isolate.
Uint8List _enhanceIsolate(Uint8List bytes) {
  // [CapturePreprocessorService] is stateless so safe to instantiate here.
  try {
    return const CapturePreprocessorService().preprocess(bytes).processedBytes;
  } catch (_) {
    return bytes;
  }
}
