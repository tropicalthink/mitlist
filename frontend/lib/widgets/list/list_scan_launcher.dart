import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart'
    show grocerySeedProvider, listRepositoryProvider;
import '../../providers/store_provider.dart';
import '../../screens/scanner/scan_review_screen.dart';
import '../../screens/scanner/smart_capture_launcher.dart';
import '../../theme/spacing.dart';
import '../app_bottom_sheet.dart';
import '../app_icon.dart';
import '../spinner.dart';

/// Picks an image, runs the on-device grocery scan pipeline, and opens
/// [ScanReviewScreen] with [listId] as the target list (skips list picker).
///
/// Returns the number of items added when [ScanReviewScreen] completes
/// successfully, or `null` if the user cancelled or no items were added.
Future<int?> launchListScan(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
  required String userId,
  required String listId,
  String? listName,
  ImageSource? source,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final pickedSource = source ?? await _pickImageSource(context);
  if (pickedSource == null || !context.mounted) return null;

  final capture = await pickSmartCapture(
    context,
    source: pickedSource,
    title: l10n.scanCheckListPhoto,
  );
  if (capture == null || !context.mounted) return null;

  if (!context.mounted) return null;
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
                Text(
                  l10n.scanReadingList,
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    },
  ));

  try {
    await ref.read(grocerySeedProvider.future);
    final pipeline = await ref.read(scanPipelineProvider.future);
    final repo = await ref.read(listRepositoryProvider.future);
    final listContextCanonicalIds = (await repo.getItemsByListOnce(listId))
        .map((item) => item.canonicalItemId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final connectivity = ref.read(connectivityServiceProvider);
    final isOnline = await connectivity.isOnline();

    final result = await pipeline.run(
      // Feed the ORIGINAL capture, not the preview-binarized bytes: the
      // pipeline's first two steps are perspective-rectify (needs the clean
      // photo to find the document quad) and enhance/binarize. Passing the
      // already-binarized preview defeated rectification (Canny on a dithered
      // binary finds no quad → no crop) and double-binarized the frame, which
      // is what produced garbage OCR. processedBytes stays for the preview UI.
      imageBytes: capture.originalBytes,
      groupId: groupId,
      storeId: ref.read(selectedStoreIdProvider),
      listContextCanonicalIds: listContextCanonicalIds,
      isOnline: isOnline,
      cropHint: capture.cropHint,
    );

    if (!context.mounted) return null;
    Navigator.of(context).pop(); // dismiss loading

    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ScanReviewScreen(
          scanResult: result,
          groupId: groupId,
          userId: userId,
          targetListId: listId,
          targetListName: listName,
        ),
      ),
    );
  } catch (e, stack) {
    // Keep the user-facing copy generic, but never lose the real cause.
    debugPrint('list scan failed: $e\n$stack');
    if (!context.mounted) return null;
    Navigator.of(context).pop(); // dismiss loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.scanCouldNotProcess),
      ),
    );
    return null;
  }
}

Future<ImageSource?> _pickImageSource(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<ImageSource>(
    context: context,
    title: l10n.scanSnapYourList,
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
