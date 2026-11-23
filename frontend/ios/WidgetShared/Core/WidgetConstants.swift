import Foundation

/// Names shared by the app, the widget extension and the Android build.
/// Plan 047, contracts C4, C5 and C7.
public enum WidgetConstants {
  public static let appGroup = "group.me.mitlist"

  /// Folder inside the App Group container that holds the snapshot and the
  /// ops queue.
  public static let directoryName = "widgets"
  public static let snapshotFileName = "snapshot.json"
  public static let pendingOpsFileName = "pending_ops.jsonl"

  public static let keychainService = "me.mitlist.widget-credential"
  public static let keychainAccount = "default"

  /// The server forgets idempotency keys after seven days, so an op older
  /// than that can no longer be replayed safely.
  public static let opMaxAge: TimeInterval = 7 * 24 * 60 * 60

  /// Response bodies larger than this are not kept on a delivered op.
  public static let maxStoredResponseBytes = 16 * 1024

  /// Older data is labelled "Updated 20 minutes ago" in the widget.
  public static let staleAfter: TimeInterval = 15 * 60

  /// A timeline reload fetches a new snapshot when the last fetch is older
  /// than this. Reloads come from WidgetKit pushes, the app, the timeline
  /// backstop and widget taps, and the system budgets them, so a short
  /// threshold costs little and makes a push actually show new data.
  public static let refetchOnReloadAfter: TimeInterval = 60

  /// How long a row ticked on the widget stays on it, ticked and struck
  /// through, unless a refresh replaces it first.
  public static let tickFeedbackDuration: TimeInterval = 10 * 60

  /// The smallest touch target for any control on a widget (plan 047
  /// design rules).
  public static let minTouchTarget: Double = 44

  public static let channelName = "me.mitlist/widgets"
}

/// Widget kinds (C7). Changing one orphans every widget a user has placed.
public enum WidgetKinds {
  public static let shoppingList = "ShoppingListWidget"
  public static let chores = "ChoresWidget"
  public static let householdToday = "HouseholdTodayWidget"
  public static let balance = "BalanceWidget"
  public static let quickAdd = "QuickAddWidget"
  public static let addItemControl = "AddItemControl"
  public static let scanReceiptControl = "ScanReceiptControl"

  /// The `installedWidgets` channel name of a placed widget's kind, or nil
  /// for kinds the channel does not report (balance, controls).
  public static func channelKind(_ kind: String) -> String? {
    switch kind {
    case shoppingList: return "shopping_list"
    case chores: return "chores"
    case quickAdd: return "quick_add"
    case householdToday: return "household"
    default: return nil
    }
  }
}

/// `source` values for ops created on iOS (C2).
public enum WidgetOpSource {
  public static let widget = "ios_widget"
  public static let siri = "ios_siri"
  public static let control = "ios_control"
}

/// Links widgets open (C5). The empty host is deliberate: go_router routes
/// on the path.
public enum WidgetLinks {
  public static func list(_ listID: String, household: String?, add: Bool = false) -> URL {
    var query = [URLQueryItem]()
    if let household { query.append(URLQueryItem(name: "group", value: household)) }
    if add { query.append(URLQueryItem(name: "add", value: "1")) }
    return make("/lists/\(listID)", query)
  }

  public static func lists(household: String?) -> URL {
    make("/lists", household.map { [URLQueryItem(name: "group", value: $0)] } ?? [])
  }

  public static func chores(household: String?) -> URL {
    make("/chores", household.map { [URLQueryItem(name: "group", value: $0)] } ?? [])
  }

  public static func money(household: String?, add: Bool = false, amountCents: Int64? = nil) -> URL {
    var query = [URLQueryItem]()
    if let household { query.append(URLQueryItem(name: "group", value: household)) }
    if add { query.append(URLQueryItem(name: "add", value: "1")) }
    if let amountCents { query.append(URLQueryItem(name: "amount_cents", value: String(amountCents))) }
    return make("/money", query)
  }

  public static func home(household: String?) -> URL {
    make("/home", household.map { [URLQueryItem(name: "group", value: $0)] } ?? [])
  }

  public static var scanner: URL { make("/scanner", []) }

  /// The app's Widgets page: where set-up states send people.
  public static var widgetsSetup: URL { make("/you/widgets", []) }

  private static func make(_ path: String, _ query: [URLQueryItem]) -> URL {
    var components = URLComponents()
    components.scheme = "mitlist"
    components.host = ""
    components.path = path
    if !query.isEmpty { components.queryItems = query }
    // URLComponents with an empty host renders "mitlist:///path".
    return components.url ?? URL(string: "mitlist:///home")!
  }
}
