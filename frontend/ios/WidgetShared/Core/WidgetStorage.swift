import Foundation

/// Files and flags in the App Group (plan 047, contract C4).
public final class WidgetStorage {
  public let directory: URL
  public let queue: PendingOpsQueue
  public let defaults: UserDefaults

  public var snapshotURL: URL { directory.appendingPathComponent(WidgetConstants.snapshotFileName) }

  public init(directory: URL, defaults: UserDefaults) {
    self.directory = directory
    self.defaults = defaults
    queue = PendingOpsQueue(directory: directory)
  }

  /// The shared App Group storage, or nil when the App Group entitlement is
  /// missing (a misconfigured build): widgets then show their setup state.
  public static let shared: WidgetStorage? = {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: WidgetConstants.appGroup),
      let defaults = UserDefaults(suiteName: WidgetConstants.appGroup)
    else { return nil }
    return WidgetStorage(
      directory: container.appendingPathComponent(WidgetConstants.directoryName, isDirectory: true),
      defaults: defaults)
  }()

  // MARK: Snapshot

  public func readSnapshot() -> WidgetSnapshot? {
    var snapshot: WidgetSnapshot?
    var error: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: snapshotURL, options: [], error: &error) { url in
      if let data = try? Data(contentsOf: url) { snapshot = try? WidgetSnapshot.decode(data) }
    }
    return snapshot
  }

  /// Validates and writes a snapshot. Returns false when [data] is not a
  /// snapshot (nothing is written then).
  @discardableResult
  public func writeSnapshot(_ data: Data, now: Date = Date()) -> Bool {
    guard (try? WidgetSnapshot.decode(data)) != nil else { return false }
    var error: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: snapshotURL, options: .forReplacing, error: &error) { url in
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try? data.write(to: url, options: [.atomic])
    }
    refreshRequested = false
    lastFetchAt = now
    return true
  }

  public func deleteAll() {
    queue.clear()
    var error: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: snapshotURL, options: .forDeleting, error: &error) { url in
      try? FileManager.default.removeItem(at: url)
    }
    for key in [Keys.authFailed, Keys.lastFetchAt, Keys.refreshRequested, Keys.pendingPushToken, Keys.registeredPushToken] {
      defaults.removeObject(forKey: key)
    }
  }

  /// Snapshot plus queue overlay: what widgets render.
  public func renderedSnapshot() -> WidgetSnapshot? {
    guard let snapshot = readSnapshot() else { return nil }
    return WidgetOverlay.apply(snapshot, ops: queue.readOps())
  }

  // MARK: Flags

  enum Keys {
    static let authFailed = "widget.auth_failed"
    static let lastFetchAt = "widget.last_fetch_at"
    static let refreshRequested = "widget.refresh_requested"
    /// iOS-only additions: the app signed out (widgets say "Sign in"), and a
    /// WidgetKit push token waiting for a credential to register with.
    static let signedOut = "widget.signed_out"
    static let pendingPushToken = "widget.pending_push_token"
    static let registeredPushToken = "widget.registered_push_token"
  }

  public var authFailed: Bool {
    get { defaults.bool(forKey: Keys.authFailed) }
    set { defaults.set(newValue, forKey: Keys.authFailed) }
  }

  public var refreshRequested: Bool {
    get { defaults.bool(forKey: Keys.refreshRequested) }
    set { defaults.set(newValue, forKey: Keys.refreshRequested) }
  }

  public var signedOut: Bool {
    get { defaults.bool(forKey: Keys.signedOut) }
    set { defaults.set(newValue, forKey: Keys.signedOut) }
  }

  public var lastFetchAt: Date? {
    get {
      let seconds = defaults.double(forKey: Keys.lastFetchAt)
      return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }
    set {
      if let newValue {
        defaults.set(newValue.timeIntervalSince1970, forKey: Keys.lastFetchAt)
      } else {
        defaults.removeObject(forKey: Keys.lastFetchAt)
      }
    }
  }

  public var pendingPushToken: String? {
    get { defaults.string(forKey: Keys.pendingPushToken) }
    set { defaults.set(newValue, forKey: Keys.pendingPushToken) }
  }

  /// The WidgetKit push token the server last accepted. The server keeps it
  /// across credential re-issues for the same device, so it is only sent
  /// again when it changes.
  public var registeredPushToken: String? {
    get { defaults.string(forKey: Keys.registeredPushToken) }
    set { defaults.set(newValue, forKey: Keys.registeredPushToken) }
  }

  /// Reads and clears the 401 flag (the `consumeAuthFailure` channel call).
  public func consumeAuthFailure() -> Bool {
    let failed = authFailed
    if failed { authFailed = false }
    return failed
  }

  /// True when a widget should fetch before rendering.
  public func needsRefresh(now: Date = Date()) -> Bool {
    if refreshRequested { return true }
    guard let last = lastFetchAt else { return true }
    return now.timeIntervalSince(last) > WidgetConstants.staleAfter
  }
}
