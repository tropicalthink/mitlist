#if canImport(ActivityKit)
  import ActivityKit
  import Foundation

  /// The shopping-trip Live Activity (plan 047, stage 7, C7). The app starts
  /// and updates it from the trip screen through the `me.mitlist/widgets`
  /// channel; the widget extension draws it.
  @available(iOS 16.1, *)
  public struct ShoppingTripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
      public var itemsLeft: Int
      public var itemsTotal: Int
      public var totalCents: Int64
      public var finished: Bool
      /// `mitlist:///money?…&add=1&amount_cents=…`, set when the trip ends.
      public var addExpenseURL: String?

      public init(itemsLeft: Int, itemsTotal: Int, totalCents: Int64, finished: Bool = false, addExpenseURL: String? = nil) {
        self.itemsLeft = itemsLeft
        self.itemsTotal = itemsTotal
        self.totalCents = totalCents
        self.finished = finished
        self.addExpenseURL = addExpenseURL
      }

      public var itemsDone: Int { max(0, itemsTotal - itemsLeft) }

      public var progress: Double {
        itemsTotal > 0 ? Double(itemsDone) / Double(itemsTotal) : 0
      }
    }

    public var householdName: String
    public var currency: String

    public init(householdName: String, currency: String) {
      self.householdName = householdName
      self.currency = currency
    }
  }
#endif
