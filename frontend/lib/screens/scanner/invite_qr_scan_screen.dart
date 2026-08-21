import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../utils/invite_link.dart';

/// Full-screen camera scanner for household invite QR codes, so joining never
/// requires leaving the app for the system camera. Pops with the extracted
/// invite code as soon as a QR carrying one is recognized; every other barcode
/// is ignored and scanning simply continues.
class InviteQrScanScreen extends StatefulWidget {
  const InviteQrScanScreen({super.key});

  /// Opens the scanner and resolves with the invite code, or `null` when the
  /// person backs out without scanning one.
  static Future<String?> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const InviteQrScanScreen(),
      ),
    );
  }

  @override
  State<InviteQrScanScreen> createState() => _InviteQrScanScreenState();
}

class _InviteQrScanScreenState extends State<InviteQrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final code = extractInviteCode(raw);
      if (code == null) continue;
      _handled = true;
      unawaited(Haptics.success());
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(MitlistSpacing.xl),
                child: Text(
                  l10n.joinScanCameraError,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Viewfinder frame — purely visual; detection uses the full preview.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.sm,
                    vertical: MitlistSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          l10n.joinScanTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flashlight_on_rounded,
                            color: Colors.white),
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.xl),
                  child: Text(
                    l10n.joinScanHint,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
