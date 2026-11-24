import Foundation

#if canImport(WidgetKit)
  import WidgetKit
#endif

/// Delivers queued ops and refreshes the snapshot with the widget
/// credential (plan 047, contract C4 "Native delivery" / "Native refresh").
/// Runs in the widget extension (timelines, widget buttons) and in the app
/// (Siri, `requestRefresh`, `setCredential`).
public enum WidgetSync {
  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = WidgetRequests.timeout
    configuration.timeoutIntervalForResource = WidgetRequests.timeout + 4
    configuration.waitsForConnectivity = false
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    return URLSession(configuration: configuration)
  }()

  /// One delivery pass at a time per process. A widget button and the
  /// timeline it triggers would otherwise send the same op twice at once,
  /// and the server answers the second with "still processing".
  private actor Gate {
    private var running = false
    func enter() -> Bool {
      if running { return false }
      running = true
      return true
    }
    func leave() { running = false }
  }

  private static let gate = Gate()

  /// One snapshot fetch at a time per process: every placed widget asks for
  /// its timeline at once after a reload, and they share the one fetch.
  private actor FetchGate {
    private var inFlight: Task<Bool, Never>?

    func fetch(_ body: @escaping @Sendable () async -> Bool) async -> Bool {
      if let inFlight { return await inFlight.value }
      let task = Task { await body() }
      inFlight = task
      let value = await task.value
      inFlight = nil
      return value
    }
  }

  private static let fetchGate = FetchGate()

  private struct Response {
    var status: Int?
    var body: Data?
    var retryAfter = false
    var errorText: String?
    /// The credential the final attempt used.
    var credential: WidgetCredential
  }

  /// Sends a request built for [credential]. A 401 caused by the app having
  /// replaced the credential meanwhile is retried once with the new one
  /// ([WidgetAuthRetry]).
  private static func send(
    credential: WidgetCredential, _ build: (WidgetCredential) -> URLRequest?
  ) async -> Response? {
    var used = credential
    var retried = false
    while true {
      guard let request = build(used) else { return nil }
      var response = Response(credential: used)
      do {
        let (data, urlResponse) = try await session.data(for: request)
        let http = urlResponse as? HTTPURLResponse
        response.status = http?.statusCode
        response.retryAfter = http?.value(forHTTPHeaderField: "Retry-After") != nil
        response.body = data
      } catch {
        response.errorText = (error as? URLError).map { "network \($0.code.rawValue)" } ?? "network"
      }
      if response.status == 401 {
        let stored = WidgetCredentialStore.load()
        if WidgetAuthRetry.shouldRetry(usedToken: used.token, stored: stored, alreadyRetried: retried), let stored {
          used = stored
          retried = true
          continue
        }
      }
      return response
    }
  }

  /// A 401 that survived the retry: flag it only while the failing token is
  /// still the stored one.
  private static func noteUnauthorized(_ response: Response, storage: WidgetStorage) {
    if WidgetAuthRetry.shouldFlag(usedToken: response.credential.token, stored: WidgetCredentialStore.load()) {
      storage.authFailed = true
    }
  }

  /// A 2xx with the stored credential proves it works: an earlier 401 flag
  /// (a server blip, or a rotation race on an older build) is stale.
  private static func noteAuthorized(_ response: Response, storage: WidgetStorage) {
    if storage.authFailed, WidgetCredentialStore.load()?.token == response.credential.token {
      storage.authFailed = false
    }
  }

  /// Delivers pending ops oldest first. Stops at the first op that could not
  /// reach the server (later ops may depend on it) and on a 401. Returns how
  /// many ops were delivered.
  @discardableResult
  public static func deliverPending(storage: WidgetStorage) async -> Int {
    guard await gate.enter() else { return 0 }
    let delivered = await deliverPendingNow(storage: storage)
    await gate.leave()
    return delivered
  }

  private static func deliverPendingNow(storage: WidgetStorage) async -> Int {
    guard let credential = WidgetCredentialStore.load() else { return 0 }
    guard credential.isUsable else {
      storage.authFailed = true
      return 0
    }
    var current = credential
    var delivered = 0
    for candidate in storage.queue.readOps() where candidate.state == .pending {
      // Another process may have delivered it since the read above.
      guard let op = storage.queue.readOps().first(where: { $0.opID == candidate.opID }),
        op.state == .pending,
        let response = await send(credential: current, { WidgetRequests.delivery(for: op, credential: $0) })
      else { continue }
      current = response.credential

      var outcome = DeliveryOutcome.forStatus(response.status)
      // A 409 with Retry-After means the same op is still being processed
      // (sent by the app or another process a moment ago): not a failure.
      if response.status == 409 && response.retryAfter { outcome = .retry }

      storage.queue.update(opID: op.opID) { op in
        // Never downgrade an op another process already delivered.
        guard op.state != .delivered else { return }
        DeliveryOutcome.apply(
          outcome, to: &op, status: response.status, responseBody: response.body, error: response.errorText)
      }

      switch outcome {
      case .delivered:
        noteAuthorized(response, storage: storage)
        delivered += 1
      case .failed:
        continue
      case .authFailed:
        noteUnauthorized(response, storage: storage)
        return delivered
      case .retry:
        return delivered
      }
    }
    return delivered
  }

  /// `GET /widget/snapshot` with the widget credential. Returns true when a
  /// new snapshot was written. [keepTicks]: see [WidgetStorage.writeSnapshot].
  @discardableResult
  public static func fetchSnapshot(storage: WidgetStorage, keepTicks: Bool = false) async -> Bool {
    await fetchGate.fetch { await fetchSnapshotNow(storage: storage, keepTicks: keepTicks) }
  }

  private static func fetchSnapshotNow(storage: WidgetStorage, keepTicks: Bool) async -> Bool {
    guard let credential = WidgetCredentialStore.load() else { return false }
    guard credential.isUsable else {
      storage.authFailed = true
      return false
    }
    guard let response = await send(credential: credential, { WidgetRequests.snapshot(credential: $0) }),
      let status = response.status
    else { return false }
    if status == 401 {
      noteUnauthorized(response, storage: storage)
      return false
    }
    guard (200..<300).contains(status), let body = response.body else { return false }
    noteAuthorized(response, storage: storage)
    return storage.writeSnapshot(body, keepTicks: keepTicks)
  }

  /// Registers a WidgetKit push token waiting in the App Group (C6).
  public static func registerPendingPushToken(storage: WidgetStorage) async {
    guard let token = storage.pendingPushToken, !token.isEmpty,
      let credential = WidgetCredentialStore.load(), credential.isUsable,
      let response = await send(credential: credential, { WidgetRequests.pushToken(token, credential: $0) }),
      let status = response.status
    else { return }
    if (200..<300).contains(status) {
      // Only if no newer token arrived meanwhile.
      if storage.pendingPushToken == token { storage.pendingPushToken = nil }
      storage.registeredPushToken = token
    }
  }

  /// Deliver, then refetch the snapshot, then reload every widget.
  /// [reload] is false inside a timeline request: that timeline already
  /// shows the result, and other widgets refetch on their own reload.
  public static func run(
    storage: WidgetStorage? = WidgetStorage.shared, fetch: Bool = true, keepTicks: Bool = false, reload: Bool = true
  ) async {
    guard let storage else { return }
    await deliverPending(storage: storage)
    if fetch { await fetchSnapshot(storage: storage, keepTicks: keepTicks) }
    await registerPendingPushToken(storage: storage)
    if reload { reloadWidgets() }
  }

  /// [run], abandoned after [seconds] so a timeline never waits on a dead
  /// network for long.
  public static func run(
    storage: WidgetStorage? = WidgetStorage.shared, fetch: Bool = true, keepTicks: Bool = false, reload: Bool = true,
    timeout seconds: Double
  ) async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await run(storage: storage, fetch: fetch, keepTicks: keepTicks, reload: reload) }
      group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
      await group.next()
      group.cancelAll()
    }
  }

  public static func reloadWidgets() {
    #if canImport(WidgetKit)
      WidgetCenter.shared.reloadAllTimelines()
    #endif
  }
}

