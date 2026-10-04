import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Theme

/// mitlist on the home screen: system font and corner radius, brand orange
/// only as an accent (tinted and clear modes wash it out, so status never
/// relies on colour alone), square 2pt outlines inside.
enum WidgetTheme {
  static let accent = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
  static let outline: CGFloat = 2
  static let rowSpacing: CGFloat = 6
}

/// Lets a renderer outside WidgetKit (previews, snapshot tests) pick the
/// family: `widgetFamily` itself is read-only.
private struct FamilyOverrideKey: EnvironmentKey {
  static let defaultValue: WidgetFamily? = nil
}

extension EnvironmentValues {
  var mitlistFamilyOverride: WidgetFamily? {
    get { self[FamilyOverrideKey.self] }
    set { self[FamilyOverrideKey.self] = newValue }
  }
}

// MARK: - Entry and loading

enum WidgetStatus: Equatable {
  /// Snapshot on disk: render it.
  case ready
  /// The app signed out and wiped widget data.
  case signedOut
  /// No snapshot yet: the app has not run since install or update.
  case notSetUp
}

struct MitlistEntry: TimelineEntry {
  let date: Date
  let status: WidgetStatus
  /// Snapshot with the queue overlay applied.
  let snapshot: WidgetSnapshot?
  /// A credential is missing, expired or was rejected: taps still queue,
  /// and the app delivers them when it next opens.
  let needsApp: Bool
  let updatedText: String?
  /// The configured list or household id, if any.
  let selection: String?

  static func preview(selection: String? = nil, date: Date = Date()) -> MitlistEntry {
    MitlistEntry(
      date: date, status: .ready, snapshot: WidgetPreviewData.snapshot, needsApp: false, updatedText: nil,
      selection: selection)
  }
}

enum WidgetLoader {
  static func entry(selection: String?, now: Date = Date()) -> MitlistEntry {
    guard let storage = WidgetStorage.shared else {
      return MitlistEntry(
        date: now, status: .notSetUp, snapshot: nil, needsApp: false, updatedText: nil, selection: selection)
    }
    guard let snapshot = storage.renderedSnapshot() else {
      return MitlistEntry(
        date: now, status: storage.signedOut ? .signedOut : .notSetUp, snapshot: nil, needsApp: false,
        updatedText: nil, selection: selection)
    }
    let credential = WidgetCredentialStore.load()
    let needsApp = storage.authFailed || !(credential?.isUsable ?? false)
    let updated = WidgetFormat.updated(storage.lastFetchAt ?? snapshot.generatedDate, now: now)
    return MitlistEntry(
      date: now, status: .ready, snapshot: snapshot, needsApp: needsApp, updatedText: updated, selection: selection)
  }

  /// Delivers queued taps and refetches when the data is stale or a push
  /// asked for it; bounded so the timeline is never late for long.
  static func refreshIfNeeded() async {
    guard let storage = WidgetStorage.shared, let credential = WidgetCredentialStore.load(), credential.isUsable
    else { return }
    let hasPending = storage.queue.readOps().contains { $0.state == .pending }
    guard storage.needsRefresh() || hasPending else { return }
    await WidgetSync.run(storage: storage, fetch: true, timeout: 10)
  }

  static func timeline(selection: String?) async -> Timeline<MitlistEntry> {
    await refreshIfNeeded()
    let now = Date()
    return Timeline(entries: [entry(selection: selection, now: now)], policy: .after(now.addingTimeInterval(30 * 60)))
  }
}

struct ListProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> MitlistEntry { .preview() }

  func snapshot(for configuration: ListWidgetConfiguration, in context: Context) async -> MitlistEntry {
    if context.isPreview { return .preview(selection: configuration.list?.id) }
    return WidgetLoader.entry(selection: configuration.list?.id)
  }

  func timeline(for configuration: ListWidgetConfiguration, in context: Context) async -> Timeline<MitlistEntry> {
    await WidgetLoader.timeline(selection: configuration.list?.id)
  }
}

