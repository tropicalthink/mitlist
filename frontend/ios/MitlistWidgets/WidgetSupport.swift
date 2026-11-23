import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Theme

/// mitlist on the home screen: the system font, square geometry with 2pt
/// outlines, brand orange (#F97316) only as an accent. Tinted and clear
/// modes wash colour out, so status is always also said in words.
enum WidgetTheme {
  static let accent = Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255)
  static let outline: CGFloat = 2
  /// Every tick, add and refresh control is at least this big (44pt).
  static let target = CGFloat(WidgetConstants.minTouchTarget)
  /// The drawn checkbox inside its 44pt target.
  static let box: CGFloat = 22
  /// Widget content margins: 16pt sides; 12pt top and bottom so a medium
  /// widget fits three 44pt rows.
  static let margins = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
  static let columnSpacing: CGFloat = 12
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

extension WidgetFamily {
  var isAccessory: Bool {
    switch self {
    case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
    default: return false
    }
  }
}

// MARK: - Entry and loading

enum WidgetStatus: Equatable {
  /// Snapshot on disk: render it.
  case ready
  /// The app signed out and wiped widget data.
  case signedOut
  /// The app is signed in but the session is not remembered ("Remember me"
  /// off), so it keeps widgets empty on purpose.
  case notRemembered
  /// No snapshot yet: the app has not run since install or update, or the
  /// first fetch has not finished.
  case notSetUp
}

struct MitlistEntry: TimelineEntry {
  let date: Date
  let status: WidgetStatus
  /// Snapshot with the queue overlay and ticked rows applied.
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

  /// The preview with one item ticked and one chore done on the widget.
  static func previewTicked(date: Date = Date()) -> MitlistEntry {
    var snapshot = WidgetPreviewData.snapshot
    snapshot.households[0].lists[0].items[1].checked = true
    snapshot.households[0].lists[0].openCount -= 1
    snapshot.households[0].chores[0].done = true
    return MitlistEntry(
      date: date, status: .ready, snapshot: snapshot, needsApp: false, updatedText: "Updated 20 min. ago", selection: nil)
  }

  /// Footer line: something to say (stale data or a sync problem).
  var hasFooter: Bool { needsApp || updatedText != nil }
}

enum WidgetLoader {
  static func entry(selection: String?, now: Date = Date()) -> MitlistEntry {
    guard let storage = WidgetStorage.shared else {
      return MitlistEntry(
        date: now, status: .notSetUp, snapshot: nil, needsApp: false, updatedText: nil, selection: selection)
    }
    guard let snapshot = storage.renderedSnapshot(now: now) else {
      let status: WidgetStatus
      if storage.signedOut {
        status = storage.clearReason == "not_remembered" ? .notRemembered : .signedOut
      } else {
        status = .notSetUp
      }
      return MitlistEntry(
        date: now, status: status, snapshot: nil, needsApp: false, updatedText: nil, selection: selection)
    }
    let credential = WidgetCredentialStore.load()
    let needsApp = storage.authFailed || !(credential?.isUsable ?? false)
    let updated = WidgetFormat.updated(storage.lastFetchAt ?? snapshot.generatedDate, now: now)
    return MitlistEntry(
      date: now, status: .ready, snapshot: snapshot, needsApp: needsApp, updatedText: updated, selection: selection)
  }

  /// Delivers queued taps, and refetches when a push or the app asked for
  /// it or the last fetch is more than a minute old: a WidgetKit push, the
  /// timeline backstop and every reload after a tap land here. Bounded so
  /// the timeline is never late for long.
  static func refreshIfNeeded() async {
    guard let storage = WidgetStorage.shared, let credential = WidgetCredentialStore.load(), credential.isUsable
    else { return }
    let hasPending = storage.queue.readOps().contains { $0.state == .pending }
    let fetch = storage.needsRefresh()
    let hasToken = storage.pendingPushToken != nil
    guard fetch || hasPending || hasToken else { return }
    await WidgetSync.run(storage: storage, fetch: fetch, reload: false, timeout: 10)
  }

