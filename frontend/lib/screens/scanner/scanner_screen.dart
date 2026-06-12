import 'dart:async';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../providers/scan_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../services/scan_service.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../sheets/create_list_sheet.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../widgets/empty_state.dart';
import 'scan_review_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  /// Pass the current household group id to enable grocery-pipeline mode.
  final String? groupId;
  final String? userId;

  const ScannerScreen({super.key, this.groupId, this.userId});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  File? _imageFile;
  bool _isAnalyzing = false;
  String? _error;
  ScanResult? _result;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _imageFile = File(picked.path);
      _isAnalyzing = true;
      _error = null;
      _result = null;
    });

    try {
      final service = await ref.read(scanServiceProviderAsync.future);
      final bytes = await _imageFile!.readAsBytes();
      final result = await service.scanImage(bytes, 'image/jpeg');

      if (!mounted) return;
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\u2019t analyze the image. Please try again with a clearer photo.';
        _isAnalyzing = false;
      });
    }
  }

  /// Grocery-intelligence pipeline: runs on-device OCR + canonical resolution
  /// then pushes to the [ScanReviewScreen].
  Future<void> _scanGroceryList(ImageSource source) async {
    final groupId = widget.groupId;
    final userId = widget.userId;
    if (groupId == null || userId == null) {
      // Fall back to the generic scanner if context is not provided.
      unawaited(_pickImage(source));
      return;
    }

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = Uint8List.fromList(await File(picked.path).readAsBytes());
      final pipeline = await ref.read(scanPipelineProvider.future);
      final connectivity = ref.read(connectivityServiceProvider);
      final isOnline = await connectivity.isOnline();

      final result = await pipeline.run(
        imageBytes: bytes,
        groupId: groupId,
        isOnline: isOnline,
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
        _error = 'Couldn\u2019t process the image. Please try again.';
        _isAnalyzing = false;
      });
    }
  }

  void _useResult() {
    if (_result == null) return;

    switch (_result!.type) {
      case 'list':
        _openListCreation();
      case 'receipt':
        _openExpenseCreation();
      case 'recipe':
        _openRecipeCreation();
      case 'chore':
        _openChoreCreation();
    }
  }

  void _openListCreation() async {
    final r = _result!;
    final created = await CreateListSheet.show(
      context,
      initialName: r.title,
    );
    if (mounted && (created == true)) {
      context.pop();
    }
  }

  void _openExpenseCreation() async {
    final r = _result!;
    String? amountStr;
    if (r.amount != null && r.amount! > 0) {
      amountStr = (r.amount! / 100).toStringAsFixed(2);
    }
    final created = await ExpenseCreationSheet.show(
      context,
      initialDescription: r.title,
      initialAmount: amountStr,
      receiptImage: _imageFile,
    );
    if (mounted && (created == true)) {
      context.pop();
    }
  }

  void _openRecipeCreation() async {
    final r = _result!;
    final ingredients = r.items.isNotEmpty
        ? r.items.map((i) => i.name).join('\n')
        : null;
    final steps = r.steps.isNotEmpty ? r.steps.join('\n') : null;
    final created = await context.pushNamed<bool>(
      'recipeCreate',
      extra: {
        'initialTitle': r.title,
        'initialIngredients': ingredients,
        'initialSteps': steps,
      },
    );
    if (mounted && (created == true)) {
      context.pop();
    }
  }

  void _openChoreCreation() async {
    final r = _result!;
    final description = r.steps.isNotEmpty
        ? r.steps.join('\n')
        : null;
    final created = await ChoreCreationSheet.show(
      context,
      initialTitle: r.title,
      initialDescription: description,
    );
    if (mounted && (created == true)) {
      context.pop();
    }
  }

  void _showSourcePicker({bool groceryMode = false}) {
    final onCamera = groceryMode
        ? () { Navigator.of(context).pop(); _scanGroceryList(ImageSource.camera); }
        : () { Navigator.of(context).pop(); _pickImage(ImageSource.camera); };
    final onGallery = groceryMode
        ? () { Navigator.of(context).pop(); _scanGroceryList(ImageSource.gallery); }
        : () { Navigator.of(context).pop(); _pickImage(ImageSource.gallery); };

    showAppBottomSheet<void>(
      context: context,
      title: groceryMode ? 'Scan grocery list' : 'Add scan',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const AppIcon(name: 'devicePhoneMobile'),
            title: const Text('Take a photo'),
            onTap: onCamera,
          ),
          ListTile(
            leading: const AppIcon(name: 'eye'),
            title: const Text('Choose from gallery'),
            onTap: onGallery,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Scanner',
        showStandardActions: false,
        leading: IconButton(
          icon: AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        children: [
          // Image preview area
          if (_imageFile != null)
            AppCard(
              child: Image.file(
                _imageFile!,
                fit: BoxFit.contain,
                height: 256,
                width: double.infinity,
              ),
            )
          else
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
                    'Scan a receipt, list, recipe,\nor chore reminder',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: MitlistSpacing.md),

          // Analyze / pick buttons
          if (_isAnalyzing)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.lg),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: MitlistSpacing.md),
                    Text('Analyzing…'),
                  ],
                ),
              ),
            )
          else if (_result == null) ...[
            AppButton(
              text: _imageFile != null ? 'Analyze this image' : 'Take a photo or choose one',
              icon: _imageFile == null
                  ? AppIcon(name: 'devicePhoneMobile',
                      color: Theme.of(context).colorScheme.onPrimary)
                  : AppIcon(name: 'magnifyingGlass',
                      color: Theme.of(context).colorScheme.onPrimary),
              onPressed: _imageFile != null
                  ? () => _pickImage(ImageSource.gallery)
                  : _showSourcePicker,
            ),
            if (widget.groupId != null) ...[
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                text: 'Scan grocery list',
                variant: AppButtonVariant.outline,
                icon: const AppIcon(name: 'shoppingCart'),
                onPressed: () => _showSourcePicker(groceryMode: true),
              ),
            ],
          ],

          if (_imageFile != null && _result == null && !_isAnalyzing) ...[
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: 'Pick different image',
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              onPressed: _showSourcePicker,
            ),
          ],

          if (_error != null)
            AppEmptyState(
              title: _error!,
              icon: const AppIcon(name: 'alertCircleOutline'),
              isError: true,
              paddingPreset: AppEmptyStatePadding.md,
              actions: [
                AppButton(
                  text: 'Retry',
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),

          // Result preview
          if (_result != null) ...[
            const SizedBox(height: MitlistSpacing.md),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    final textTheme = Theme.of(context).textTheme;
    final typeLabel = switch (r.type) {
      'receipt' => 'Receipt',
      'list' => 'Shopping list',
      'recipe' => 'Recipe',
      'chore' => 'Chore',
      _ => r.type,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                name: 'checkCircle',
                size: MitlistSpacing.space6,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Text(
                'Detected: $typeLabel',
                style: textTheme.titleMedium,
              ),
            ],
          ),
          if (r.title != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              r.title!,
              style: textTheme.headlineSmall,
            ),
          ],
          if (r.items.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.md),
            Text(
              '${r.items.length} item${r.items.length == 1 ? '' : 's'}',
              style: textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            ...r.items.take(8).map((item) {
              var label = item.name;
              if (item.quantity != null && item.quantity!.isNotEmpty) {
                label = '${item.quantity}${item.unit != null ? ' ${item.unit}' : ''} $label';
              }
              String? priceLabel;
              if (item.priceCents != null && item.priceCents! > 0) {
                priceLabel =
                    '\$${(item.priceCents! / 100).toStringAsFixed(2)}';
              }
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: MitlistSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (priceLabel != null)
                      Text(
                        priceLabel,
                        style: MitlistTypography.monoBody(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              );
            }),
            if (r.items.length > 8)
              Text(
                '…and ${r.items.length - 8} more',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          if (r.steps.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.md),
            Text(
              '${r.steps.length} step${r.steps.length == 1 ? '' : 's'}',
              style: textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            ...r.steps.take(5).map((step) => Padding(
                  padding: const EdgeInsets.only(
                      bottom: MitlistSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.steps.indexOf(step) + 1}. ',
                        style: MitlistTypography.labelXSmall(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step,
                          style: textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (r.amount != null && r.amount! > 0) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              'Total: \$${(r.amount! / 100).toStringAsFixed(2)}',
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: MitlistSpacing.lg),
          AppButton(
            text: switch (r.type) {
              'list' => 'Add to lists',
              'receipt' => 'Create expense',
              'recipe' => 'Create recipe',
              'chore' => 'Create chore',
              _ => 'Use this',
            },
            onPressed: _useResult,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            text: 'Scan again',
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            onPressed: () => setState(() {
              _imageFile = null;
              _result = null;
              _error = null;
            }),
          ),
        ],
      ),
    );
  }
}
