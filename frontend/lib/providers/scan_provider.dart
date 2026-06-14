import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/scan_service.dart';

final scanServiceProviderAsync = FutureProvider<ScanService>((ref) async {
  return ScanService.create(ref);
});

/// Persisted toggle: whether cloud scan fallback is allowed.
/// Default is `false` (on-device only). Users can opt in via account settings.
final cloudScanProvider = StateNotifierProvider<CloudScanNotifier, bool>(
  (ref) => CloudScanNotifier(),
);

class CloudScanNotifier extends StateNotifier<bool> {
  CloudScanNotifier() : super(false) {
    _load();
  }

  static const _key = 'allow_cloud_scan';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = value;
  }
}
