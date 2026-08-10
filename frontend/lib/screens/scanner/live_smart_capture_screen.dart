import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../services/scan/capture_boundary_service.dart';
import '../../services/scan/capture_preprocessor_service.dart';
import '../../services/scan/capture_quality_service.dart';
import '../../services/scan/document_rectifier_service.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/spinner.dart';
import 'smart_capture_screen.dart';

class LiveSmartCaptureScreen extends StatefulWidget {
  const LiveSmartCaptureScreen({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<LiveSmartCaptureScreen> createState() => _LiveSmartCaptureScreenState();
}

class _LiveSmartCaptureScreenState extends State<LiveSmartCaptureScreen>
    with WidgetsBindingObserver {
  final _qualityService = const CaptureQualityService();
  final _boundaryService = const CaptureBoundaryService();
  CameraController? _controller;
  CaptureQualityResult? _quality;
  CaptureBoundaryResult? _boundary;

  /// Sensor orientation (degrees clockwise) of the chosen back camera.
  /// Captured when the camera is selected in [_initCamera].
  int _sensorOrientation = 90;

  String? _error;
  bool _initializing = true;
  bool _capturing = false;
  bool _streaming = false;
  DateTime _lastSampleAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (_streaming) {
        unawaited(controller.stopImageStream().catchError((_) {}));
      }
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_streaming) {
        _streaming = false;
        unawaited(controller.stopImageStream().catchError((_) {}));
      }
      unawaited(controller.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initCamera());
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _error = AppLocalizations.of(context)!.liveSmartCaptureNoCamera;
          _initializing = false;
        });
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _sensorOrientation = camera.sensorOrientation;
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      setState(() => _initializing = false);
      await _startQualityStream(controller);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.liveSmartCaptureCouldNotOpen;
        _initializing = false;
      });
    }
  }

  Future<void> _startQualityStream(CameraController controller) async {
    try {
      await controller.startImageStream(_handleCameraImage);
      _streaming = true;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quality ??= CaptureQualityResult(
          level: CaptureQualityLevel.okay,
          score: 0.5,
          hint: AppLocalizations.of(context)!.liveSmartCaptureFrameList,
          sharpness: 0,
          brightness: 0.5,
          contrast: 0,
          glareRatio: 0,
        );
      });
    }
  }

  void _handleCameraImage(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastSampleAt) < const Duration(milliseconds: 450)) {
      return;
    }
    _lastSampleAt = now;
    if (image.planes.isEmpty) return;

    final plane = image.planes.first;
    final pixelStride = plane.bytesPerPixel ?? 1;
    final quality = _qualityService.assessLumaPlane(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      pixelStride: pixelStride,
    );
    final boundary = _boundaryService.detectLumaPlane(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      pixelStride: pixelStride,
    );
    if (!mounted) return;
    setState(() {
      _quality = quality;
      _boundary = boundary;
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing || !controller.value.isInitialized) {
      return;
    }
    setState(() => _capturing = true);
    try {
      if (_streaming) {
        _streaming = false;
        await controller.stopImageStream();
      }
      final file = await controller.takePicture();
      // Build a crop hint from the last detected boundary, but only when the
      // boundary was confidently found. Gallery picks use null (no live data).
      final b = _boundary;
      final hint = (b != null && b.level == CaptureBoundaryLevel.found)
          ? CaptureCropHint(
              left: b.left,
              top: b.top,
              right: b.right,
              bottom: b.bottom,
              sensorOrientation: _sensorOrientation,
            )
          : null;
      final result = await _reviewFile(file.path, cropHint: hint);
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(result);
        return;
      }
      await _startQualityStream(controller);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            AppLocalizations.of(context)!.liveSmartCaptureCouldNotCapture);
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2200,
      maxHeight: 2200,
      imageQuality: 96,
    );
    if (picked == null || !mounted) return;
    // Gallery images have no live detection — boundary stays null.
    final result = await _reviewFile(picked.path, cropHint: null);
    if (!mounted) return;
    if (result != null) Navigator.of(context).pop(result);
  }

  Future<SmartCaptureResult?> _reviewFile(String path,
      {CaptureCropHint? cropHint}) async {
    final originalBytes = Uint8List.fromList(await File(path).readAsBytes());
    final processed = await preprocessCaptureInBackground(originalBytes);
    if (!mounted) return null;
    return Navigator.of(context).push<SmartCaptureResult>(
      MaterialPageRoute(
        builder: (_) => SmartCaptureScreen(
          title: widget.title,
          originalPath: path,
          originalBytes: processed.originalBytes,
          processedBytes: processed.processedBytes,
          quality: processed.quality,
          cropHint: cropHint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final quality = _quality;
    final boundary = _boundary;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              Stack(
                fit: StackFit.expand,
                children: [
                  _CameraPreview(controller: controller),
                  _BoundaryOverlay(boundary: boundary),
                ],
              )
            else
              Center(
                child: _initializing
                    ? const AppSpinner(size: AppSpinnerSize.lg)
                    : Text(_error ?? l10n.liveSmartCaptureCameraUnavailable),
              ),
            Positioned(
              left: MitlistSpacing.md,
              top: MitlistSpacing.md,
              child: IconButton(
                icon: const AppIcon(name: 'arrowLeft'),
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              left: MitlistSpacing.md,
              right: MitlistSpacing.md,
              bottom: MitlistSpacing.md,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LiveHint(
                    quality: quality,
                    boundary: boundary,
                    error: _error,
                  ),
                  const SizedBox(height: MitlistSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: l10n.liveSmartCaptureGallery,
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          onPressed: _capturing ? null : _pickGallery,
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.md),
                      SizedBox(
                        width: 92,
                        height: 64,
                        child: AppButton(
                          text: _capturing ? '' : l10n.liveSmartCaptureScan,
                          isLoading: _capturing,
                          variant: quality?.level == CaptureQualityLevel.good
                              ? AppButtonVariant.solid
                              : AppButtonVariant.outline,
                          onPressed: ready && !_capturing ? _capture : null,
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.md),
                      Expanded(
                        child: AppButton(
                          text: l10n.smartCaptureUseAnyway,
                          variant: AppButtonVariant.ghost,
                          onPressed: ready && !_capturing ? _capture : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    final previewAspect = previewSize.height / previewSize.width;
    final screenAspect = size.width / size.height;
    return Transform.scale(
      scale: previewAspect / screenAspect,
      child: Center(
        child: CameraPreview(controller),
      ),
    );
  }
}

class _LiveHint extends StatelessWidget {
  const _LiveHint({
    required this.quality,
    required this.boundary,
    required this.error,
  });

  final CaptureQualityResult? quality;
  final CaptureBoundaryResult? boundary;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final q = quality;
    final b = boundary;
    final text = error ??
        (b?.level == CaptureBoundaryLevel.found ? q?.hint : b?.hint) ??
        q?.hint ??
        l10n.liveSmartCaptureFrameList;
    final isReady = q?.level == CaptureQualityLevel.good &&
        b?.level == CaptureBoundaryLevel.found;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            name: isReady ? 'checkCircle' : 'documentScanner',
            color: isReady ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundaryOverlay extends StatelessWidget {
  const _BoundaryOverlay({required this.boundary});

  final CaptureBoundaryResult? boundary;

  @override
  Widget build(BuildContext context) {
    final b = boundary;
    if (b == null || !b.hasBounds) return const SizedBox.shrink();

    final color = switch (b.level) {
      CaptureBoundaryLevel.found => MitlistColors.success500,
      CaptureBoundaryLevel.partial => MitlistColors.warning500,
      CaptureBoundaryLevel.missing => Theme.of(context).colorScheme.outline,
    };

    return IgnorePointer(
      child: CustomPaint(
        painter: _BoundaryPainter(boundary: b, color: color),
      ),
    );
  }
}

class _BoundaryPainter extends CustomPainter {
  const _BoundaryPainter({required this.boundary, required this.color});

  final CaptureBoundaryResult boundary;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      boundary.left * size.width,
      boundary.top * size.height,
      boundary.right * size.width,
      boundary.bottom * size.height,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final scrim = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(cutout, scrim);

    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, border);

    final corner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square;
    const len = 28.0;
    for (final p in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final xDir = p.dx == rect.left ? 1.0 : -1.0;
      final yDir = p.dy == rect.top ? 1.0 : -1.0;
      canvas.drawLine(p, Offset(p.dx + len * xDir, p.dy), corner);
      canvas.drawLine(p, Offset(p.dx, p.dy + len * yDir), corner);
    }
  }

  @override
  bool shouldRepaint(covariant _BoundaryPainter oldDelegate) {
    return oldDelegate.boundary != boundary || oldDelegate.color != color;
  }
}
