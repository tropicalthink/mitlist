import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../l10n/app_localizations.dart';
import 'widget_snapshot_sync.dart';

/// Long-press app icon shortcuts (plans/047, stage 6): Add item, Scan, Log
/// expense, Chores today. iOS shows at most four. Each opens a C5 link, so a
/// shortcut lands exactly where the matching widget link would.
class AppShortcuts {
  AppShortcuts({QuickActions? quickActions, bool? isSupported})
      : _quickActions = quickActions ?? const QuickActions(),
        _supported = isSupported ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS));

  static const addItem = 'add_item';
  static const scan = 'scan';
  static const logExpense = 'log_expense';
  static const choresToday = 'chores_today';

  final QuickActions _quickActions;
  final bool _supported;
  WidgetDefaults? _defaults;
  bool _initialized = false;

  /// Routes a shortcut tap to [open] with its location. Call once.
  Future<void> initialize(void Function(String location) open) async {
    if (!_supported || _initialized) return;
    _initialized = true;
    try {
      await _quickActions
          .initialize((type) => open(locationFor(type, _defaults)));
    } catch (_) {
      // A launcher without shortcut support is not an error.
    }
  }

  /// Publishes the shortcuts in the current language, pointing "Add item"
  /// at [defaults] when known.
  Future<void> update(AppLocalizations l10n, {WidgetDefaults? defaults}) async {
    if (!_supported) return;
    if (defaults != null) _defaults = defaults;
    try {
      await _quickActions.setShortcutItems([
        ShortcutItem(type: addItem, localizedTitle: l10n.shortcutAddItem),
        ShortcutItem(type: scan, localizedTitle: l10n.shortcutScan),
        ShortcutItem(type: logExpense, localizedTitle: l10n.shortcutLogExpense),
        ShortcutItem(
            type: choresToday, localizedTitle: l10n.shortcutChoresToday),
      ]);
    } catch (_) {}
  }

  /// Signed out: no shortcuts into a household.
  Future<void> clear() async {
    if (!_supported) return;
    _defaults = null;
    try {
      await _quickActions.clearShortcutItems();
    } catch (_) {}
  }

  /// The C5 link a shortcut opens.
  static String locationFor(String type, WidgetDefaults? defaults) {
    final household = defaults?.householdId;
    final group = household == null ? '' : 'group=$household';
    String withQuery(String path, [String extra = '']) {
      final parts = [if (group.isNotEmpty) group, if (extra.isNotEmpty) extra];
      return parts.isEmpty ? path : '$path?${parts.join('&')}';
    }

    switch (type) {
      case addItem:
        final list = defaults?.listId;
        return list == null
            ? withQuery('/lists')
            : withQuery('/lists/$list', 'add=1');
      case scan:
        return '/scanner';
      case logExpense:
        return withQuery('/money', 'add=1');
      case choresToday:
        return withQuery('/chores');
    }
    return '/home';
  }
}
