import SwiftUI
import WidgetKit

/// Household today: due chores, the list, tonight's meal and the balance in
/// one large widget (plan 047, stage 7, C7).
struct HouseholdTodayWidget: Widget {
  var body: some WidgetConfiguration { Self.configuration() }

  static func configuration() -> some WidgetConfiguration {
    AppIntentConfiguration(
      kind: WidgetKinds.householdToday, intent: HouseholdWidgetConfiguration.self, provider: HouseholdProvider()
    ) { entry in
      HouseholdTodayView(entry: entry)
    }
    .configurationDisplayName("Household today")
    .description("Chores, the shopping list, tonight's meal and who owes whom.")
    .supportedFamilies([.systemLarge, .systemExtraLarge])
  }
}

struct HouseholdTodayView: View {
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
    } else if let household = entry.snapshot?.resolveHousehold(entry.selection) {
      let list = household.lists.first { $0.type == "shopping" } ?? household.lists.first
      VStack(alignment: .leading, spacing: 10) {
        Link(destination: WidgetLinks.home(household: household.id)) {
          HStack(alignment: .firstTextBaseline) {
            Text(verbatim: household.name)
              .font(.headline)
              .lineLimit(1)
            Spacer(minLength: 0)
            Text(entry.date, format: .dateTime.weekday(.wide).day().month())
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        // Large and extra large are the same height: stacked sections get
        // two chores and three items (two above a footer line); side by
        // side they get three and four.
        let footer = entry.needsApp || entry.updatedText != nil
        if family == .systemExtraLarge {
          HStack(alignment: .top, spacing: 16) {
            ChoresSection(entry: entry, household: household, maxRows: 3)
            if let list { ListSection(household: household, list: list, maxItems: 4) }
          }
        } else {
          ChoresSection(entry: entry, household: household, maxRows: 2)
          if let list { ListSection(household: household, list: list, maxItems: footer ? 2 : 3) }
        }
        Spacer(minLength: 0)
        HStack(alignment: .top, spacing: 12) {
          MealCell(household: household)
          BalanceCell(household: household)
        }
        WidgetFooter(entry: entry)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else {
      WidgetSetupView(status: .notSetUp)
    }
  }
}

private struct SectionHeader: View {
  let title: Text
  let detail: Text
  let url: URL

  var body: some View {
    Link(destination: url) {
      HStack(alignment: .firstTextBaseline) {
        title
          .font(.subheadline.weight(.bold))
          .lineLimit(1)
        Spacer(minLength: 0)
        detail
          .font(.caption.weight(.semibold))
          .foregroundStyle(WidgetTheme.accent)
          .widgetAccentable()
      }
    }
  }
}

private struct ChoresSection: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let maxRows: Int

  var body: some View {
    let due = household.choresDue(now: entry.date)
    VStack(alignment: .leading, spacing: WidgetTheme.rowSpacing) {
      SectionHeader(
        title: Text("Chores"), detail: due.isEmpty ? Text(verbatim: "") : Text("\(due.count) chores due"),
        url: WidgetLinks.chores(household: household.id))
      if due.isEmpty {
        Text("Nothing due")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(due.prefix(maxRows)) { chore in
          ChoreRow(chore: chore, householdID: household.id, now: entry.date)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ListSection: View {
  let household: WidgetHousehold
  let list: WidgetList
  let maxItems: Int

  var body: some View {
    VStack(alignment: .leading, spacing: WidgetTheme.rowSpacing) {
      HStack(alignment: .center) {
        SectionHeader(
          title: Text(verbatim: list.name), detail: Text("\(list.openCount) left"),
          url: WidgetLinks.list(list.id, household: household.id))
        AddLink(url: WidgetLinks.list(list.id, household: household.id, add: true), size: 24)
      }
      if list.items.isEmpty {
        Text("Nothing left to buy")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(list.items.prefix(maxItems)) { item in
          ListItemRow(item: item, listID: list.id, householdID: household.id, showAddedBy: false)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct MealCell: View {
  let household: WidgetHousehold

  var body: some View {
    Link(destination: WidgetLinks.home(household: household.id)) {
      VStack(alignment: .leading, spacing: 2) {
        Label("Tonight", systemImage: "fork.knife")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        if let meal = household.tonightMeal {
          Text(verbatim: meal.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
        } else {
          Text("Nothing planned")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct BalanceCell: View {
  let household: WidgetHousehold

  var body: some View {
    Link(destination: WidgetLinks.money(household: household.id)) {
      VStack(alignment: .leading, spacing: 2) {
        Label("Balance", systemImage: "arrow.left.arrow.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
        Text(verbatim: WidgetFormat.balanceLine(household.balance))
          .font(.subheadline.weight(.semibold))
          .lineLimit(2)
          .privacySensitive()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// Balance: "You owe Sam €12.00". Home Screen only, and amounts are
/// redacted on a locked device (plan 047, stage 7).
struct BalanceWidget: Widget {
  var body: some WidgetConfiguration { Self.configuration() }

  static func configuration() -> some WidgetConfiguration {
    AppIntentConfiguration(kind: WidgetKinds.balance, intent: HouseholdWidgetConfiguration.self, provider: HouseholdProvider()) {
      entry in
      BalanceWidgetView(entry: entry)
    }
    .configurationDisplayName("Balance")
    .description("Who owes whom in your household.")
    .supportedFamilies([.systemSmall])
  }
}

struct BalanceWidgetView: View {
  let entry: MitlistEntry

  var body: some View {
    content.mitlistBackground()
  }

  @ViewBuilder
  private var content: some View {
    if entry.status != .ready {
      WidgetSetupView(status: entry.status)
    } else if let household = entry.snapshot?.resolveHousehold(entry.selection) {
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: household.name)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Image(systemName: settled(household) ? "checkmark.seal" : "arrow.left.arrow.right")
          .font(.title3)
          .foregroundStyle(WidgetTheme.accent)
          .widgetAccentable()
          .accessibilityHidden(true)
        Spacer(minLength: 0)
        Text(verbatim: WidgetFormat.balanceLine(household.balance))
          .font(.headline)
          .lineLimit(3)
          .minimumScaleFactor(0.7)
          .privacySensitive()
        if entry.needsApp {
          Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Open mitlist to sync"))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .widgetURL(WidgetLinks.money(household: household.id))
    } else {
      WidgetSetupView(status: .notSetUp)
    }
  }

  private func settled(_ household: WidgetHousehold) -> Bool {
    (household.balance?.netCents ?? 0) == 0
  }
}

#Preview(as: .systemLarge) {
  HouseholdTodayWidget()
} timeline: {
  MitlistEntry.preview()
}

#Preview(as: .systemSmall) {
  BalanceWidget()
} timeline: {
  MitlistEntry.preview()
}
