import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much bigger or smaller the person wants every bit of text, on top of
/// whatever the OS text scaler already asks for.
enum TextSizeOption {
  small(0.9),
  defaultSize(1.0),
  large(1.15),
  extraLarge(1.3);

  const TextSizeOption(this.scale);

  /// The multiplier applied on top of the platform text scaler.
  final double scale;

  static TextSizeOption fromName(String? name) {
    for (final option in values) {
      if (option.name == name) return option;
    }
    return TextSizeOption.defaultSize;
  }
}

/// The text size the person picked. Persisted.
final textSizeProvider =
    StateNotifierProvider<TextSizeNotifier, TextSizeOption>(
  (ref) => TextSizeNotifier(),
);

class TextSizeNotifier extends StateNotifier<TextSizeOption> {
  TextSizeNotifier() : super(TextSizeOption.defaultSize) {
    _load();
  }

  static const _key = 'text_size';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = TextSizeOption.fromName(prefs.getString(_key));
      if (mounted) state = loaded;
    } catch (_) {}
  }

  Future<void> set(TextSizeOption option) async {
    state = option;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, option.name);
    } catch (_) {}
  }
}

/// Whether the whole text theme renders in heavier weights. Persisted.
final boldTextProvider = StateNotifierProvider<BoldTextNotifier, bool>(
  (ref) => BoldTextNotifier(),
);

class BoldTextNotifier extends StateNotifier<bool> {
  BoldTextNotifier() : super(false) {
    _load();
  }

  static const _key = 'bold_text';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = prefs.getBool(_key) ?? false;
      if (mounted) state = loaded;
    } catch (_) {}
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {}
  }
}
