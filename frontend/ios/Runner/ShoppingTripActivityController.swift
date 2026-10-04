import ActivityKit
import Foundation

/// Starts, updates and ends the shopping-trip Live Activity for the
/// `me.mitlist/widgets` channel (plan 047, stage 7). One trip at a time.
@available(iOS 16.2, *)
enum ShoppingTripActivityController {
  private typealias TripActivity = Activity<ShoppingTripAttributes>

  /// Returns the activity id, or nil when Live Activities are off.
  static func start(_ args: [String: Any]) async -> String? {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
    await endAll()
    let attributes = ShoppingTripAttributes(
      householdName: args["household_name"] as? String ?? "",
      currency: args["currency"] as? String ?? "EUR")
    let state = ShoppingTripAttributes.ContentState(
      itemsLeft: int(args["items_left"]), itemsTotal: int(args["items_total"]),
      totalCents: int64(args["total_cents"]))
    do {
      let activity = try TripActivity.request(
        attributes: attributes, content: ActivityContent(state: state, staleDate: nil), pushType: nil)
      return activity.id
    } catch {
      return nil
    }
  }

  static func update(_ args: [String: Any]) async {
    for activity in TripActivity.activities {
      var state = activity.content.state
      if args["items_left"] != nil { state.itemsLeft = int(args["items_left"]) }
      if args["items_total"] != nil { state.itemsTotal = int(args["items_total"]) }
      if args["total_cents"] != nil { state.totalCents = int64(args["total_cents"]) }
      await activity.update(ActivityContent(state: state, staleDate: nil))
    }
  }

  /// Ends the trip. With a basket total and an expense link, the final
  /// "Add expense €xx" state stays on the Lock Screen for an hour; a trip
  /// left unfinished, or finished without prices, disappears at once.
  static func end(_ args: [String: Any]) async {
    let totalCents = int64(args["total_cents"])
    let expenseURL = (args["add_expense_url"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    for activity in TripActivity.activities {
      guard totalCents > 0, let expenseURL else {
        await activity.end(nil, dismissalPolicy: .immediate)
        continue
      }
      var state = activity.content.state
      state.totalCents = totalCents
      state.finished = true
      state.itemsLeft = 0
      state.addExpenseURL = expenseURL
      await activity.end(
        ActivityContent(state: state, staleDate: nil),
        dismissalPolicy: .after(Date().addingTimeInterval(60 * 60)))
    }
  }

  /// Removes every trip at once (sign-out, or a new trip).
  static func endAll() async {
    for activity in TripActivity.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private static func int(_ value: Any?) -> Int {
    (value as? NSNumber)?.intValue ?? 0
  }

  private static func int64(_ value: Any?) -> Int64 {
    (value as? NSNumber)?.int64Value ?? 0
  }
}
