import Flutter
import Foundation
import UIKit
import WidgetKit

/// The `me.mitlist/widgets` method channel (plan 047, contract C4): the app
/// hands the widget credential and fresh snapshots to native storage,
/// imports queued widget taps, and drives the shopping-trip Live Activity.
/// Every call answers on the main thread; file and Keychain work runs off it.
enum WidgetChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: WidgetConstants.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      handle(call, result: result)
    }
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "setCredential":
      work(result) { setCredential(args) }
    case "clearAll":
      work(result) {
        clearAll()
        return nil
      }
    case "hasCredential":
      work(result) { hasCredential() }
    case "writeSnapshot":
      work(result) { writeSnapshot(args) }
    case "readPendingOps":
      work(result) { WidgetStorage.shared?.queue.readLines() ?? [] }
    case "ackPendingOps":
      work(result) {
        let ids = (args["op_ids"] as? [Any])?.compactMap { $0 as? String } ?? []
        WidgetStorage.shared?.queue.remove(opIDs: Set(ids))
        WidgetSync.reloadWidgets()
        return nil
      }
    case "consumeAuthFailure":
      work(result) { WidgetStorage.shared?.consumeAuthFailure() ?? false }
    case "reloadWidgets":
      WidgetSync.reloadWidgets()
      result(nil)
    case "requestRefresh":
      WidgetStorage.shared?.refreshRequested = true
      runInBackground { await WidgetSync.run(timeout: 25) }
      result(nil)
    case "startShoppingTrip", "updateShoppingTrip", "endShoppingTrip":
      handleShoppingTrip(call.method, args: args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Credential and data

  private static func setCredential(_ args: [String: Any]) -> Any? {
    guard let token = args["token"] as? String, !token.isEmpty,
      let base = args["api_base_url"] as? String, !base.isEmpty
    else {
      return FlutterError(code: "invalid_args", message: "token and api_base_url are required", details: nil)
    }
    let credential = WidgetCredential(
      token: token, expiresAt: args["expires_at"] as? String, apiBaseURL: base,
      userID: args["user_id"] as? String, deviceID: args["device_id"] as? String)
    guard WidgetCredentialStore.save(credential) else {
      return FlutterError(code: "keychain", message: "Could not store the widget credential", details: nil)
    }
    if let storage = WidgetStorage.shared {
      storage.signedOut = false
      storage.authFailed = false
      runInBackground {
        await queueCurrentPushToken(storage: storage)
        // Taps that waited for a credential go out now.
        await WidgetSync.run(storage: storage, fetch: false, timeout: 25)
      }
    }
    WidgetSync.reloadWidgets()
    return nil
  }

  /// True when a credential is stored, reads back, and has not expired.
  private static func hasCredential() -> Bool {
    guard let credential = WidgetCredentialStore.load(), !credential.token.isEmpty,
      let expiry = credential.expiresAt.flatMap(WidgetDate.parse)
    else { return false }
    return expiry > Date()
  }

  private static func clearAll() {
    WidgetCredentialStore.delete()
    if let storage = WidgetStorage.shared {
      storage.deleteAll()
      storage.signedOut = true
    }
    if #available(iOS 16.2, *) {
      Task { await ShoppingTripActivityController.endAll() }
    }
    WidgetSync.reloadWidgets()
  }

  private static func writeSnapshot(_ args: [String: Any]) -> Any? {
    guard let json = args["json"] as? String, let storage = WidgetStorage.shared else { return nil }
    guard storage.writeSnapshot(Data(json.utf8)) else {
      return FlutterError(code: "invalid_snapshot", message: "Not a widget snapshot", details: nil)
    }
    WidgetSync.reloadWidgets()
    if #available(iOS 17.0, *) {
      // Siri learns the list names for "Add to <list>".
      MitlistAppShortcuts.updateAppShortcutParameters()
    }
    return nil
  }

  /// On iOS 26 the extension may have received its WidgetKit push token
  /// before any credential existed; queue it for registration.
  private static func queueCurrentPushToken(storage: WidgetStorage) async {
    guard #available(iOS 26.0, *), let info = await WidgetCenter.shared.currentPushInfo else { return }
    let hex = info.token.map { String(format: "%02x", $0) }.joined()
    if storage.registeredPushToken != hex { storage.pendingPushToken = hex }
  }

  // MARK: Shopping trip Live Activity

  private static func handleShoppingTrip(_ method: String, args: [String: Any], result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }
    Task {
      var answer: Any?
      switch method {
      case "startShoppingTrip": answer = await ShoppingTripActivityController.start(args)
      case "updateShoppingTrip": await ShoppingTripActivityController.update(args)
      default: await ShoppingTripActivityController.end(args)
      }
      await MainActor.run { result(answer) }
    }
  }

  // MARK: Helpers

  /// Runs [body] off the main thread and answers on it.
  private static func work(_ result: @escaping FlutterResult, _ body: @escaping () -> Any?) {
    DispatchQueue.global(qos: .userInitiated).async {
      let value = body()
      DispatchQueue.main.async { result(value) }
    }
  }

  private final class BackgroundTask {
    var id: UIBackgroundTaskIdentifier = .invalid
  }

  /// Keeps the app alive long enough to finish [work] if it is backgrounded.
  static func runInBackground(_ work: @escaping () async -> Void) {
    let task = BackgroundTask()
    DispatchQueue.main.async {
      task.id = UIApplication.shared.beginBackgroundTask(withName: "mitlist.widgets") {
        UIApplication.shared.endBackgroundTask(task.id)
        task.id = .invalid
      }
      Task {
        await work()
        await MainActor.run {
          if task.id != .invalid {
            UIApplication.shared.endBackgroundTask(task.id)
            task.id = .invalid
          }
        }
      }
    }
  }
}
