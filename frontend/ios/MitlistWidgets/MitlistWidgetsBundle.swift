import SwiftUI
import WidgetKit

/// Picks the bundle for the running OS. `WidgetBundleBuilder` has no
/// `if/else`, and the iOS 26 push handler changes each widget's
/// configuration type, so the iOS 26 widgets live in their own bundle.
@main
enum MitlistWidgetsEntry {
  @MainActor
  static func main() {
    if #available(iOS 26.0, *) {
      MitlistWidgetsPushBundle.main()
    } else {
      MitlistWidgetsBundle.main()
    }
  }
}

/// iOS 17–25.
struct MitlistWidgetsBundle: WidgetBundle {
  var body: some Widget {
    ShoppingListWidget()
    ChoresWidget()
    HouseholdTodayWidget()
    BalanceWidget()
    ShoppingTripLiveActivity()
    if #available(iOS 18.0, *) {
      AddItemControl()
    }
    if #available(iOS 18.0, *) {
      ScanReceiptControl()
    }
  }
}

/// iOS 26+: the same widgets, refreshed by WidgetKit push (C6).
@available(iOS 26.0, *)
struct MitlistWidgetsPushBundle: WidgetBundle {
  var body: some Widget {
    PushEnabled.ShoppingList()
    PushEnabled.Chores()
    PushEnabled.HouseholdToday()
    PushEnabled.Balance()
    ShoppingTripLiveActivity()
    AddItemControl()
    ScanReceiptControl()
  }
}

@available(iOS 26.0, *)
enum PushEnabled {
  struct ShoppingList: Widget {
    var body: some WidgetConfiguration {
      ShoppingListWidget.configuration().pushHandler(MitlistWidgetPushHandler.self)
    }
  }

  struct Chores: Widget {
    var body: some WidgetConfiguration {
      ChoresWidget.configuration().pushHandler(MitlistWidgetPushHandler.self)
    }
  }

  struct HouseholdToday: Widget {
    var body: some WidgetConfiguration {
      HouseholdTodayWidget.configuration().pushHandler(MitlistWidgetPushHandler.self)
    }
  }

  struct Balance: Widget {
    var body: some WidgetConfiguration {
      BalanceWidget.configuration().pushHandler(MitlistWidgetPushHandler.self)
    }
  }
}
