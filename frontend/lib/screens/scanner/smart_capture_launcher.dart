import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../services/scan/capture_preprocessor_service.dart';
import '../../theme/spacing.dart';
import '../../utils/inline_camera_route.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/spinner.dart';
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
    return pushInlineCamera<SmartCaptureResult>(
      context,
      builder: (_) => LiveSmartCaptureScreen(title: resolvedTitle),
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
  final processed = await preprocessCaptureInBackground(originalBytes);
  if (!context.mounted) return null;

  return Navigator.of(context).push<SmartCaptureResult>(
    MaterialPageRoute(
      builder: (_) => SmartCaptureScreen(
        title: resolvedTitle,
        originalPath: picked.path,
        originalBytes: processed.originalBytes,
        processedBytes: processed.processedBytes,
        quality: processed.quality,
        cropHint: null, // Gallery picks have no live boundary detection.
      ),
    ),
  );
}

/// Asks whether to take a photo or pick one from the gallery.
Future<ImageSource?> pickCaptureSource(
  BuildContext context, {
  required String title,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<ImageSource>(
    context: context,
    title: title,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const AppIcon(name: 'devicePhoneMobile'),
          title: Text(l10n.scanTakePhoto),
          onTap: () => Navigator.of(context).pop(ImageSource.camera),
        ),
        ListTile(
          leading: const AppIcon(name: 'eye'),
          title: Text(l10n.scanChooseFromGallery),
          onTap: () => Navigator.of(context).pop(ImageSource.gallery),
        ),
      ],
    ),
  );
}

/// A blocking "reading…" panel while a photo is read on the device. The
/// caller pops it with `Navigator.of(context).pop()` when the work is done.
void showScanProgress(BuildContext context, String message) {
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      final textTheme = Theme.of(dialogContext).textTheme;
      return PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.lg,
              vertical: MitlistSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outline, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppSpinner(size: AppSpinnerSize.lg),
                const SizedBox(height: MitlistSpacing.md),
                Text(message, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    },
  ));
}
