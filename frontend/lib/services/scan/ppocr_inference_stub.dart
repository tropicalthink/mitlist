import 'dart:typed_data';

import 'scan_models.dart';

class PpOcrInference {
  Future<List<OcrLine>> recognise(Uint8List imageBytes) =>
      Future.error(UnsupportedError('On-device OCR is unavailable on web.'));

  Future<List<OcrLine>> recogniseFromPath(String path) =>
      Future.error(UnsupportedError('On-device OCR is unavailable on web.'));

  Future<void> dispose() async {}
}
