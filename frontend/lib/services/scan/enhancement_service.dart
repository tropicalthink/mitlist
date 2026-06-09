import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Applies light image enhancement before OCR: grayscale + contrast boost.
/// Returns the original bytes unchanged if decoding fails.
class EnhancementService {
  Uint8List enhance(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.grayscale(decoded);
      img.adjustColor(decoded, contrast: 1.3, brightness: 1.05);
      final out = img.encodeJpg(decoded, quality: 90);
      return Uint8List.fromList(out);
    } catch (_) {
      return bytes;
    }
  }
}
