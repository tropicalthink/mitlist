import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/scan/capture_preprocessor_service.dart';
import 'live_smart_capture_screen.dart';
import 'smart_capture_screen.dart';

Future<SmartCaptureResult?> pickSmartCapture(
  BuildContext context, {
  required ImageSource source,
  String title = 'Check scan',
}) async {
  if (source == ImageSource.camera) {
    return Navigator.of(context).push<SmartCaptureResult>(
      MaterialPageRoute(
        builder: (_) => LiveSmartCaptureScreen(title: title),
      ),
    );
  }

  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: source,
    maxWidth: 2200,
    maxHeight: 2200,
    imageQuality: 96,
  );
  if (picked == null || !context.mounted) return null;

  final originalBytes =
      Uint8List.fromList(await File(picked.path).readAsBytes());
  final processed =
      const CapturePreprocessorService().preprocess(originalBytes);
  if (!context.mounted) return null;

  return Navigator.of(context).push<SmartCaptureResult>(
    MaterialPageRoute(
      builder: (_) => SmartCaptureScreen(
        title: title,
        originalPath: picked.path,
        originalBytes: processed.originalBytes,
        processedBytes: processed.processedBytes,
        quality: processed.quality,
      ),
    ),
  );
}
