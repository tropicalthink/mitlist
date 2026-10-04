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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetLinks.list(list.id, household: household.id))
      case .systemSmall:
        SmallListView(entry: entry, household: household, list: list)
      default:
        // A medium widget fits three rows, or two above the footer line.
        let footer = entry.needsApp || entry.updatedText != nil
        ListBodyView(
          entry: entry, household: household, list: list,
          maxItems: family == .systemLarge ? (footer ? 7 : 8) : (footer ? 2 : 3),
          showsMore: family == .systemLarge)
      }
    } else {
      NoListView(householdID: entry.snapshot?.resolveHousehold(nil)?.id)
    }
  }
}

private struct SmallListView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let list: WidgetList

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(verbatim: list.name)
        .font(.headline)
        .lineLimit(2)
      Spacer(minLength: 0)
      Text(verbatim: "\(list.openCount)")
        .font(.system(size: 40, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .contentTransition(.numericText())
      HStack(alignment: .center) {
        Text("left")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
        AddLink(url: WidgetLinks.list(list.id, household: household.id, add: true), size: 32)
      }
      if entry.needsApp {
        Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .accessibilityLabel(Text("Open mitlist to sync"))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .widgetURL(WidgetLinks.list(list.id, household: household.id))
  }
}

private struct ListBodyView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let list: WidgetList
  let maxItems: Int
  /// "+3 more" under the rows; the medium size has no room for it and its
  /// header already shows the count.
  let showsMore: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: WidgetTheme.rowSpacing) {
      HStack(alignment: .center, spacing: 8) {
        Link(destination: WidgetLinks.list(list.id, household: household.id)) {
          VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: list.name)
              .font(.headline)
              .lineLimit(1)
            Text("\(list.openCount) left")
              .font(.caption.weight(.semibold))
              .foregroundStyle(WidgetTheme.accent)
              .widgetAccentable()
          }
        }
        Spacer(minLength: 0)
        AddLink(url: WidgetLinks.list(list.id, household: household.id, add: true))
      }

      if list.items.isEmpty {
        Spacer(minLength: 0)
        Text("Nothing left to buy")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
      } else {
        ForEach(list.items.prefix(maxItems)) { item in
          ListItemRow(item: item, listID: list.id, householdID: household.id, showAddedBy: maxItems > 3)
        }
        let hidden = max(0, list.openCount - min(maxItems, list.items.count))
        if showsMore && hidden > 0 {
          Link(destination: WidgetLinks.list(list.id, household: household.id)) {
            Text("+\(hidden) more")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 0)
      }
      WidgetFooter(entry: entry)
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

#Preview(as: .systemMedium) {
  ShoppingListWidget()
} timeline: {
  MitlistEntry.preview()
}

#Preview(as: .systemSmall) {
  ShoppingListWidget()
} timeline: {
  MitlistEntry.preview()
}
