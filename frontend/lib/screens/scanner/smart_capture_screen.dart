import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/scan/capture_quality_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';

class SmartCaptureResult {
  const SmartCaptureResult({
    required this.originalPath,
    required this.originalBytes,
    required this.processedBytes,
    required this.quality,
  });

  final String originalPath;
  final Uint8List originalBytes;
  final Uint8List processedBytes;
  final CaptureQualityResult quality;
}

class SmartCaptureScreen extends StatefulWidget {
  const SmartCaptureScreen({
    super.key,
    required this.title,
    required this.originalPath,
    required this.originalBytes,
    required this.processedBytes,
    required this.quality,
  });

  final String title;
  final String originalPath;
  final Uint8List originalBytes;
  final Uint8List processedBytes;
  final CaptureQualityResult quality;

  @override
  State<SmartCaptureScreen> createState() => _SmartCaptureScreenState();
}

class _SmartCaptureScreenState extends State<SmartCaptureScreen> {
  bool _showOriginal = false;

  void _use() {
    Navigator.of(context).pop(SmartCaptureResult(
      originalPath: widget.originalPath,
      originalBytes: widget.originalBytes,
      processedBytes: widget.processedBytes,
      quality: widget.quality,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final quality = widget.quality;
    final colorScheme = Theme.of(context).colorScheme;
    final previewBytes =
        _showOriginal ? widget.originalBytes : widget.processedBytes;
    final poor = quality.level == CaptureQualityLevel.poor;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: MitlistAppBar.titleText(
        widget.title,
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(MitlistSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline, width: 2),
                  color: colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(
                      previewBytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.md,
                0,
                MitlistSpacing.md,
                MitlistSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QualityPanel(quality: quality),
                  const SizedBox(height: MitlistSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: _showOriginal ? 'Show enhanced' : 'Original',
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          onPressed: () {
                            setState(() => _showOriginal = !_showOriginal);
                          },
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: AppButton(
                          text: poor ? 'Use anyway' : 'Use scan',
                          variant: poor
                              ? AppButtonVariant.outline
                              : AppButtonVariant.solid,
                          onPressed: _use,
                        ),
                      ),
                    ],
                  ),
                  if (poor) ...[
                    const SizedBox(height: MitlistSpacing.sm),
                    AppButton(
                      text: 'Retake',
                      color: AppButtonColor.neutral,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityPanel extends StatelessWidget {
  const _QualityPanel({required this.quality});

  final CaptureQualityResult quality;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (quality.level) {
      CaptureQualityLevel.good => MitlistColors.success600,
      CaptureQualityLevel.okay => MitlistColors.warning600,
      CaptureQualityLevel.poor => colorScheme.error,
    };
    final label = switch (quality.level) {
      CaptureQualityLevel.good => 'Ready',
      CaptureQualityLevel.okay => 'Usable',
      CaptureQualityLevel.poor => 'Retake suggested',
    };

    return Container(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline, width: 2),
        color: colorScheme.surface,
      ),
      child: Row(
        children: [
          AppIcon(name: 'documentScanner', color: color),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  quality.hint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Text(
            '${(quality.score * 100).round()}',
            style: MitlistTypography.monoBody(color: color),
          ),
        ],
      ),
    );
  }
}