struct HouseholdProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> MitlistEntry { .preview() }

  func snapshot(for configuration: HouseholdWidgetConfiguration, in context: Context) async -> MitlistEntry {
    if context.isPreview { return .preview(selection: configuration.household?.id) }
    return WidgetLoader.entry(selection: configuration.household?.id)
  }

  func timeline(for configuration: HouseholdWidgetConfiguration, in context: Context) async -> Timeline<MitlistEntry> {
    await WidgetLoader.timeline(selection: configuration.household?.id)
  }
}

// MARK: - Shared views

/// Signed-out and first-run states.
struct WidgetSetupView: View {
  let status: WidgetStatus
  @Environment(\.widgetFamily) private var systemFamily
  @Environment(\.mitlistFamilyOverride) private var familyOverride
  private var family: WidgetFamily { familyOverride ?? systemFamily }

  var body: some View {
    let message: LocalizedStringKey =
      status == .signedOut ? "Sign in to mitlist" : "Open mitlist to set up widgets"
    Group {
      switch family {
      case .accessoryInline:
        Text(message)
      case .accessoryCircular:
        Image(systemName: "list.bullet.rectangle")
          .accessibilityLabel(Text(message))
      default:
        VStack(alignment: .leading, spacing: 6) {
          Image(systemName: status == .signedOut ? "person.crop.circle.badge.exclamationmark" : "list.bullet.rectangle")
            .font(.title2)
            .foregroundStyle(WidgetTheme.accent)
            .widgetAccentable()
            .accessibilityHidden(true)
          Text(message)
            .font(.subheadline.weight(.semibold))
            .lineLimit(3)
            .minimumScaleFactor(0.8)
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }
    .widgetURL(WidgetLinks.home(household: nil))
  }
}

/// "Open mitlist to sync", or "Updated 20 minutes ago" with a refresh
/// button, or nothing while fresh.
struct WidgetFooter: View {
  let entry: MitlistEntry

  var body: some View {
    if entry.needsApp {
      Label("Open mitlist to sync", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .foregroundStyle(.secondary)
    } else if let updated = entry.updatedText {
      HStack(spacing: 4) {
        Text(verbatim: updated)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Spacer(minLength: 0)
        Button(intent: RefreshWidgetsIntent()) {
          Image(systemName: "arrow.clockwise")
            .font(.caption2.weight(.bold))
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Refresh"))
      }
    }
  }
}

/// The square, 2pt-outlined checkbox.
struct ItemToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 8) {
      ZStack {
        Rectangle()
          .strokeBorder(Color.primary, lineWidth: WidgetTheme.outline)
        if configuration.isOn {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .heavy))
        }
      }
      .frame(width: 20, height: 20)
      configuration.label
    }
    .contentShape(Rectangle())
  }
}

/// One open list item: a toggle that ticks it off, or a greyed row for an
/// add still waiting to be delivered.
struct ListItemRow: View {
  let item: WidgetListItem
  let listID: String
  let householdID: String
  var showAddedBy = true

  var body: some View {
    if item.isLocal {
      HStack(spacing: 8) {
        Rectangle()
          .strokeBorder(style: StrokeStyle(lineWidth: WidgetTheme.outline, dash: [3, 2]))
          .frame(width: 20, height: 20)
          .foregroundStyle(.secondary)
        label
          .foregroundStyle(.secondary)
        Image(systemName: "clock")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .accessibilityLabel(Text("Waiting to sync"))
      }
      .frame(minHeight: 24)
    } else {
      Toggle(isOn: false, intent: ToggleListItemIntent(itemID: item.id, listID: listID, householdID: householdID)) {
        label
      }
      .toggleStyle(ItemToggleStyle())
      .frame(minHeight: 24)
      .accessibilityLabel(Text("Tick off \(item.name)"))
    }
  }

