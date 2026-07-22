import 'dart:typed_data';

import 'ppocr_inference_native.dart'
    if (dart.library.html) 'ppocr_inference_stub.dart';
import 'scan_models.dart';

/// Cross-platform, fully offline PP-OCRv6 service.
///
/// Android and iOS use the same bundled detector, recognizer, ONNX Runtime CPU
/// execution, and Dart pre/post-processing implementation.
class OcrService {
  OcrService() : _inference = PpOcrInference();

  final PpOcrInference _inference;

  Future<List<OcrLine>> recognise(Uint8List imageBytes) =>
      _inference.recognise(imageBytes);

  Future<List<OcrLine>> recogniseFromPath(String path) =>
      _inference.recogniseFromPath(path);

  Future<void> dispose() => _inference.dispose();
}
