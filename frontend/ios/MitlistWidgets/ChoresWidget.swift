import SwiftUI
import WidgetKit

/// Chores: overdue, today's and upcoming chores, mine first, each with a
/// "Done" box and its urgency in words (plan 047, C7).
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
    .contentMarginsDisabled()
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
      let chores = household.orderedChores(now: entry.date)
      let summary = WidgetFormat.choreSummary(household.choreCounts(now: entry.date))
      let url = WidgetLinks.chores(household: household.id)
      switch family {
      case .accessoryInline:
        Text(verbatim: summary)
          .widgetURL(url)
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 1) {
          Text("Chores")
            .font(.headline)
            .widgetAccentable()
          // Counts only: the Lock Screen shows with the phone locked.
          Text(verbatim: summary)
            .font(.subheadline)
            .lineLimit(2)
            .invalidatableContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(url)
      case .systemSmall:
        SmallChoresView(entry: entry, chores: chores, summary: summary)
          .mitlistMargins(family)
          .widgetURL(url)
      case .systemMedium:
        MediumChoresView(entry: entry, household: household, chores: chores, summary: summary)
          .mitlistMargins(family)
          .widgetURL(url)
      default:
        LargeChoresView(entry: entry, household: household, chores: chores, summary: summary)
          .mitlistMargins(family)
          .widgetURL(url)
      }
    } else {
      WidgetSetupView(status: .notSetUp)
    }
  }
}

/// The summary and the most urgent chores by name, at a glance.
private struct SmallChoresView: View {
  let entry: MitlistEntry
  let chores: [WidgetChore]
  let summary: String

  var body: some View {
    let open = chores.filter { !$0.done }
    VStack(alignment: .leading, spacing: 3) {
      Text("Chores")
        .font(.headline)
        .lineLimit(1)
      Text(verbatim: summary)
        .font(.caption.weight(.semibold))
        .foregroundStyle(WidgetTheme.accent)
        .widgetAccentable()
        .lineLimit(2)
        .invalidatableContent()
      Spacer(minLength: 0)
      ForEach(open.prefix(3)) { chore in
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(verbatim: chore.title)
            .font(.caption.weight(chore.isMine ? .semibold : .regular))
            .lineLimit(1)
          Spacer(minLength: 0)
          Text(verbatim: WidgetFormat.urgencyLabel(chore, now: entry.date))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .layoutPriority(1)
        }
      }
      if open.isEmpty {
        Text("Add a chore")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if entry.needsApp {
        Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .accessibilityLabel(Text("Open mitlist to sync"))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// Title and summary on the left; as many 44pt rows as fit on the right.
private struct MediumChoresView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let chores: [WidgetChore]
  let summary: String

  var body: some View {
    HStack(alignment: .top, spacing: WidgetTheme.columnSpacing) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Chores")
          .font(.headline)
          .lineLimit(1)
        Text(verbatim: household.name)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Text(verbatim: summary)
          .font(.caption.weight(.semibold))
          .foregroundStyle(WidgetTheme.accent)
          .widgetAccentable()
          .lineLimit(2)
          .invalidatableContent()
        Spacer(minLength: 0)
        WidgetFooter(entry: entry, showsRefresh: false)
        if !entry.needsApp { RefreshButton() }
      }
      .frame(width: 104, alignment: .leading)

      GeometryReader { geometry in
        let rows = max(1, RowFit.rows(in: geometry.size.height))
        VStack(alignment: .leading, spacing: 0) {
          if chores.isEmpty {
            NothingDueView()
          } else {
            ForEach(chores.prefix(rows)) { chore in
              ChoreRow(chore: chore, householdID: household.id, now: entry.date)
            }
            Spacer(minLength: 0)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct LargeChoresView: View {
  let entry: MitlistEntry
  let household: WidgetHousehold
  let chores: [WidgetChore]
  let summary: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .center, spacing: 4) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Chores")
              .font(.headline)
            Text(verbatim: household.name)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Text(verbatim: summary)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WidgetTheme.accent)
            .widgetAccentable()
            .lineLimit(1)
            .invalidatableContent()
        }
        Spacer(minLength: 0)
        if !entry.needsApp { RefreshButton() }
      }

      GeometryReader { geometry in
        let rows = max(1, RowFit.rows(in: geometry.size.height, reserved: 18))
        let hidden = max(0, chores.count - rows)
        VStack(alignment: .leading, spacing: 0) {
          if chores.isEmpty {
            NothingDueView()
          } else {
            ForEach(chores.prefix(rows)) { chore in
              ChoreRow(chore: chore, householdID: household.id, now: entry.date)
            }
            Spacer(minLength: 0)
          }
          WidgetFooter(entry: entry, showsRefresh: false, trailing: hidden > 0 ? Text("+\(hidden) more") : nil)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct NothingDueView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Spacer(minLength: 0)
      Text("Nothing due")
        .font(.subheadline.weight(.semibold))
      Text("Add a chore")
        .font(.caption.weight(.semibold))
        .foregroundStyle(WidgetTheme.accent)
        .widgetAccentable()
      Spacer(minLength: 0)
    }
  }
}

#Preview(as: .systemMedium) {
  ChoresWidget()
} timeline: {
  MitlistEntry.preview()
  MitlistEntry.previewTicked()
}

#Preview(as: .systemSmall) {
  ChoresWidget()
} timeline: {
  MitlistEntry.preview()
}

#Preview(as: .systemLarge) {
  ChoresWidget()
} timeline: {
  MitlistEntry.previewTicked()
}
