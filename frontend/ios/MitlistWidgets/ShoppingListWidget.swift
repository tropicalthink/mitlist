import SwiftUI
import WidgetKit

/// Shopping list: tick items off in place, "+" opens the list with the
/// composer focused (plan 047, C7).
struct ShoppingListWidget: Widget {
  var body: some WidgetConfiguration { Self.configuration() }

  static func configuration() -> some WidgetConfiguration {
    AppIntentConfiguration(kind: WidgetKinds.shoppingList, intent: ListWidgetConfiguration.self, provider: ListProvider()) {
      entry in
      ShoppingListWidgetView(entry: entry)
    }
    .configurationDisplayName("Shopping list")
    .description("Tick items off and add new ones.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    .contentMarginsDisabled()
  }
}

struct ShoppingListWidgetView: View {
  let entry: MitlistEntry
  @Environment(\.widgetFamily) private var systemFamily
  @Environment(\.mitlistFamilyOverride) private var familyOverride
  private var family: WidgetFamily { familyOverride ?? systemFamily }

  var body: some View {
    content.mitlistBackground()
  }

  @ViewBuilder
  private var content: some View {
    if entry.status != .ready {
      WidgetSetupView(status: entry.status)
    } else if let snapshot = entry.snapshot, let (household, list) = snapshot.resolveList(entry.selection) {
      switch family {
      case .accessoryInline:
        Text("\(list.name) · \(list.openCount) left")
          .widgetURL(WidgetLinks.list(list.id, household: household.id))
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 1) {
          Text(verbatim: list.name)
            .font(.headline)
            .widgetAccentable()
            .lineLimit(1)
          // Locked screens show counts, not item names.
          Text("\(list.openCount) left")
            .font(.subheadline)
            .invalidatableContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetLinks.list(list.id, household: household.id))
      case .systemSmall:
        SmallListView(entry: entry, household: household, list: list)
          .mitlistMargins(family)
      case .systemMedium:
        MediumListView(entry: entry, household: household, list: list)
          .mitlistMargins(family)
          .widgetURL(WidgetLinks.list(list.id, household: household.id))
      default:
        LargeListView(entry: entry, household: household, list: list)
          .mitlistMargins(family)
          .widgetURL(WidgetLinks.list(list.id, household: household.id))
      }
    } else {
      NoListView(householdID: entry.snapshot?.resolveHousehold(nil)?.id)
        .mitlistMargins(family)
    }
  }
}

