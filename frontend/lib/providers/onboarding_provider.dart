import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final hubQuickStartDismissedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('hub_quick_start_dismissed') ?? false;
});

Future<void> dismissHubQuickStart() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('hub_quick_start_dismissed', true);
}
