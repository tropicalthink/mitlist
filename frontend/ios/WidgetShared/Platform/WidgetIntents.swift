import AppIntents
import Foundation

#if canImport(WidgetKit)
  import WidgetKit
#endif

// App Intents shared by the app and the widget extension (plan 047, D4/D8,
// C7). They are compiled into both targets and kept `public`, or release
// builds cannot find them.

// MARK: - Entities

@available(iOS 17.0, *)
public struct HouseholdEntity: AppEntity {
  public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Household"
  public static let defaultQuery = HouseholdEntityQuery()

  public let id: String
  public let name: String

  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }

  public var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }
}

@available(iOS 17.0, *)
public struct HouseholdEntityQuery: EntityQuery {
  public init() {}

  private func all() -> [HouseholdEntity] {
    (WidgetStorage.shared?.readSnapshot()?.households ?? []).map { HouseholdEntity(id: $0.id, name: $0.name) }
  }

  public func entities(for identifiers: [String]) async throws -> [HouseholdEntity] {
    all().filter { identifiers.contains($0.id) }
  }

  public func suggestedEntities() async throws -> [HouseholdEntity] { all() }

  public func defaultResult() async -> HouseholdEntity? {
    guard let snapshot = WidgetStorage.shared?.readSnapshot(),
      let household = snapshot.resolveHousehold(nil)
    else { return nil }
    return HouseholdEntity(id: household.id, name: household.name)
  }
}

@available(iOS 17.0, *)
public struct ListEntity: AppEntity {
  public static let typeDisplayRepresentation: TypeDisplayRepresentation = "List"
  public static let defaultQuery = ListEntityQuery()

  public let id: String
  public let name: String
  public let householdID: String
  public let householdName: String

  public init(id: String, name: String, householdID: String, householdName: String) {
    self.id = id
    self.name = name
    self.householdID = householdID
    self.householdName = householdName
  }

  public var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)", subtitle: "\(householdName)")
  }
}

@available(iOS 17.0, *)
public struct ListEntityQuery: EntityQuery {
  public init() {}

  private func all() -> [ListEntity] {
    let households = WidgetStorage.shared?.readSnapshot()?.households ?? []
    return households.flatMap { household in
      household.lists.map {
        ListEntity(id: $0.id, name: $0.name, householdID: household.id, householdName: household.name)
      }
    }
  }

  public func entities(for identifiers: [String]) async throws -> [ListEntity] {
    all().filter { identifiers.contains($0.id) }
  }

  public func suggestedEntities() async throws -> [ListEntity] { all() }

  public func defaultResult() async -> ListEntity? {
    guard let snapshot = WidgetStorage.shared?.readSnapshot(),
      let (household, list) = snapshot.resolveList(nil)
    else { return nil }
    return ListEntity(id: list.id, name: list.name, householdID: household.id, householdName: household.name)
  }
}

// MARK: - Widget configuration (D7)

@available(iOS 17.0, *)
public struct ListWidgetConfiguration: WidgetConfigurationIntent {
  public static let title: LocalizedStringResource = "Shopping list"
  public static let description: IntentDescription? = IntentDescription("Choose the list this widget shows.")

  @Parameter(title: "List")
  public var list: ListEntity?

  public init() {}
}

@available(iOS 17.0, *)
public struct HouseholdWidgetConfiguration: WidgetConfigurationIntent {
  public static let title: LocalizedStringResource = "Household"
  public static let description: IntentDescription? = IntentDescription(
    "Choose the household this widget shows.")

  @Parameter(title: "Household")
  public var household: HouseholdEntity?

  public init() {}
}

// MARK: - Widget buttons

/// Ticks a list item off from a widget.
@available(iOS 17.0, *)
public struct ToggleListItemIntent: AppIntent {
  public static let title: LocalizedStringResource = "Tick off item"
  public static let isDiscoverable = false

  @Parameter(title: "Item") public var itemID: String
  @Parameter(title: "List") public var listID: String
  @Parameter(title: "Household") public var householdID: String

