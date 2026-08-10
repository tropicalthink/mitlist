import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'capture_preprocessor_service.dart';

/// Applies image enhancement before OCR.
///
/// Portable preview enhancement runs on a worker isolate so the UI thread
/// stays responsive during capture.
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

  /// Returns a natural (non-binarized) image suitable for neural OCR engines.
  ///
  /// PP-OCRv6 is trained on natural photographs. Use this method for OCR and
  /// [enhance] only for the human-facing preview.
  Future<Uint8List> enhanceForOcr(Uint8List bytes) async {
    try {
      return await compute(_enhanceForOcrIsolate, bytes);
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

/// Top-level isolate function for [EnhancementService.enhanceForOcr].
///
/// Returns [CapturePreprocessResult.ocrBytes] — the natural (non-binarized)
/// image that neural OCR engines should receive.
Uint8List _enhanceForOcrIsolate(Uint8List bytes) {
  try {
    return const CapturePreprocessorService().preprocess(bytes).ocrBytes;
  } catch (_) {
    return bytes;
  }
}
