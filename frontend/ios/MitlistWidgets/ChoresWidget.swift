import SwiftUI
import WidgetKit

/// Chores today: due and overdue chores with a "Done" button each, and who
/// is next in the rotation (plan 047, C7).
struct ChoresWidget: Widget {
  var body: some WidgetConfiguration { Self.configuration() }

  static func configuration() -> some WidgetConfiguration {
    AppIntentConfiguration(kind: WidgetKinds.chores, intent: HouseholdWidgetConfiguration.self, provider: HouseholdProvider()) {
      entry in
      ChoresWidgetView(entry: entry)
    }
    .configurationDisplayName("Chores today")
    .description("Due chores, with a Done button for each.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
  }
}

struct ChoresWidgetView: View {
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
      let due = household.choresDue(now: entry.date)
      switch family {
      case .accessoryInline:
        Text("\(due.count) chores due")
          .widgetURL(WidgetLinks.chores(household: household.id))
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 1) {
          Text("Chores")
            .font(.headline)
            .widgetAccentable()
          Text("\(due.count) chores due")
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(WidgetLinks.chores(household: household.id))
      case .systemSmall:
        SmallChoresView(entry: entry, household: household, due: due)
      default:
        let footer = entry.needsApp || entry.updatedText != nil
        ChoreListView(
          entry: entry, household: household, due: due,
          maxRows: family == .systemLarge ? (footer ? 6 : 7) : (footer ? 2 : 3),
          showsMore: family == .systemLarge)
      }
    } else {
      WidgetSetupView(status: .notSetUp)
    }
  }
}

private struct SmallChoresView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let due: [WidgetChore]

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Chores")
        .font(.headline)
      if !due.isEmpty {
        Text("\(due.count) chores due")
          .font(.caption.weight(.semibold))
          .foregroundStyle(WidgetTheme.accent)
          .widgetAccentable()
      }
      Spacer(minLength: 0)
      if let first = due.first {
        ChoreRow(chore: first, householdID: household.id, now: entry.date)
      } else {
        Text("Nothing due")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(WidgetLinks.chores(household: household.id))
  }
}

private struct ChoreListView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let due: [WidgetChore]
  let maxRows: Int
  let showsMore: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: WidgetTheme.rowSpacing) {
      Link(destination: WidgetLinks.chores(household: household.id)) {
        HStack(alignment: .firstTextBaseline) {
          Text("Chores")
            .font(.headline)
          Text(verbatim: household.name)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer(minLength: 0)
          if !due.isEmpty {
            Text("\(due.count) chores due")
              .font(.caption.weight(.semibold))
              .foregroundStyle(WidgetTheme.accent)
              .widgetAccentable()
              .lineLimit(1)
          }
        }
      }

      if due.isEmpty {
        Spacer(minLength: 0)
        Text("Nothing due")
          .font(.subheadline.weight(.semibold))
        if let upcoming = household.chores.first {
          Text("Next up: \(upcoming.title), \(WidgetFormat.due(upcoming, now: entry.date))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else {
          Link(destination: WidgetLinks.chores(household: household.id)) {
            Text("Add a chore")
              .font(.caption.weight(.semibold))
              .foregroundStyle(WidgetTheme.accent)
              .widgetAccentable()
          }
        }
        Spacer(minLength: 0)
      } else {
        ForEach(due.prefix(maxRows)) { chore in
          ChoreRow(chore: chore, householdID: household.id, now: entry.date)
        }
        if showsMore && due.count > maxRows {
          Text("+\(due.count - maxRows) more")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      WidgetFooter(entry: entry)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

#Preview(as: .systemMedium) {
  ChoresWidget()
} timeline: {
  MitlistEntry.preview()
}
