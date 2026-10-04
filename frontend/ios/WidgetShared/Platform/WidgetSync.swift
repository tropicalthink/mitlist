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
    var delivered = 0
    for candidate in storage.queue.readOps() where candidate.state == .pending {
      // Another process may have delivered it since the read above.
      guard let op = storage.queue.readOps().first(where: { $0.opID == candidate.opID }),
        op.state == .pending,
        let request = WidgetRequests.delivery(for: op, credential: credential)
      else { continue }

      var status: Int?
      var body: Data?
      var errorText: String?
      var retryAfter = false
      do {
        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        status = http?.statusCode
        retryAfter = http?.value(forHTTPHeaderField: "Retry-After") != nil
        body = data
      } catch {
        errorText = (error as? URLError).map { "network \($0.code.rawValue)" } ?? "network"
      }

      var outcome = DeliveryOutcome.forStatus(status)
      // A 409 with Retry-After means the same op is still being processed
      // (sent by the app or another process a moment ago): not a failure.
      if status == 409 && retryAfter { outcome = .retry }

      storage.queue.update(opID: op.opID) { current in
        // Never downgrade an op another process already delivered.
        guard current.state != .delivered else { return }
        DeliveryOutcome.apply(outcome, to: &current, status: status, responseBody: body, error: errorText)
      }

      switch outcome {
      case .delivered:
        delivered += 1
      case .failed:
        continue
      case .authFailed:
        storage.authFailed = true
        return delivered
      case .retry:
        return delivered
      }
    }
    return delivered
  }

  /// `GET /widget/snapshot` with the widget credential. Returns true when a
  /// new snapshot was written.
  @discardableResult
  public static func fetchSnapshot(storage: WidgetStorage) async -> Bool {
    guard let credential = WidgetCredentialStore.load() else { return false }
    guard credential.isUsable, let request = WidgetRequests.snapshot(credential: credential) else {
      storage.authFailed = true
      return false
    }
    do {
      let (data, response) = try await session.data(for: request)
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      if status == 401 {
        storage.authFailed = true
        return false
      }
      guard (200..<300).contains(status) else { return false }
      return storage.writeSnapshot(data)
    } catch {
      return false
    }
  }

  /// Registers a WidgetKit push token waiting in the App Group (C6).
  public static func registerPendingPushToken(storage: WidgetStorage) async {
    guard let token = storage.pendingPushToken, !token.isEmpty,
      let credential = WidgetCredentialStore.load(), credential.isUsable,
      let request = WidgetRequests.pushToken(token, credential: credential)
    else { return }
    if let (_, response) = try? await session.data(for: request),
      let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status)
    {
      storage.pendingPushToken = nil
      storage.registeredPushToken = token
    }
  }

  /// Deliver, then refetch the snapshot, then reload every widget.
  public static func run(storage: WidgetStorage? = WidgetStorage.shared, fetch: Bool = true) async {
    guard let storage else { return }
    await deliverPending(storage: storage)
    if fetch { await fetchSnapshot(storage: storage) }
    await registerPendingPushToken(storage: storage)
    reloadWidgets()
  }

  /// [run], abandoned after [seconds] so a timeline never waits on a dead
  /// network for long.
  public static func run(storage: WidgetStorage? = WidgetStorage.shared, fetch: Bool = true, timeout seconds: Double) async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await run(storage: storage, fetch: fetch) }
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
/// it with the widget credential.
public enum WidgetActions {
  public static func checkItem(householdID: String, listID: String, itemID: String, source: String) async {
    await enqueueAndDeliver(
      PendingOp.check(householdID: householdID, listID: listID, itemID: itemID, source: source))
  }

  public static func addItem(householdID: String, listID: String, name: String, source: String) async {
    await enqueueAndDeliver(PendingOp.add(householdID: householdID, listID: listID, name: name, source: source))
  }

  public static func completeChore(householdID: String, choreID: String, source: String) async {
    await enqueueAndDeliver(PendingOp.completeChore(householdID: householdID, choreID: choreID, source: source))
  }

  private static func enqueueAndDeliver(_ op: PendingOp) async {
    guard let storage = WidgetStorage.shared else { return }
    storage.queue.append(op)
    // Show the change before the network round trip.
    WidgetSync.reloadWidgets()
    await WidgetSync.deliverPending(storage: storage)
    WidgetSync.reloadWidgets()
  }
}