/// What a tap on a widget, a Siri request or the quick-add control does
/// (plan 047, D4): change the widget's own display, queue the op, deliver
/// it with the widget credential, then refetch so the widget shows what
/// the rest of the household changed too.
public enum WidgetActions {
  public static func checkItem(householdID: String, listID: String, itemID: String, source: String) async {
    guard let storage = WidgetStorage.shared else { return }
    // Remember the row as drawn, so it stays ticked on the widget after the
    // refetch below drops it from the snapshot.
    if let list = storage.renderedSnapshot()?.household(householdID)?.lists.first(where: { $0.id == listID }),
      let index = list.items.firstIndex(where: { $0.id == itemID })
    {
      storage.recordTick(.item(list.items[index], listID: listID, householdID: householdID, index: index, at: Date()))
    }
    await enqueueAndDeliver(
      PendingOp.check(householdID: householdID, listID: listID, itemID: itemID, source: source), storage: storage,
      fetch: source == WidgetOpSource.widget)
  }

  public static func addItem(householdID: String, listID: String, name: String, source: String) async {
    guard let storage = WidgetStorage.shared else { return }
    await enqueueAndDeliver(
      PendingOp.add(householdID: householdID, listID: listID, name: name, source: source), storage: storage,
      fetch: source == WidgetOpSource.widget)
  }

  public static func completeChore(householdID: String, choreID: String, source: String) async {
    guard let storage = WidgetStorage.shared else { return }
    if let chores = storage.renderedSnapshot()?.household(householdID)?.chores,
      let index = chores.firstIndex(where: { $0.id == choreID })
    {
      storage.recordTick(.chore(chores[index], householdID: householdID, index: index, at: Date()))
    }
    await enqueueAndDeliver(
      PendingOp.completeChore(householdID: householdID, choreID: choreID, source: source), storage: storage,
      fetch: source == WidgetOpSource.widget)
  }

  /// [fetch]: a widget button refetches after delivering (the widget then
  /// also shows the rest of the household's changes); Siri answers without
  /// waiting for that.
  private static func enqueueAndDeliver(_ op: PendingOp, storage: WidgetStorage, fetch: Bool) async {
    storage.queue.append(op)
    // Show the change before the network round trip.
    WidgetSync.reloadWidgets()
    await WidgetSync.run(storage: storage, fetch: fetch, keepTicks: true, reload: true, timeout: fetch ? 15 : 8)
    WidgetSync.reloadWidgets()
  }
}
