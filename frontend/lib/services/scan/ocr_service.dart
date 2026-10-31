import 'dart:typed_data';

import 'ppocr_inference_native.dart'
    if (dart.library.html) 'ppocr_inference_stub.dart';
import 'ppocr_processor.dart' show OcrLexiconEntry;
import 'scan_models.dart';

/// Cross-platform, fully offline PP-OCRv6 service.
///
/// Android and iOS use the same bundled detector, recognizer, ONNX Runtime CPU
/// execution, and Dart pre/post-processing implementation.
class OcrService {
  OcrService() : _inference = PpOcrInference();

  final PpOcrInference _inference;

  /// Reads [imageBytes]. A [OcrPageKind.list] prefers the household's own
  /// words in [lexicon] wherever the pixels support them; a
  /// [OcrPageKind.document] is read as it stands.
  Future<List<OcrLine>> recognise(
    Uint8List imageBytes, {
    List<OcrLexiconEntry> lexicon = const [],
    OcrPageKind kind = OcrPageKind.list,
  }) =>
      _inference.recognise(imageBytes, lexicon: lexicon, kind: kind);

  Future<List<OcrLine>> recogniseFromPath(String path) =>
      _inference.recogniseFromPath(path);

  Future<void> dispose() => _inference.dispose();
}