/// List name and count, and the first item names at a glance; "+" opens the
/// list ready to type.
private struct SmallListView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let list: WidgetList

  var body: some View {
    let open = list.items.filter { !$0.checked }
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(verbatim: list.name)
          .font(.headline)
          .lineLimit(1)
        Spacer(minLength: 0)
        Text(verbatim: "\(list.openCount)")
          .font(.headline.monospacedDigit())
          .foregroundStyle(WidgetTheme.accent)
          .widgetAccentable()
          .invalidatableContent()
          .accessibilityLabel(Text("\(list.openCount) left"))
      }
      if open.isEmpty {
        Text("Nothing left to buy")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      } else {
        ForEach(open.prefix(3)) { item in
          Text(verbatim: item.name)
            .font(.caption)
            .foregroundStyle(item.isLocal ? .secondary : .primary)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 0)
      HStack(alignment: .bottom, spacing: 4) {
        let hidden = max(0, list.openCount - min(3, open.count))
        if entry.needsApp {
          Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Open mitlist to sync"))
        } else if hidden > 0 {
          Text("+\(hidden) more")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        AddButton(url: WidgetLinks.list(list.id, household: household.id, add: true))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(WidgetLinks.list(list.id, household: household.id))
  }
}

/// Name, count, "+" and refresh on the left; as many 44pt rows as fit on
/// the right (three on most phones).
private struct MediumListView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let list: WidgetList

  var body: some View {
    HStack(alignment: .top, spacing: WidgetTheme.columnSpacing) {
      VStack(alignment: .leading, spacing: 2) {
        Link(destination: WidgetLinks.list(list.id, household: household.id)) {
          VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: list.name)
              .font(.headline)
              .lineLimit(2)
            Text("\(list.openCount) left")
              .font(.caption.weight(.semibold))
              .foregroundStyle(WidgetTheme.accent)
              .widgetAccentable()
              .invalidatableContent()
          }
        }
        Spacer(minLength: 0)
        WidgetFooter(entry: entry, showsRefresh: false)
        HStack(spacing: 4) {
          AddButton(url: WidgetLinks.list(list.id, household: household.id, add: true))
          if !entry.needsApp { RefreshButton() }
        }
      }
      .frame(width: 104, alignment: .leading)

      GeometryReader { geometry in
        let rows = max(1, RowFit.rows(in: geometry.size.height))
        VStack(alignment: .leading, spacing: 0) {
          if list.items.isEmpty {
            Spacer(minLength: 0)
            Text("Nothing left to buy")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer(minLength: 0)
          } else {
            ForEach(list.items.prefix(rows)) { item in
              ListItemRow(item: item, listID: list.id, householdID: household.id, showAddedBy: false)
            }
            Spacer(minLength: 0)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// Header with "+" and refresh, then as many 44pt rows as fit.
private struct LargeListView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let list: WidgetList

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .center, spacing: 4) {
        Link(destination: WidgetLinks.list(list.id, household: household.id)) {
          VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: list.name)
              .font(.headline)
              .lineLimit(1)
            Text("\(list.openCount) left")
              .font(.caption.weight(.semibold))
              .foregroundStyle(WidgetTheme.accent)
              .widgetAccentable()
              .invalidatableContent()
          }
        }
        Spacer(minLength: 0)
        if !entry.needsApp { RefreshButton() }
        AddButton(url: WidgetLinks.list(list.id, household: household.id, add: true))
      }

      GeometryReader { geometry in
        // One caption line under the rows: "+3 more" and the footer.
        let rows = max(1, RowFit.rows(in: geometry.size.height, reserved: 18))
        let shown = Array(list.items.prefix(rows))
        let hidden = max(0, list.openCount - shown.filter { !$0.checked }.count)
        VStack(alignment: .leading, spacing: 0) {
          if list.items.isEmpty {
            Spacer(minLength: 0)
            Text("Nothing left to buy")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer(minLength: 0)
          } else {
            ForEach(shown) { item in
              ListItemRow(item: item, listID: list.id, householdID: household.id, showAddedBy: true)
            }
            Spacer(minLength: 0)
          }
          WidgetFooter(
            entry: entry, showsRefresh: false,
            trailing: hidden > 0 ? Text("+\(hidden) more") : nil)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// The household has no list yet.
private struct NoListView: View {
  let householdID: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: "cart")
        .font(.title2)
        .foregroundStyle(WidgetTheme.accent)
        .widgetAccentable()
        .accessibilityHidden(true)
      Text("Create a list in mitlist")
        .font(.subheadline.weight(.semibold))
        .lineLimit(3)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(WidgetLinks.lists(household: householdID))
  }
}

// MARK: - Quick add

/// "Add to Groceries": one tap opens the list with the composer focused
/// (`mitlist:///lists/<id>?group=<hh>&add=1`, C5). Home Screen small and a
/// Lock Screen circle.
struct QuickAddWidget: Widget {
  var body: some WidgetConfiguration { Self.configuration() }

  static func configuration() -> some WidgetConfiguration {
    AppIntentConfiguration(kind: WidgetKinds.quickAdd, intent: ListWidgetConfiguration.self, provider: ListProvider()) {
      entry in
      QuickAddWidgetView(entry: entry)
    }
    .configurationDisplayName("Quick add")
    .description("Add to your shopping list in one tap.")
    .supportedFamilies([.systemSmall, .accessoryCircular])
    .contentMarginsDisabled()
  }
}

struct QuickAddWidgetView: View {
  let entry: MitlistEntry
  @Environment(\.widgetFamily) private var systemFamily
  @Environment(\.mitlistFamilyOverride) private var familyOverride
  private var family: WidgetFamily { familyOverride ?? systemFamily }

  var body: some View {
    content.mitlistBackground()
  }

  @ViewBuilder
  private var content: some View {
    if entry.status != .ready {
      WidgetSetupView(status: entry.status)
    } else if let (household, list) = entry.snapshot?.resolveList(entry.selection) {
      let url = WidgetLinks.list(list.id, household: household.id, add: true)
      if family == .accessoryCircular {
        ZStack {
          AccessoryWidgetBackground()
          Image(systemName: "plus")
            .font(.title2.weight(.heavy))
        }
        .widgetURL(url)
        .accessibilityLabel(Text("Add to \(list.name)"))
      } else {
        VStack(alignment: .leading, spacing: 2) {
          ZStack {
            Rectangle()
              .fill(WidgetTheme.accent)
              .widgetAccentable()
            Image(systemName: "plus")
              .font(.system(size: 30, weight: .heavy))
              .foregroundStyle(.white)
          }
          .frame(width: 64, height: 64)
          .accessibilityHidden(true)
          Spacer(minLength: 0)
          Text("Add to")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(verbatim: list.name)
            .font(.headline)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .mitlistMargins(family)
        .widgetURL(url)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Add to \(list.name)"))
      }
    } else {
      NoListView(householdID: entry.snapshot?.resolveHousehold(nil)?.id)
        .mitlistMargins(family)
    }
  }
}

#Preview(as: .systemMedium) {
  ShoppingListWidget()
} timeline: {
  MitlistEntry.preview()
  MitlistEntry.previewTicked()
}

#Preview(as: .systemSmall) {
  ShoppingListWidget()
} timeline: {
  MitlistEntry.preview()
  MitlistEntry.previewTicked()
}

#Preview(as: .systemSmall) {
  QuickAddWidget()
} timeline: {
  MitlistEntry.preview()
  MitlistEntry.previewTicked()
}

#Preview(as: .systemLarge) {
  ShoppingListWidget()
} timeline: {
  MitlistEntry.previewTicked()
}