  private var label: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Text(verbatim: item.name)
        .font(.subheadline)
        .lineLimit(1)
      if let quantity = item.quantityText {
        Text(verbatim: quantity)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      if showAddedBy, let addedBy = item.addedByName, !addedBy.isEmpty {
        Text(verbatim: addedBy)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}

/// One due chore with its "Done" button.
struct ChoreRow: View {
  let chore: WidgetChore
  let householdID: String
  let now: Date

  var body: some View {
    HStack(spacing: 8) {
      Button(intent: CompleteChoreIntent(choreID: chore.id, householdID: householdID)) {
        Image(systemName: "checkmark.square")
          .font(.system(size: 20, weight: .semibold))
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(WidgetTheme.accent)
      .widgetAccentable()
      .accessibilityLabel(Text("Mark \(chore.title) done"))

      VStack(alignment: .leading, spacing: 1) {
        Text(verbatim: chore.title)
          .font(.subheadline.weight(chore.isMine ? .semibold : .regular))
          .lineLimit(1)
        Text(verbatim: subtitle)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
  }

  private var subtitle: String {
    var parts = [WidgetFormat.due(chore, now: now)]
    if !chore.isMine, let assignee = chore.assigneeName, !assignee.isEmpty {
      parts.append(assignee)
    } else if let next = WidgetFormat.next(chore) {
      parts.append(next)
    }
    return parts.joined(separator: " · ")
  }
}

/// A round "+" that opens the list with the composer focused.
struct AddLink: View {
  let url: URL
  var size: CGFloat = 28

  var body: some View {
    Link(destination: url) {
      Image(systemName: "plus")
        .font(.system(size: size * 0.5, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(Circle().fill(WidgetTheme.accent))
        .widgetAccentable()
    }
    .accessibilityLabel(Text("Add item"))
  }
}

extension WidgetHousehold {
  /// Chores due today or overdue in the device's time zone, server order.
  func choresDue(now: Date) -> [WidgetChore] {
    let calendar = Calendar.current
    let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
    return chores.filter { chore in
      if let due = chore.dueDate { return due < endOfToday }
      return chore.dueStatus == "overdue" || chore.dueStatus == "due_today"
    }
  }
}

extension View {
  /// The widget background in every rendering mode. Links take the tint,
  /// so it is the primary colour: titles stay neutral and orange is used
  /// only where a view asks for the accent.
  func mitlistBackground() -> some View {
    tint(Color.primary)
      .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
  }
}

// MARK: - Preview data

enum WidgetPreviewData {
  static let snapshot = WidgetSnapshot(
    version: 1, generatedAt: WidgetDate.format(Date()), source: "server", userID: "preview",
    defaults: WidgetDefaults(householdID: "h1", listID: "l1"),
    households: [
      WidgetHousehold(
        id: "h1", name: String(localized: "Flat 3B"),
        lists: [
          WidgetList(
            id: "l1", name: String(localized: "Groceries"), type: "shopping", openCount: 7,
            items: [
              WidgetListItem(id: "i1", name: String(localized: "Oat milk"), quantity: 2, unit: "l", addedByName: "Sam"),
              WidgetListItem(id: "i2", name: String(localized: "Bread"), quantity: 1),
              WidgetListItem(id: "i3", name: String(localized: "Coffee beans"), quantity: 1, addedByName: "Alex"),
              WidgetListItem(id: "i4", name: String(localized: "Tomatoes"), quantity: 6),
              WidgetListItem(id: "i5", name: String(localized: "Basil"), quantity: 1),
              WidgetListItem(id: "i6", name: String(localized: "Washing-up liquid"), quantity: 1),
              WidgetListItem(id: "i7", name: String(localized: "Apples"), quantity: 1, unit: "kg"),
            ])
        ],
        chores: [
          WidgetChore(
            id: "c1", title: String(localized: "Bins out"), dueAt: WidgetDate.format(Date()),
            dueStatus: "due_today", isMine: true, assigneeName: "Jo", nextAssigneeName: "Alex"),
          WidgetChore(
            id: "c2", title: String(localized: "Clean bathroom"),
            dueAt: WidgetDate.format(Date().addingTimeInterval(-2 * 86_400)), dueStatus: "overdue", isMine: false,
            assigneeName: "Sam"),
        ],
        tonightMeal: WidgetMeal(title: String(localized: "Lasagne"), slot: "dinner"),
        balance: WidgetBalance(currency: "EUR", netCents: -1200, settleWithName: "Sam", settleCents: 1200))
    ])
}
