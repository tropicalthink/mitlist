import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Controls (iOS 18): Control Center, Lock Screen, Action button

@available(iOS 18.0, *)
struct AddItemControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: WidgetKinds.addItemControl) {
      ControlWidgetButton(action: OpenAddItemIntent()) {
        Label("Add to list", systemImage: "cart.badge.plus")
      }
    }
    .displayName("Add to list")
    .description("Opens your shopping list ready to type.")
  }
}

@available(iOS 18.0, *)
struct ScanReceiptControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: WidgetKinds.scanReceiptControl) {
      ControlWidgetButton(action: OpenScannerIntent()) {
        Label("Scan receipt", systemImage: "doc.text.viewfinder")
      }
    }
    .displayName("Scan receipt")
    .description("Opens the mitlist scanner.")
  }
}

// MARK: - Shopping trip Live Activity (stage 7)

struct ShoppingTripLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ShoppingTripAttributes.self) { context in
      ShoppingTripLockScreenView(attributes: context.attributes, state: context.state)
        .padding(16)
        .activityBackgroundTint(Color(uiColor: .systemBackground))
        .activitySystemActionForegroundColor(WidgetTheme.accent)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text(verbatim: context.attributes.householdName)
              .lineLimit(1)
          } icon: {
            Image(systemName: "cart")
          }
          .font(.caption.weight(.semibold))
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(verbatim: WidgetFormat.money(context.state.totalCents, currency: context.attributes.currency))
            .font(.headline)
            .monospacedDigit()
        }
        DynamicIslandExpandedRegion(.bottom) {
          ShoppingTripProgress(state: context.state, currency: context.attributes.currency)
        }
      } compactLeading: {
        Image(systemName: context.state.finished ? "checkmark.circle" : "cart")
          .foregroundStyle(WidgetTheme.accent)
      } compactTrailing: {
        if context.state.finished {
          Text(verbatim: WidgetFormat.money(context.state.totalCents, currency: context.attributes.currency))
            .monospacedDigit()
        } else {
          Text("\(context.state.itemsLeft) left")
            .monospacedDigit()
        }
      } minimal: {
        Text(verbatim: "\(context.state.itemsLeft)")
          .monospacedDigit()
          .foregroundStyle(WidgetTheme.accent)
      }
      .widgetURL(WidgetLinks.lists(household: nil))
      .keylineTint(WidgetTheme.accent)
    }
  }
}

struct ShoppingTripLockScreenView: View {
  let attributes: ShoppingTripAttributes
  let state: ShoppingTripAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label {
          Text(state.finished ? "Trip done" : "Shopping")
            .font(.headline)
        } icon: {
          Image(systemName: state.finished ? "checkmark.circle.fill" : "cart.fill")
            .foregroundStyle(WidgetTheme.accent)
        }
        Spacer(minLength: 0)
        Text(verbatim: attributes.householdName)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      ShoppingTripProgress(state: state, currency: attributes.currency)
    }
  }
}

private struct ShoppingTripProgress: View {
  let state: ShoppingTripAttributes.ContentState
  let currency: String

  var body: some View {
    if state.finished {
      let amount = WidgetFormat.money(state.totalCents, currency: currency)
      if let raw = state.addExpenseURL, let url = URL(string: raw) {
        Link(destination: url) {
          Text("Add expense \(amount)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10).fill(WidgetTheme.accent))
        }
      } else {
        Text(verbatim: amount)
          .font(.title3.weight(.bold))
      }
    } else {
      VStack(alignment: .leading, spacing: 4) {
        ProgressView(value: state.progress)
          .tint(WidgetTheme.accent)
        HStack {
          Text("\(state.itemsLeft) of \(state.itemsTotal) left")
            .font(.caption)
            .monospacedDigit()
          Spacer(minLength: 0)
          Text(verbatim: WidgetFormat.money(state.totalCents, currency: currency))
            .font(.caption.weight(.semibold))
            .monospacedDigit()
        }
      }
    }
  }
}

// MARK: - WidgetKit push (iOS 26, stage 7)

/// Receives the WidgetKit push token and registers it with the server
/// (`PUT /widget/push-token`, C6). Without a credential yet, the token waits
/// in the App Group and the next sync registers it.
@available(iOS 26.0, *)
struct MitlistWidgetPushHandler: WidgetPushHandler {
  init() {}

  func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
    let hex = pushInfo.token.map { String(format: "%02x", $0) }.joined()
    guard let storage = WidgetStorage.shared, storage.registeredPushToken != hex else { return }
    storage.pendingPushToken = hex
    Task { await WidgetSync.registerPendingPushToken(storage: storage) }
  }
}
