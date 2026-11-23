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
  /// [keepTicks]: the fetch right after a widget tap keeps the rows it
  /// ticked on screen; every other refresh clears them.
  @discardableResult
  public func writeSnapshot(_ data: Data, now: Date = Date(), keepTicks: Bool = false) -> Bool {
    guard (try? WidgetSnapshot.decode(data)) != nil else { return false }
    var error: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: snapshotURL, options: .forReplacing, error: &error) { url in
      WidgetFiles.write(data, to: url)
    }
    refreshRequested = false
    lastFetchAt = now
    if !keepTicks { ticks = [] }
    return true
  }

  public func deleteAll() {
    queue.clear()
    var error: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: snapshotURL, options: .forDeleting, error: &error) { url in
      try? FileManager.default.removeItem(at: url)
    }
    for key in [
      Keys.authFailed, Keys.lastFetchAt, Keys.refreshRequested, Keys.pendingPushToken, Keys.registeredPushToken,
      Keys.ticks, Keys.clearReason,
    ] {
      defaults.removeObject(forKey: key)
    }
  }

  /// Snapshot plus queue overlay plus rows ticked on the widget: what
  /// widgets render (see [WidgetOverlay.display]).
  public func renderedSnapshot(now: Date = Date()) -> WidgetSnapshot? {
    guard let snapshot = readSnapshot() else { return nil }
    return WidgetOverlay.display(snapshot, ops: queue.readOps(), ticks: ticks, now: now)
  }

  // MARK: Ticked rows (iOS display only)

  public var ticks: [WidgetTick] {
    get { WidgetTick.decode(defaults.data(forKey: Keys.ticks)) }
    set {
      if newValue.isEmpty {
        defaults.removeObject(forKey: Keys.ticks)
      } else {
        defaults.set(WidgetTick.encode(newValue), forKey: Keys.ticks)
      }
    }
  }

  /// Remembers a row ticked on the widget, replacing an older tick of the
  /// same row and dropping expired ones.
  public func recordTick(_ tick: WidgetTick, now: Date = Date()) {
    var current = ticks.filter { $0.isLive(now: now) && !($0.kind == tick.kind && $0.id == tick.id) }
    current.append(tick)
    ticks = Array(current.suffix(40))
  }

  /// When the oldest live tick expires: the widget redraws then.
  public func nextTickExpiry(now: Date = Date()) -> Date? {
    ticks.filter { $0.isLive(now: now) }.map { $0.date.addingTimeInterval(WidgetConstants.tickFeedbackDuration) }.min()
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
    /// Why the app last cleared the widgets (`clearAll` argument `reason`),
    /// e.g. `not_remembered`.
    static let clearReason = "widget.clear_reason"
    /// Rows ticked on a widget (JSON [WidgetTick]).
    static let ticks = "widget.recent_ticks"
  }

  /// The `reason` the app gave when it last cleared the widgets, if any.
  public var clearReason: String? {
    get { defaults.string(forKey: Keys.clearReason) }
    set { defaults.set(newValue, forKey: Keys.clearReason) }
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

  /// True when a widget should fetch before rendering: a push or the app
  /// asked for it, or the last fetch is older than [after].
  public func needsRefresh(now: Date = Date(), after: TimeInterval = WidgetConstants.refetchOnReloadAfter) -> Bool {
    if refreshRequested { return true }
    guard let last = lastFetchAt else { return true }
    let age = now.timeIntervalSince(last)
    // A clock set back makes the age negative: refetch.
    return age > after || age < 0
  }
}

/// File writes for the App Group. Widgets read these files while the phone
/// is locked (Lock Screen, StandBy, a push at night), so they are kept
/// readable after the first unlock, the same class as the credential in the
/// Keychain, whatever the app's default data protection becomes.
enum WidgetFiles {
  static func write(_ data: Data, to url: URL) {
    let directory = url.deletingLastPathComponent()
    #if os(iOS)
      try? FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
      try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    #else
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try? data.write(to: url, options: [.atomic])
    #endif
  }
}
