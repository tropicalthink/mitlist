import Foundation

/// The widget credential the app hands over (plan 047, contract C4).
public struct WidgetCredential: Codable, Equatable {
  public var token: String
  public var expiresAt: String?
  /// Exactly the app's Dio base URL (`…/api/v1`), so a widget request's URI
  /// equals the app's when it replays the same op.
  public var apiBaseURL: String
  public var userID: String?
  public var deviceID: String?

  enum CodingKeys: String, CodingKey {
    case token
    case expiresAt = "expires_at"
    case apiBaseURL = "api_base_url"
    case userID = "user_id"
    case deviceID = "device_id"
  }

  public init(token: String, expiresAt: String?, apiBaseURL: String, userID: String?, deviceID: String?) {
    self.token = token
    self.expiresAt = expiresAt
    self.apiBaseURL = apiBaseURL
    self.userID = userID
    self.deviceID = deviceID
  }

  public func isExpired(now: Date = Date()) -> Bool {
    guard let expiry = expiresAt.flatMap(WidgetDate.parse) else { return false }
    return expiry <= now
  }

  public var isUsable: Bool { !token.isEmpty && !apiBaseURL.isEmpty && !isExpired() }

  /// [path] starts with "/"; a trailing slash on the base is tolerated.
  public func url(_ path: String) -> URL? {
    var base = apiBaseURL
    while base.hasSuffix("/") { base.removeLast() }
    return URL(string: base + path)
  }
}

/// What to do with a 401 (C3). The app replaces the widget credential every
/// few days and the server revokes the old one at once, so a request that
/// was already in flight with the old token gets a 401 although nothing is
/// wrong: retry it once with the new one, and only report a dead credential
/// when the token that failed is still the stored one.
public enum WidgetAuthRetry {
  /// Retry once when the stored credential is a different, usable one.
  public static func shouldRetry(usedToken: String, stored: WidgetCredential?, alreadyRetried: Bool) -> Bool {
    guard !alreadyRetried, let stored, stored.isUsable else { return false }
    return stored.token != usedToken
  }

  /// Raise `widget.auth_failed` only when the failing token is still the
  /// stored one (not replaced meanwhile, not deleted by a sign-out).
  public static func shouldFlag(usedToken: String, stored: WidgetCredential?) -> Bool {
    stored?.token == usedToken
  }
}

/// Builds the exact HTTP requests widgets send (C4 "Native delivery").
public enum WidgetRequests {
  public static let timeout: TimeInterval = 8

  /// The op's stored method, path and body bytes, with the widget
  /// credential, household and idempotency headers.
  public static func delivery(for op: PendingOp, credential: WidgetCredential) -> URLRequest? {
    guard !op.path.isEmpty, let url = credential.url(op.path) else { return nil }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
    request.httpMethod = op.method
    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
    if let household = op.householdID, !household.isEmpty {
      request.setValue(household, forHTTPHeaderField: "X-Mitlist-Group-ID")
    }
    request.setValue(op.opID, forHTTPHeaderField: "Idempotency-Key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = Data(op.body.utf8)
    return request
  }

  public static func snapshot(credential: WidgetCredential) -> URLRequest? {
    guard let url = credential.url("/widget/snapshot") else { return nil }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
    request.httpMethod = "GET"
    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  /// `PUT /widget/push-token` (C6, WidgetKit push).
  public static func pushToken(_ hexToken: String, credential: WidgetCredential) -> URLRequest? {
    guard let url = credential.url("/widget/push-token"),
      let body = try? JSONSerialization.data(withJSONObject: ["token": hexToken])
    else { return nil }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
    request.httpMethod = "PUT"
    request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body
    return request
  }
}
