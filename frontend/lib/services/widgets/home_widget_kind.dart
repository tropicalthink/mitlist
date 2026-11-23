import 'package:flutter/foundation.dart' show TargetPlatform;

/// The home screen widgets mitlist ships (plans/047, C7), by the id the
/// `me.mitlist/widgets` channel uses for them.
enum HomeWidgetKind {
  shoppingList('shopping_list'),
  chores('chores'),
  quickAdd('quick_add'),
  household('household');

  const HomeWidgetKind(this.id);

  /// The id on the method channel (`installedWidgets`, `pinWidget`).
  final String id;

  static HomeWidgetKind? fromId(String id) {
    for (final kind in values) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  /// The widgets a platform offers: every kind, on both. (iOS quick add is
  /// a small square plus a Lock Screen circle; Android's is a 4x1 bar.)
  static List<HomeWidgetKind> availableOn(TargetPlatform platform) => values;

  /// The kinds among [ids] (what `installedWidgets` reported), in order.
  /// Ids this app build does not know (a newer native widget, iOS Balance or
  /// Controls if they are ever reported) are ignored.
  static List<HomeWidgetKind> parseAll(Iterable<String> ids) => [
        for (final id in ids)
          if (fromId(id) case final kind?) kind,
      ];
}
