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
    relative.unitsStyle = .short
    return String(localized: "Updated \(relative.localizedString(for: date, relativeTo: now))")
  }
}

/// How urgent a chore is, judged in the device's time zone. Both platforms
/// use the same rule (plan 047 design rules):
/// - overdue: due on an earlier day than today;
/// - today: due today;
/// - soon: due later, or the server says `due_soon`.
/// Without `due_at` the server's `due_status` decides. "Due" means overdue
/// or today; soon chores are listed but never counted as due.
public enum ChoreUrgency: Int, Comparable {
  case overdue = 0
  case today = 1
  case soon = 2

  public static func < (a: ChoreUrgency, b: ChoreUrgency) -> Bool { a.rawValue < b.rawValue }
}

public struct ChoreCounts: Equatable {
  public var overdue = 0
  public var today = 0
  public var soon = 0

  public init(overdue: Int = 0, today: Int = 0, soon: Int = 0) {
    self.overdue = overdue
    self.today = today
    self.soon = soon
  }

  public var due: Int { overdue + today }
}

public enum WidgetChores {
  public static func urgency(_ chore: WidgetChore, now: Date = Date(), calendar: Calendar = .current) -> ChoreUrgency {
    guard let due = chore.dueDate else {
      switch chore.dueStatus {
      case "overdue": return .overdue
      case "due_today": return .today
      default: return .soon
      }
    }
    let today = calendar.startOfDay(for: now)
    let dueDay = calendar.startOfDay(for: due)
    if dueDay < today { return .overdue }
    if dueDay == today { return .today }
    return .soon
  }

  /// Overdue, then today, then soon; within each, mine first, then by
  /// `due_at` (earliest first, chores without one last), then server order.
  public static func ordered(_ chores: [WidgetChore], now: Date = Date(), calendar: Calendar = .current) -> [WidgetChore] {
    chores.enumerated().sorted { a, b in
      let ua = urgency(a.element, now: now, calendar: calendar)
      let ub = urgency(b.element, now: now, calendar: calendar)
      if ua != ub { return ua < ub }
      if a.element.isMine != b.element.isMine { return a.element.isMine }
      let da = a.element.dueDate ?? .distantFuture
      let db = b.element.dueDate ?? .distantFuture
      if da != db { return da < db }
      return a.offset < b.offset
    }.map(\.element)
  }

  /// Counts by urgency. Chores marked done on the widget do not count.
  public static func counts(_ chores: [WidgetChore], now: Date = Date(), calendar: Calendar = .current) -> ChoreCounts {
    var counts = ChoreCounts()
    for chore in chores where !chore.done {
      switch urgency(chore, now: now, calendar: calendar) {
      case .overdue: counts.overdue += 1
      case .today: counts.today += 1
      case .soon: counts.soon += 1
      }
    }
    return counts
  }
}

extension WidgetFormat {
  /// The text label of a chore's urgency (never colour alone).
  public static func urgencyLabel(_ chore: WidgetChore, now: Date = Date(), calendar: Calendar = .current) -> String {
    due(chore, now: now, calendar: calendar)
  }

  /// "2 overdue · 1 due today", "3 coming up" or "Nothing due". Each number
  /// counts exactly what its words say.
  public static func choreSummary(_ counts: ChoreCounts) -> String {
    var parts: [String] = []
    if counts.overdue > 0 { parts.append(String(localized: "\(counts.overdue) overdue")) }
    if counts.today > 0 { parts.append(String(localized: "\(counts.today) due today")) }
    if parts.isEmpty && counts.soon > 0 { parts.append(String(localized: "\(counts.soon) coming up")) }
    if parts.isEmpty { return String(localized: "Nothing due") }
    return parts.joined(separator: " · ")
  }

  /// The household's single most urgent fact first: "2 overdue · 7 to buy".
  public static func householdLead(_ counts: ChoreCounts, openItems: Int) -> String {
    var parts: [String] = []
    if counts.overdue > 0 {
      parts.append(String(localized: "\(counts.overdue) overdue"))
    } else if counts.today > 0 {
      parts.append(String(localized: "\(counts.today) due today"))
    }
    if openItems > 0 { parts.append(String(localized: "\(openItems) to buy")) }
    if parts.isEmpty { return String(localized: "All done for today") }
    return parts.joined(separator: " · ")
  }
}
