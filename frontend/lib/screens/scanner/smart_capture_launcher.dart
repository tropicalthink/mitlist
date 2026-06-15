import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../services/scan/capture_preprocessor_service.dart';
import 'live_smart_capture_screen.dart';
import 'smart_capture_screen.dart';

Future<SmartCaptureResult?> pickSmartCapture(
  BuildContext context, {
  required ImageSource source,
  String? title,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final resolvedTitle = title ?? l10n.smartCaptureLaunchTitle;
  if (source == ImageSource.camera) {
    return Navigator.of(context).push<SmartCaptureResult>(
      MaterialPageRoute(
        builder: (_) => LiveSmartCaptureScreen(title: resolvedTitle),
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
        title: resolvedTitle,
        originalPath: picked.path,
        originalBytes: processed.originalBytes,
        processedBytes: processed.processedBytes,
        quality: processed.quality,
      ),
    ),
  );
}
