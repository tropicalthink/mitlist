import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'scan_models.dart';

/// Wraps ML Kit text recognition and produces a list of [OcrLine]s with
/// bounding box metadata. Uses the Latin script bundle (covers DE + EN).
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Recognise text in [imageBytes] (JPEG or PNG).
  /// Writes a temp file so ML Kit can use its file-path API.
  Future<List<OcrLine>> recognise(Uint8List imageBytes) async {
    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File(
        '${tmpDir.path}/scan_input_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tmpFile.writeAsBytes(imageBytes);
    try {
      return await recogniseFromPath(tmpFile.path);
    } finally {
      tmpFile.deleteSync();
    }
  }

  Future<List<OcrLine>> recogniseFromPath(String path) async {
    final input = InputImage.fromFilePath(path);
    final result = await _recognizer.processImage(input);
    return result.blocks
        .expand((block) => block.lines)
        .map((line) {
          final bb = line.boundingBox;
          return OcrLine(
            text: line.text,
            bbox: OcrBBox(
              bb.left.toDouble(),
              bb.top.toDouble(),
              bb.width.toDouble(),
              bb.height.toDouble(),
            ),
          );
        })
        .where((l) => l.text.trim().isNotEmpty)
        .toList();
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }
}
