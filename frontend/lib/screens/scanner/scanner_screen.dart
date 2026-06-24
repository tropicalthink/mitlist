import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart' show grocerySeedProvider;
import '../../providers/store_provider.dart';
import '../../theme/spacing.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/store_picker_sheet.dart';
import '../../l10n/app_localizations.dart';
import 'scan_review_screen.dart';
import 'smart_capture_launcher.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  /// Pass the current household group id to enable grocery-pipeline mode.
  final String? groupId;
  final String? userId;

  const ScannerScreen({super.key, this.groupId, this.userId});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _isAnalyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(grocerySeedProvider);
  }

  /// Grocery-intelligence pipeline: runs on-device OCR + canonical resolution
  /// then pushes to the [ScanReviewScreen].
  Future<void> _scanGroceryList(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final groupId = widget.groupId;
    final userId = widget.userId;
    if (groupId == null || userId == null) return;

    final capture = await pickSmartCapture(
      context,
      source: source,
      title: l10n.scannerCheckGrocery,
    );
    if (capture == null || !mounted) return;

    setState(() => _isAnalyzing = true);

    try {
      final pipeline = await ref.read(scanPipelineProvider.future);
      final connectivity = ref.read(connectivityServiceProvider);
      final isOnline = await connectivity.isOnline();

      final result = await pipeline.run(
        // Original capture, not the preview-binarized bytes — the pipeline
        // rectifies (needs the clean photo to find the document quad) and
        // binarizes internally. See list_scan_launcher for the full rationale.
        imageBytes: capture.originalBytes,
        groupId: groupId,
        storeId: ref.read(selectedStoreIdProvider),
        isOnline: isOnline,
        cropHint: capture.cropHint,
      );

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanReviewScreen(
            scanResult: result,
            groupId: groupId,
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.scanCouldNotProcess;
        _isAnalyzing = false;
      });
    }
  }

  void _showSourcePicker() {
    final l10n = AppLocalizations.of(context)!;
    showAppBottomSheet<void>(
      context: context,
      title: l10n.scannerScanSheetTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const AppIcon(name: 'devicePhoneMobile'),
            title: Text(l10n.scannerTakePhoto),
            onTap: () {
              Navigator.of(context).pop();
              _scanGroceryList(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const AppIcon(name: 'eye'),
            title: Text(l10n.scannerChooseFromGallery),
            onTap: () {
              Navigator.of(context).pop();
              _scanGroceryList(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector() {
    final l10n = AppLocalizations.of(context)!;
    final selectedId = ref.watch(selectedStoreIdProvider);
    final catalog = ref.watch(storeCatalogProvider);
    final storeName = selectedId == null
        ? null
        : catalog.maybeWhen(
            data: (stores) {
              for (final s in stores) {
                if (s.id == selectedId) return s.name;
              }
              return null;
            },
            orElse: () => null,
          );
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: () => showStorePicker(context),
      child: Row(
        children: [
          AppIcon(name: 'shoppingCart', color: colorScheme.primary),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.scannerShoppingAt,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  storeName ?? l10n.scannerChooseStore,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          AppIcon(name: 'chevronRight', color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.scannerAppBarTitle,
        showStandardActions: false,
        leading: IconButton(
          icon: AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        children: [
          _buildStoreSelector(),
          const SizedBox(height: MitlistSpacing.md),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.xl,
            child: Column(
              children: [
                AppIcon(
                  name: 'eye',
                  size: MitlistSpacing.space12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: MitlistSpacing.md),
                Text(
                  l10n.scannerHintText,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),

          if (_isAnalyzing)
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: MitlistSpacing.lg),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: MitlistSpacing.md),
                    Text(l10n.scannerAnalyzing),
                  ],
                ),
              ),
            )
          else if (widget.groupId != null) ...[
            AppButton(
              text: l10n.scannerScanGrocery,
              size: AppButtonSize.xl,
              icon: AppIcon(
                name: 'camera',
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: _showSourcePicker,
            ),
          ],

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: MitlistSpacing.md),
              child: Text(
                _error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
