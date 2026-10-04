import Foundation

/// The widget snapshot, schema v1 (plan 047, contract C1).
///
/// Timestamps stay strings so a snapshot round-trips byte-for-byte in
/// meaning; the `…Date` accessors parse them. Unknown keys are ignored, so
/// later optional fields never break an older extension.
public struct WidgetSnapshot: Codable, Equatable {
  public var version: Int
  public var generatedAt: String?
  public var source: String?
  public var userID: String?
  public var defaults: WidgetDefaults?
  public var households: [WidgetHousehold]

  enum CodingKeys: String, CodingKey {
    case version
    case generatedAt = "generated_at"
    case source
    case userID = "user_id"
    case defaults
    case households
  }

  public init(
    version: Int = 1, generatedAt: String? = nil, source: String? = "server", userID: String? = nil,
    defaults: WidgetDefaults? = nil, households: [WidgetHousehold] = []
  ) {
    self.version = version
    self.generatedAt = generatedAt
    self.source = source
    self.userID = userID
    self.defaults = defaults
    self.households = households
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
    generatedAt = try c.decodeIfPresent(String.self, forKey: .generatedAt)
    source = try c.decodeIfPresent(String.self, forKey: .source)
    userID = try c.decodeIfPresent(String.self, forKey: .userID)
    defaults = try c.decodeIfPresent(WidgetDefaults.self, forKey: .defaults)
    households = try c.decodeIfPresent([WidgetHousehold].self, forKey: .households) ?? []
  }

  public var generatedDate: Date? { generatedAt.flatMap(WidgetDate.parse) }

  public static func decode(_ data: Data) throws -> WidgetSnapshot {
    try JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }

  public func household(_ id: String?) -> WidgetHousehold? {
    guard let id else { return nil }
    return households.first { $0.id == id }
  }

  /// The household a widget shows: the configured one if it still exists,
  /// else the snapshot default, else the first.
  public func resolveHousehold(_ preferred: String?) -> WidgetHousehold? {
    household(preferred) ?? household(defaults?.householdID) ?? households.first
  }

  /// The list a widget shows, with its household: the configured list if it
  /// still exists, else the snapshot default, else the household's first
  /// shopping list, else its first list.
  public func resolveList(_ preferredList: String?) -> (WidgetHousehold, WidgetList)? {
    if let preferredList {
      for household in households {
        if let list = household.lists.first(where: { $0.id == preferredList }) {
          return (household, list)
        }
      }
    }
    if let defaultList = defaults?.listID, defaultList != preferredList {
      if let hit = resolveList(defaultList) { return hit }
    }
    for household in [household(defaults?.householdID)].compactMap({ $0 }) + households {
      if let list = household.lists.first(where: { $0.type == "shopping" }) ?? household.lists.first {
        return (household, list)
      }
    }
    return nil
  }
}

public struct WidgetDefaults: Codable, Equatable {
  public var householdID: String?
  public var listID: String?

  enum CodingKeys: String, CodingKey {
    case householdID = "household_id"
    case listID = "list_id"
  }

  public init(householdID: String? = nil, listID: String? = nil) {
    self.householdID = householdID
    self.listID = listID
  }
}

public struct WidgetHousehold: Codable, Equatable, Identifiable {
  public var id: String
  public var name: String
  public var lists: [WidgetList]
  public var chores: [WidgetChore]
  public var tonightMeal: WidgetMeal?
  public var balance: WidgetBalance?

  enum CodingKeys: String, CodingKey {
    case id, name, lists, chores
    case tonightMeal = "tonight_meal"
    case balance
  }

  public init(
    id: String, name: String, lists: [WidgetList] = [], chores: [WidgetChore] = [],
    tonightMeal: WidgetMeal? = nil, balance: WidgetBalance? = nil
  ) {
    self.id = id
    self.name = name
    self.lists = lists
    self.chores = chores
    self.tonightMeal = tonightMeal
    self.balance = balance
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    lists = try c.decodeIfPresent([WidgetList].self, forKey: .lists) ?? []
    chores = try c.decodeIfPresent([WidgetChore].self, forKey: .chores) ?? []
    tonightMeal = try c.decodeIfPresent(WidgetMeal.self, forKey: .tonightMeal)
    balance = try c.decodeIfPresent(WidgetBalance.self, forKey: .balance)
  }

  /// Chores that are due today or overdue, in server order (mine first).
  public var dueChores: [WidgetChore] {
    chores.filter { $0.dueStatus == "overdue" || $0.dueStatus == "due_today" }
  }
}

public struct WidgetList: Codable, Equatable, Identifiable {
  public var id: String
  public var name: String
  public var type: String?
  public var openCount: Int
  public var items: [WidgetListItem]

  enum CodingKeys: String, CodingKey {
    case id, name, type
    case openCount = "open_count"
    case items
  }

  public init(id: String, name: String, type: String? = nil, openCount: Int = 0, items: [WidgetListItem] = []) {
    self.id = id
    self.name = name
    self.type = type
    self.openCount = openCount
    self.items = items
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    type = try c.decodeIfPresent(String.self, forKey: .type)
    items = try c.decodeIfPresent([WidgetListItem].self, forKey: .items) ?? []
    openCount = try c.decodeIfPresent(Int.self, forKey: .openCount) ?? items.count
  }
}