  public init() {}

  public init(itemID: String, listID: String, householdID: String) {
    self.itemID = itemID
    self.listID = listID
    self.householdID = householdID
  }

  @available(iOS 26.0, *)
  public static var supportedModes: IntentModes { .background }

  public func perform() async throws -> some IntentResult {
    await WidgetActions.checkItem(
      householdID: householdID, listID: listID, itemID: itemID, source: WidgetOpSource.widget)
    return .result()
  }
}

/// Marks a chore done from a widget.
@available(iOS 17.0, *)
public struct CompleteChoreIntent: AppIntent {
  public static let title: LocalizedStringResource = "Complete chore"
  public static let isDiscoverable = false

  @Parameter(title: "Chore") public var choreID: String
  @Parameter(title: "Household") public var householdID: String

  public init() {}

  public init(choreID: String, householdID: String) {
    self.choreID = choreID
    self.householdID = householdID
  }

  @available(iOS 26.0, *)
  public static var supportedModes: IntentModes { .background }

  public func perform() async throws -> some IntentResult {
    await WidgetActions.completeChore(householdID: householdID, choreID: choreID, source: WidgetOpSource.widget)
    return .result()
  }
}

/// Delivers queued taps and fetches fresh data (the refresh button).
@available(iOS 17.0, *)
public struct RefreshWidgetsIntent: AppIntent {
  public static let title: LocalizedStringResource = "Refresh widgets"
  public static let isDiscoverable = false

  public init() {}

  @available(iOS 26.0, *)
  public static var supportedModes: IntentModes { .background }

  public func perform() async throws -> some IntentResult {
    WidgetStorage.shared?.refreshRequested = true
    await WidgetSync.run(timeout: 12)
    return .result()
  }
}

// MARK: - Siri and Shortcuts

/// "Add to my list in mitlist": Siri asks for the item.
@available(iOS 17.0, *)
public struct AddItemIntent: AppIntent {
  public static let title: LocalizedStringResource = "Add to list"
  public static let description: IntentDescription? = IntentDescription("Adds an item to a mitlist list.")

  @Parameter(title: "Item", requestValueDialog: IntentDialog("What should I add?"))
  public var itemName: String

  @Parameter(title: "List")
  public var list: ListEntity?

  public static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$itemName) to \(\.$list)")
  }

  public init() {}

  @available(iOS 26.0, *)
  public static var supportedModes: IntentModes { .background }

  public func perform() async throws -> some IntentResult & ProvidesDialog {
    let name = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      return .result(dialog: IntentDialog("Nothing to add."))
    }
    guard let snapshot = WidgetStorage.shared?.readSnapshot(),
      let (household, target) = snapshot.resolveList(list?.id)
    else {
      return .result(dialog: IntentDialog("Open mitlist once to set up your lists."))
    }
    await WidgetActions.addItem(
      householdID: household.id, listID: target.id, name: name, source: WidgetOpSource.siri)
    let listName = target.name
    return .result(dialog: IntentDialog("Added \(name) to \(listName)."))
  }
}

// MARK: - Controls (iOS 18)

/// Opens the default list with the composer focused.
@available(iOS 18.0, *)
public struct OpenAddItemIntent: AppIntent {
  public static let title: LocalizedStringResource = "Add to list"
  public static let isDiscoverable = false

  public init() {}

  public func perform() async throws -> some IntentResult & OpensIntent {
    let url: URL
    if let snapshot = WidgetStorage.shared?.readSnapshot(), let (household, list) = snapshot.resolveList(nil) {
      url = WidgetLinks.list(list.id, household: household.id, add: true)
    } else {
      url = WidgetLinks.lists(household: nil)
    }
    return .result(opensIntent: OpenURLIntent(url))
  }
}

/// Opens the scanner.
@available(iOS 18.0, *)
public struct OpenScannerIntent: AppIntent {
  public static let title: LocalizedStringResource = "Scan receipt"
  public static let isDiscoverable = false

  public init() {}

  public func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(WidgetLinks.scanner))
  }
}
