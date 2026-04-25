import 'package:flutter/services.dart';

/// Static helpers for haptic feedback.
///
/// Maps common interaction types to Flutter [HapticFeedback] calls.
class Haptics {
  const Haptics._();

  /// Light impact — suitable for checkbox toggles and subtle confirmations.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium impact — suitable for deletions and moderate interactions.
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Success feedback — uses heavy impact for a strong positive signal.
  static Future<void> success() => HapticFeedback.heavyImpact();

  /// Failure feedback — uses a vibrate pattern for errors.
  static Future<void> failure() => HapticFeedback.vibrate();
}
