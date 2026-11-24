import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/scan/ocr_service.dart';

/// The one on-device OCR engine. Lists, receipts and recipes share it, so the
/// detector and recognizer are loaded into a single worker isolate once.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});
