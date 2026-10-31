import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/ocr_provider.dart';
import '../../services/scan/scan_models.dart';
import '../../widgets/app_toast.dart';
import 'smart_capture_launcher.dart';
import 'smart_capture_screen.dart';

/// A photographed page and the text read from it.
class DocumentPhoto {
  const DocumentPhoto({required this.capture, required this.lines});

  final SmartCaptureResult capture;
  final List<OcrLine> lines;
}

/// Whether this device can read photos (the OCR models are not on web).
bool get canReadDocumentPhotos => !kIsWeb;

/// Takes or picks a photo of a printed page (a receipt, a recipe) and reads
/// it on the device, as written: no household vocabulary, nothing sent off
/// the phone. Returns null when the person backs out or nothing could be
/// read; the failure toast is shown here.
Future<DocumentPhoto?> captureDocumentPhoto(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String readingMessage,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final source = await pickCaptureSource(context, title: title);
  if (source == null || !context.mounted) return null;

  final capture = await pickSmartCapture(context, source: source, title: title);
  if (capture == null || !context.mounted) return null;

  showScanProgress(context, readingMessage);
  List<OcrLine> lines;
  try {
    lines = await ref.read(ocrServiceProvider).recognise(
          capture.originalBytes,
          kind: OcrPageKind.document,
        );
  } catch (e, stack) {
    debugPrint('document photo read failed: $e\n$stack');
    lines = const [];
  }
  if (!context.mounted) return null;
  Navigator.of(context).pop(); // the progress panel

  if (lines.isEmpty) {
    AppToast.error(context, l10n.scanCouldNotProcess);
    return null;
  }
  return DocumentPhoto(capture: capture, lines: lines);
}