  static func timeline(selection: String?) async -> Timeline<MitlistEntry> {
    await refreshIfNeeded()
    let now = Date()
    var next = now.addingTimeInterval(30 * 60)
    // Ticked rows leave the widget when their feedback time is up.
    if let expiry = WidgetStorage.shared?.nextTickExpiry(now: now), expiry < next {
      next = expiry.addingTimeInterval(1)
    }
    return Timeline(entries: [entry(selection: selection, now: now)], policy: .after(next))
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

/// Signed-out, not-remembered and first-run states: say what to do, and
/// open the app where it can be done.
struct WidgetSetupView: View {
  let status: WidgetStatus
  @Environment(\.widgetFamily) private var systemFamily
  @Environment(\.mitlistFamilyOverride) private var familyOverride
  private var family: WidgetFamily { familyOverride ?? systemFamily }

  private var title: LocalizedStringKey {
    switch status {
    case .signedOut: return "Sign in to mitlist"
    case .notRemembered: return "Widgets need Remember me"
    default: return "Open mitlist to set up widgets"
    }
  }

  private var detail: LocalizedStringKey? {
    switch status {
    case .signedOut: return "Your lists and chores show here once you're signed in."
    case .notRemembered: return "Sign in again with Remember me on to see your household here."
    default: return "Tap to connect this widget to your household."
    }
  }

  private var url: URL {
    switch status {
    case .signedOut, .notRemembered: return WidgetLinks.home(household: nil)
    default: return WidgetLinks.widgetsSetup
    }
  }

  private var icon: String {
    switch status {
    case .signedOut, .notRemembered: return "person.crop.circle.badge.exclamationmark"
    default: return "square.grid.2x2"
    }
  }

  var body: some View {
    Group {
      switch family {
      case .accessoryInline:
        Text(title)
      case .accessoryCircular:
        Image(systemName: icon)
          .font(.title3)
          .accessibilityLabel(Text(title))
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 1) {
          Text(verbatim: "mitlist")
            .font(.headline)
            .widgetAccentable()
          Text(title)
            .font(.caption)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      default:
        VStack(alignment: .leading, spacing: 6) {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(WidgetTheme.accent)
            .widgetAccentable()
            .accessibilityHidden(true)
          Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(3)
            .minimumScaleFactor(0.8)
          if family != .systemSmall, let detail {
            Text(detail)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(3)
          }
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetTheme.margins)
      }
    }
    .widgetURL(url)
  }
}

/// The refresh button: a 44pt square target.
struct RefreshButton: View {
  var body: some View {
    Button(intent: RefreshWidgetsIntent()) {
      Image(systemName: "arrow.clockwise")
        .font(.footnote.weight(.bold))
        .foregroundStyle(.secondary)
        .frame(width: WidgetTheme.target, height: WidgetTheme.target)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text("Refresh"))
  }
}

/// "Open mitlist to sync", or "Updated 20 min ago", or nothing while fresh.
/// The refresh button sits next to it unless [showsRefresh] is false (the
/// layout puts it elsewhere).
struct WidgetFooter: View {
  let entry: MitlistEntry
  var showsRefresh = true
  var trailing: Text?

  var body: some View {
    HStack(spacing: 4) {
      if entry.needsApp {
        Label("Open mitlist to sync", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
          .font(.caption2.weight(.semibold))
          .lineLimit(2)
          .minimumScaleFactor(0.8)
          .foregroundStyle(.secondary)
      } else if let updated = entry.updatedText {
        Text(verbatim: updated)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      Spacer(minLength: 0)
      if let trailing {
        trailing
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if showsRefresh && !entry.needsApp && entry.updatedText != nil {
        RefreshButton()
      }
    }
  }
}

/// The square, 2pt-outlined checkbox: empty, or filled orange with a tick.
struct CheckBox: View {
  let checked: Bool
  var dashed = false

  var body: some View {
    ZStack {
      if checked {
        Rectangle()
          .fill(WidgetTheme.accent)
          .widgetAccentable()
        Image(systemName: "checkmark")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(.white)
      } else if dashed {
        Rectangle()
          .strokeBorder(style: StrokeStyle(lineWidth: WidgetTheme.outline, dash: [3, 2]))
          .foregroundStyle(.secondary)
      } else {
        Rectangle()
          .strokeBorder(Color.primary, lineWidth: WidgetTheme.outline)
      }
    }
    .frame(width: WidgetTheme.box, height: WidgetTheme.box)
    .accessibilityHidden(true)
  }
}

/// A full-height 44pt row: the checkbox in a 44pt square, then the label.
struct CheckRowStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 2) {
      CheckBox(checked: configuration.isOn)
        .frame(width: WidgetTheme.target, height: WidgetTheme.target, alignment: .leading)
      configuration.label
    }
    .frame(minHeight: WidgetTheme.target)
    .contentShape(Rectangle())
  }
}

/// One list item. Open: the whole row ticks it off. Ticked on the widget:
/// filled box and struck through until the next refresh. A local add still
/// waiting to be delivered: dashed and greyed, not tickable.
struct ListItemRow: View {
  let item: WidgetListItem
  let listID: String
  let householdID: String
  var showAddedBy = true

  var body: some View {
    if item.checked || item.isLocal {
      HStack(spacing: 2) {
        CheckBox(checked: item.checked, dashed: item.isLocal)
          .frame(width: WidgetTheme.target, height: WidgetTheme.target, alignment: .leading)
        label(struck: item.checked)
          .foregroundStyle(.secondary)
        if item.isLocal {
          Image(systemName: "clock")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Waiting to sync"))
        }
      }
      .frame(minHeight: WidgetTheme.target)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(item.checked ? Text("\(item.name), ticked off") : Text(verbatim: item.name))
    } else {
      Toggle(isOn: false, intent: ToggleListItemIntent(itemID: item.id, listID: listID, householdID: householdID)) {
        label(struck: false)
      }
      .toggleStyle(CheckRowStyle())
      .accessibilityLabel(Text("Tick off \(item.name)"))
    }
  }

  private func label(struck: Bool) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Text(verbatim: item.name)
        .font(.subheadline)
        .strikethrough(struck)
        .lineLimit(1)
      if let quantity = item.quantityText {
        Text(verbatim: quantity)
          .font(.caption)
          .foregroundStyle(.secondary)
          .strikethrough(struck)
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

/// One chore: the same square checkbox as list rows (a 44pt "Done"
/// target), the title, and its urgency in words.
struct ChoreRow: View {
  let chore: WidgetChore
  let householdID: String
  let now: Date

  var body: some View {
    HStack(spacing: 2) {
      if chore.done {
        CheckBox(checked: true)
          .frame(width: WidgetTheme.target, height: WidgetTheme.target, alignment: .leading)
      } else {
        Button(intent: CompleteChoreIntent(choreID: chore.id, householdID: householdID)) {
          CheckBox(checked: false)
            .frame(width: WidgetTheme.target, height: WidgetTheme.target, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Mark \(chore.title) done"))
      }

      VStack(alignment: .leading, spacing: 1) {
        Text(verbatim: chore.title)
          .font(.subheadline.weight(chore.isMine && !chore.done ? .semibold : .regular))
          .strikethrough(chore.done)
          .foregroundStyle(chore.done ? .secondary : .primary)
          .lineLimit(1)
        Text(verbatim: subtitle)
          .font(.caption2.weight(urgency == .overdue && !chore.done ? .bold : .regular))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(chore.done ? Text("\(chore.title), done") : Text(verbatim: "\(chore.title), \(subtitle)"))
      Spacer(minLength: 0)
    }
    .frame(minHeight: WidgetTheme.target)
  }

  private var urgency: ChoreUrgency { WidgetChores.urgency(chore, now: now) }

  private var subtitle: String {
    var parts = [WidgetFormat.urgencyLabel(chore, now: now)]
    if !chore.isMine, let assignee = chore.assigneeName, !assignee.isEmpty {
      parts.append(assignee)
    } else if let next = WidgetFormat.next(chore) {
      parts.append(next)
    }
    return parts.joined(separator: " · ")
  }
}

/// The square orange "+" (44pt) that opens a list with the composer focused.
struct AddButton: View {
  let url: URL
  var size: CGFloat = WidgetTheme.target

  var body: some View {
    Link(destination: url) {
      ZStack {
        Rectangle()
          .fill(WidgetTheme.accent)
          .widgetAccentable()
        Image(systemName: "plus")
          .font(.system(size: size * 0.42, weight: .heavy))
          .foregroundStyle(.white)
      }
      .frame(width: size, height: size)
      .contentShape(Rectangle())
    }
    .accessibilityLabel(Text("Add item"))
  }
}

/// How many 44pt rows fit in [height] after [reserved] points of other
/// content: fewer rows rather than smaller ones.
enum RowFit {
  static func rows(in height: CGFloat, reserved: CGFloat = 0, spacing: CGFloat = 0) -> Int {
    let available = height - reserved
    guard available >= WidgetTheme.target else { return 0 }
    return Int((available + spacing) / (WidgetTheme.target + spacing))
  }
}

extension WidgetHousehold {
  /// Chores in widget order (Overdue, Today, Soon; mine first in each).
  func orderedChores(now: Date) -> [WidgetChore] { WidgetChores.ordered(chores, now: now) }

  func choreCounts(now: Date) -> ChoreCounts { WidgetChores.counts(chores, now: now) }
}

extension View {
  /// The widget background in every rendering mode. Links take the tint,
  /// so it is the primary colour: titles stay neutral and orange is used
  /// only where a view asks for the accent.
  func mitlistBackground() -> some View {
    tint(Color.primary)
      .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
  }

  /// The system-family margins (the configurations disable WidgetKit's own
  /// so a medium widget fits three 44pt rows).
  @ViewBuilder
  func mitlistMargins(_ family: WidgetFamily) -> some View {
    if family.isAccessory { self } else { padding(WidgetTheme.margins) }
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
