import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart' show listRepositoryProvider;
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
  final pickedSource = source ?? await _pickImageSource(context);
  if (pickedSource == null || !context.mounted) return null;

  final capture = await pickSmartCapture(
    context,
    source: pickedSource,
    title: 'Check list photo',
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
                  'Reading your list\u2026',
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
      imageBytes: capture.processedBytes,
      groupId: groupId,
      storeId: ref.read(selectedStoreIdProvider),
      listContextCanonicalIds: listContextCanonicalIds,
      isOnline: isOnline,
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
  } catch (_) {
    if (!context.mounted) return null;
    Navigator.of(context).pop(); // dismiss loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Couldn\u2019t process the image. Please try again.'),
      ),
    );
    return null;
  }
}

Future<ImageSource?> _pickImageSource(BuildContext context) {
  return showAppBottomSheet<ImageSource>(
    context: context,
    title: 'Snap your list',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const AppIcon(name: 'devicePhoneMobile'),
          title: const Text('Take a photo'),
          onTap: () => Navigator.of(context).pop(ImageSource.camera),
        ),
        ListTile(
          leading: const AppIcon(name: 'eye'),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.of(context).pop(ImageSource.gallery),
        ),
      ],
    ),
  );
}
