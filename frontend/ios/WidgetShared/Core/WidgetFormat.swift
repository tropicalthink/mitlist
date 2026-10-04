import Foundation

/// User-visible text derived from snapshot data. Strings resolve through
/// the target's `Localizable.xcstrings` (en, de, fr, es).
public enum WidgetFormat {
  /// Money in the household's currency, e.g. "€12.00".
  public static func money(_ cents: Int64, currency: String, locale: Locale = .current) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = locale
    formatter.currencyCode = currency.isEmpty ? nil : currency
    let amount = NSDecimalNumber(value: cents).dividing(by: 100)
    return formatter.string(from: amount) ?? "\(currency) \(amount)"
  }

  /// When a chore is due, judged in the device's time zone (the server's
  /// `due_status` uses UTC).
  public static func due(_ chore: WidgetChore, now: Date = Date(), calendar: Calendar = .current) -> String {
    guard let due = chore.dueDate else {
      switch chore.dueStatus {
      case "overdue": return String(localized: "Overdue")
      case "due_today": return String(localized: "Today")
      default: return String(localized: "Soon")
      }
    }
    let today = calendar.startOfDay(for: now)
    let dueDay = calendar.startOfDay(for: due)
    if dueDay < today { return String(localized: "Overdue") }
    if dueDay == today { return String(localized: "Today") }
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), dueDay == tomorrow {
      return String(localized: "Tomorrow")
    }
    let weekday = DateFormatter()
    weekday.calendar = calendar
    weekday.locale = .current
    weekday.setLocalizedDateFormatFromTemplate("EEE")
    return weekday.string(from: due)
  }

  public static func isOverdue(_ chore: WidgetChore, now: Date = Date(), calendar: Calendar = .current) -> Bool {
    guard let due = chore.dueDate else { return chore.dueStatus == "overdue" }
    return calendar.startOfDay(for: due) < calendar.startOfDay(for: now)
  }

  /// "Next: Alex, Thu"-style rotation hint, nil when the server sent none.
  public static func next(_ chore: WidgetChore) -> String? {
    guard let name = chore.nextAssigneeName, !name.isEmpty else { return nil }
    return String(localized: "Next: \(name)")
  }

  /// One line for a household balance.
  public static func balanceLine(_ balance: WidgetBalance?) -> String {
    guard let balance, balance.netCents != 0 else { return String(localized: "All settled") }
    let settle = balance.settleCents ?? abs(balance.netCents)
    let amount = money(settle, currency: balance.currency)
    if let name = balance.settleWithName, !name.isEmpty {
      return balance.netCents < 0
        ? String(localized: "You owe \(name) \(amount)")
        : String(localized: "\(name) owes you \(amount)")
    }
    let net = money(abs(balance.netCents), currency: balance.currency)
    return balance.netCents < 0 ? String(localized: "You owe \(net)") : String(localized: "You're owed \(net)")
  }

  /// "Updated 20 minutes ago", or nil while the data is fresh.
  public static func updated(_ date: Date?, now: Date = Date()) -> String? {
    guard let date, now.timeIntervalSince(date) > WidgetConstants.staleAfter else { return nil }
    let relative = RelativeDateTimeFormatter()
    relative.unitsStyle = .full
    return String(localized: "Updated \(relative.localizedString(for: date, relativeTo: now))")
  }
}
