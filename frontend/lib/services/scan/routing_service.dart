import 'scan_models.dart';

/// Decision record returned by [RoutingService].
class RoutingDecision {
  final bool useOnDevice;

  /// Human-readable reason (for logging / debugging).
  final String reason;

  const RoutingDecision.onDevice(this.reason) : useOnDevice = true;
  const RoutingDecision.cloud(this.reason) : useOnDevice = false;
}

/// Decides whether to keep the result from on-device OCR or escalate to the
/// CrofAI cloud vision fallback.
///
/// Heuristics (Phase 3 baseline — no per-token confidence from ML Kit):
///  • Fewer than 2 non-trivial lines  → cloud (likely cursive or blank image)
///  • Very long lines that look like prose → cloud (probably not a grocery list)
///  • Otherwise → on-device
class RoutingService {
  RoutingDecision decide(List<OcrLine> lines, {bool isOnline = true}) {
    final substantive = lines
        .where((l) => l.text.trim().split(RegExp(r'\s+')).isNotEmpty)
        .toList();

    if (substantive.isEmpty) {
      if (!isOnline) return const RoutingDecision.onDevice('offline, keeping on-device despite empty result');
      return const RoutingDecision.cloud('no text recognised on-device');
    }

    if (substantive.length < 2 && isOnline) {
      return const RoutingDecision.cloud('too few lines recognised, possible cursive');
    }

    // If any single line is very long (>80 chars) it's likely a receipt header
    // or prose — not a simple grocery list. Hand off to CrofAI.
    final hasLongLines = substantive.any((l) => l.text.length > 80);
    if (hasLongLines && isOnline) {
      return const RoutingDecision.cloud('long lines detected, likely a receipt or recipe');
    }

    return RoutingDecision.onDevice(
        '${substantive.length} lines recognised on-device');
  }
}
