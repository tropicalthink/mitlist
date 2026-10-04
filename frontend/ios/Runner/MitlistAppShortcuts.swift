import AppIntents

/// Siri and Shortcuts phrases (plan 047, stage 6). String parameters cannot
/// appear in a phrase, so Siri asks "What should I add?" after it.
@available(iOS 17.0, *)
struct MitlistAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddItemIntent(),
      phrases: [
        "Add to my list in \(.applicationName)",
        "Add to my \(.applicationName) list",
        "Add to \(\.$list) in \(.applicationName)",
      ],
      shortTitle: "Add to list",
      systemImageName: "cart.badge.plus")
  }

  static var shortcutTileColor: ShortcutTileColor { .orange }
}
