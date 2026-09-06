import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/accent.dart';
import 'billing_provider.dart' show supporterPerksProvider;

/// The accent the person picked. Persisted; may name an accent they are not
/// entitled to (the pack was refunded, say), which is why the theme reads
/// [effectiveAccentProvider] instead.
final accentProvider = StateNotifierProvider<AccentNotifier, MitlistAccent>(
  (ref) => AccentNotifier(),
);

/// The accent the theme actually renders: the chosen one when the supporter
/// perks are unlocked, otherwise the default. Keeping the choice and the
/// entitlement apart means a lapsed supporter gets their colour back the
/// moment they are one again, without picking it a second time.
final effectiveAccentProvider = Provider<MitlistAccent>((ref) {
  final chosen = ref.watch(accentProvider);
  if (chosen.isFree) return chosen;
  return ref.watch(supporterPerksProvider)
      ? chosen
      : MitlistAccent.defaultAccent;
});

class AccentNotifier extends StateNotifier<MitlistAccent> {
  AccentNotifier() : super(MitlistAccent.defaultAccent) {
    _load();
  }

  static const _key = 'accent';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = MitlistAccent.fromName(prefs.getString(_key));
      if (mounted) state = loaded;
    } catch (_) {}
  }

  Future<void> set(MitlistAccent accent) async {
    state = accent;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, accent.name);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_key, raw);
    state = mode;
  }
}
