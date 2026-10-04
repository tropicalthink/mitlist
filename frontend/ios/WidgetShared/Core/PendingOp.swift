import Foundation

/// One line of the pending-ops queue (plan 047, contract C2).
///
/// Backed by the decoded JSON object so fields this build does not know
/// survive a rewrite. `body` is the exact request body: it is generated once,
/// when the op is created, and sent verbatim by the widget and by the app.
public struct PendingOp {
  public enum State: String {
    case pending, delivered, failed
  }

  public enum OpType: String {
    case listItemCheck = "list_item.check"
    case listItemAdd = "list_item.add"
    case choreComplete = "chore.complete"
  }

  public private(set) var fields: [String: Any]

  public init(fields: [String: Any]) {
    self.fields = fields
  }

  /// Parses one queue line. Returns nil for blank or malformed lines and for
  /// lines without an `op_id`.
  public init?(line: String) {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let opID = object["op_id"] as? String, !opID.isEmpty
    else { return nil }
    fields = object
  }

  public func jsonLine() -> String? {
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: fields, options: [.sortedKeys, .withoutEscapingSlashes])
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  // MARK: Fields

  public var opID: String { fields["op_id"] as? String ?? "" }
  public var createdAt: String? { fields["created_at"] as? String }
  public var createdDate: Date? { createdAt.flatMap(WidgetDate.parse) }
  public var source: String? { fields["source"] as? String }
  public var typeRaw: String { fields["type"] as? String ?? "" }
  public var type: OpType? { OpType(rawValue: typeRaw) }
  public var householdID: String? { fields["household_id"] as? String }
  public var listID: String? { fields["list_id"] as? String }
  public var itemID: String? { fields["item_id"] as? String }
  public var choreID: String? { fields["chore_id"] as? String }
  public var name: String? { fields["name"] as? String }
  public var method: String { fields["method"] as? String ?? "POST" }
  public var path: String { fields["path"] as? String ?? "" }
  public var body: String { fields["body"] as? String ?? "" }
  public var attempts: Int { (fields["attempts"] as? NSNumber)?.intValue ?? 0 }
  public var lastError: String? { fields["last_error"] as? String }
  public var deliveredAt: String? { fields["delivered_at"] as? String }
  public var deliveredDate: Date? { deliveredAt.flatMap(WidgetDate.parse) }
  public var response: String? { fields["response"] as? String }

  /// A missing or unknown state counts as pending: the op has not been
  /// confirmed delivered.
  public var state: State {
    (fields["state"] as? String).flatMap(State.init(rawValue:)) ?? .pending
  }

  /// The `id` in the stored response of a delivered `list_item.add`.
  public var responseItemID: String? {
    guard let response, let data = response.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return object["id"] as? String
  }

  public var responseItemName: String? {
    guard let response, let data = response.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return object["name"] as? String
  }

  // MARK: Mutation

  public mutating func set(_ key: String, _ value: Any?) {
    if let value { fields[key] = value } else { fields.removeValue(forKey: key) }
  }

  public mutating func markAttempt(error: String?) {
    set("attempts", attempts + 1)
    set("last_error", error)
  }

  // MARK: Creation

  /// `{"checked":true}` for `PATCH /lists/{list}/items/{item}`.
  public static func check(
    householdID: String, listID: String, itemID: String, source: String, now: Date = Date()
  ) -> PendingOp {
    make(
      type: .listItemCheck, source: source, householdID: householdID, now: now,
      method: "PATCH", path: "/lists/\(listID)/items/\(itemID)", body: #"{"checked":true}"#,
      extra: ["list_id": listID, "item_id": itemID])
  }

  /// `{"name":…}` for `POST /lists/{list}/items`.
  public static func add(
    householdID: String, listID: String, name: String, source: String, now: Date = Date()
  ) -> PendingOp {
    let bodyData =
      (try? JSONSerialization.data(withJSONObject: ["name": name], options: [.withoutEscapingSlashes]))
      ?? Data(#"{"name":""}"#.utf8)
    return make(
      type: .listItemAdd, source: source, householdID: householdID, now: now,
      method: "POST", path: "/lists/\(listID)/items", body: String(decoding: bodyData, as: UTF8.self),
      extra: ["list_id": listID, "name": name])
  }

  /// `{}` for `POST /chores/{chore}/complete`: the handler rejects an empty
  /// body.
  public static func completeChore(
    householdID: String, choreID: String, source: String, now: Date = Date()
  ) -> PendingOp {
    make(
      type: .choreComplete, source: source, householdID: householdID, now: now,
      method: "POST", path: "/chores/\(choreID)/complete", body: "{}",
      extra: ["chore_id": choreID])
  }

  private static func make(
    type: OpType, source: String, householdID: String, now: Date,
    method: String, path: String, body: String, extra: [String: Any]
  ) -> PendingOp {
    var fields: [String: Any] = [
      "op_id": UUID().uuidString.lowercased(),
      "created_at": WidgetDate.format(now),
      "source": source,
      "type": type.rawValue,
      "household_id": householdID,
      "method": method,
      "path": path,
      "body": body,
      "state": State.pending.rawValue,
      "attempts": 0,
    ]
    for (key, value) in extra { fields[key] = value }
    return PendingOp(fields: fields)
  }
}

/// How a delivery attempt's HTTP status maps onto an op (C3/C4).
public enum DeliveryOutcome: Equatable {
  /// 2xx.
  case delivered
  /// 400/403/404/409/422: never retried.
  case failed
  /// No response, a timeout, 5xx, 408, 429…: retried later.
  case retry
  /// 401: the credential is dead. Kept for the app to deliver.
  case authFailed

  public static func forStatus(_ status: Int?) -> DeliveryOutcome {
    guard let status else { return .retry }
    switch status {
    case 200..<300: return .delivered
    case 401: return .authFailed
    case 400, 403, 404, 409, 422: return .failed
    default: return .retry
    }
  }

  /// Applies the outcome of one attempt to [op].
  public static func apply(
    _ outcome: DeliveryOutcome, to op: inout PendingOp, status: Int?, responseBody: Data?,
    error: String?, now: Date = Date()
  ) {
    switch outcome {
    case .delivered:
      op.set("state", PendingOp.State.delivered.rawValue)
      op.set("attempts", op.attempts + 1)
      op.set("last_error", nil)
      op.set("delivered_at", WidgetDate.format(now))
      if let responseBody, responseBody.count <= WidgetConstants.maxStoredResponseBytes,
        let text = String(data: responseBody, encoding: .utf8)
      {
        op.set("response", text)
      } else {
        op.set("response", nil)
      }
    case .failed:
      op.set("state", PendingOp.State.failed.rawValue)
      op.markAttempt(error: status.map(String.init) ?? error ?? "failed")
    case .authFailed:
      op.set("state", PendingOp.State.pending.rawValue)
      op.markAttempt(error: "401")
    case .retry:
      op.set("state", PendingOp.State.pending.rawValue)
      op.markAttempt(error: status.map(String.init) ?? error ?? "offline")
    }
  }
}