public struct WidgetListItem: Codable, Equatable, Identifiable {
  public var id: String
  public var name: String
  public var quantity: Double?
  public var unit: String?
  public var addedByName: String?
  /// Set only by the native overlay for a queued, undelivered add (C1).
  public var local: Bool?

  enum CodingKeys: String, CodingKey {
    case id, name, quantity, unit
    case addedByName = "added_by_name"
    case local
  }

  public init(
    id: String, name: String, quantity: Double? = nil, unit: String? = nil,
    addedByName: String? = nil, local: Bool? = nil
  ) {
    self.id = id
    self.name = name
    self.quantity = quantity
    self.unit = unit
    self.addedByName = addedByName
    self.local = local
  }

  public var isLocal: Bool { local ?? false }

  /// "2 l", "×3", or nil for a plain single item.
  public var quantityText: String? {
    let unit = (self.unit ?? "").trimmingCharacters(in: .whitespaces)
    guard let quantity, quantity > 0 else { return unit.isEmpty ? nil : unit }
    let number =
      quantity.rounded() == quantity
      ? String(Int64(quantity))
      : String(format: "%g", quantity)
    if unit.isEmpty { return quantity == 1 ? nil : "×\(number)" }
    return "\(number) \(unit)"
  }
}

public struct WidgetChore: Codable, Equatable, Identifiable {
  public var id: String
  public var title: String
  public var dueAt: String?
  public var dueStatus: String?
  public var isMine: Bool
  public var assigneeName: String?
  public var nextAssigneeName: String?

  enum CodingKeys: String, CodingKey {
    case id, title
    case dueAt = "due_at"
    case dueStatus = "due_status"
    case isMine = "is_mine"
    case assigneeName = "assignee_name"
    case nextAssigneeName = "next_assignee_name"
  }

  public init(
    id: String, title: String, dueAt: String? = nil, dueStatus: String? = nil, isMine: Bool = false,
    assigneeName: String? = nil, nextAssigneeName: String? = nil
  ) {
    self.id = id
    self.title = title
    self.dueAt = dueAt
    self.dueStatus = dueStatus
    self.isMine = isMine
    self.assigneeName = assigneeName
    self.nextAssigneeName = nextAssigneeName
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    dueAt = try c.decodeIfPresent(String.self, forKey: .dueAt)
    dueStatus = try c.decodeIfPresent(String.self, forKey: .dueStatus)
    isMine = try c.decodeIfPresent(Bool.self, forKey: .isMine) ?? false
    assigneeName = try c.decodeIfPresent(String.self, forKey: .assigneeName)
    nextAssigneeName = try c.decodeIfPresent(String.self, forKey: .nextAssigneeName)
  }

  public var dueDate: Date? { dueAt.flatMap(WidgetDate.parse) }
}

public struct WidgetMeal: Codable, Equatable {
  public var title: String
  public var slot: String?
  public var recipeID: String?

  enum CodingKeys: String, CodingKey {
    case title, slot
    case recipeID = "recipe_id"
  }

  public init(title: String, slot: String? = nil, recipeID: String? = nil) {
    self.title = title
    self.slot = slot
    self.recipeID = recipeID
  }
}

public struct WidgetBalance: Codable, Equatable {
  public var currency: String
  /// Positive: others owe the user. Negative: the user owes.
  public var netCents: Int64
  public var settleWithName: String?
  /// Always positive when present.
  public var settleCents: Int64?

  enum CodingKeys: String, CodingKey {
    case currency
    case netCents = "net_cents"
    case settleWithName = "settle_with_name"
    case settleCents = "settle_cents"
  }

  public init(currency: String, netCents: Int64, settleWithName: String? = nil, settleCents: Int64? = nil) {
    self.currency = currency
    self.netCents = netCents
    self.settleWithName = settleWithName
    self.settleCents = settleCents
  }
}

/// RFC 3339 timestamps as Go writes them: `Z` or an offset, and fractional
/// seconds of any length (Go emits up to nine digits).
public enum WidgetDate {
  private static let withFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let plain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private static let lock = NSLock()

  public static func parse(_ raw: String) -> Date? {
    let value = raw.trimmingCharacters(in: .whitespaces)
    guard !value.isEmpty else { return nil }
    lock.lock()
    defer { lock.unlock() }
    if let dot = value.firstIndex(of: ".") {
      // Keep at most three fractional digits; ISO8601DateFormatter rejects
      // Go's nanosecond precision on some OS versions.
      var digitsEnd = value.index(after: dot)
      while digitsEnd < value.endIndex, value[digitsEnd].isNumber { digitsEnd = value.index(after: digitsEnd) }
      let digits = value[value.index(after: dot)..<digitsEnd]
      let millis = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
      let normalized = String(value[..<dot]) + "." + millis + String(value[digitsEnd...])
      if let date = withFraction.date(from: normalized) { return date }
      // Last resort: drop the fraction.
      return plain.date(from: String(value[..<dot]) + String(value[digitsEnd...]))
    }
    return plain.date(from: value) ?? withFraction.date(from: value)
  }

  /// Millisecond precision, UTC: `2026-10-02T09:03:01.200Z`.
  public static func format(_ date: Date) -> String {
    lock.lock()
    defer { lock.unlock() }
    return withFraction.string(from: date)
  }
}
