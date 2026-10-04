import Foundation

/// The pending-ops queue file (plan 047, contract C2).
///
/// The widget extension, Siri and the app all touch this file, possibly at
/// the same moment, so every read-modify-write runs inside one
/// `NSFileCoordinator` write and replaces the file atomically. The in-process
/// lock keeps two threads of the same process from interleaving.
public final class PendingOpsQueue {
  public let fileURL: URL
  private let lock = NSLock()

  public init(directory: URL) {
    fileURL = directory.appendingPathComponent(WidgetConstants.pendingOpsFileName)
  }

  // MARK: Pure helpers (tested against contracts/widgets)

  public static func parse(_ text: String) -> [PendingOp] {
    text.split(whereSeparator: \.isNewline).compactMap { PendingOp(line: String($0)) }
  }

  public static func serialize(_ ops: [PendingOp]) -> String {
    let lines = ops.compactMap { $0.jsonLine() }
    return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
  }

  /// Drops every op created more than seven days ago (and ops whose
  /// `created_at` cannot be read): the server forgets idempotency keys after
  /// seven days, so a replay could duplicate the write.
  public static func prune(_ ops: [PendingOp], now: Date = Date()) -> [PendingOp] {
    ops.filter { op in
      guard let created = op.createdDate else { return false }
      return now.timeIntervalSince(created) <= WidgetConstants.opMaxAge
    }
  }

  // MARK: File access

  /// The raw, valid lines, oldest first.
  public func readLines() -> [String] {
    readOps().compactMap { $0.jsonLine() }
  }

  public func readOps() -> [PendingOp] {
    lock.lock()
    defer { lock.unlock() }
    var result: [PendingOp] = []
    var coordinationError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      readingItemAt: fileURL, options: [], error: &coordinationError
    ) { url in
      result = Self.parse(Self.readText(url))
    }
    return result
  }

  /// Runs [body] on the current ops and writes the result back atomically.
  /// The ops are pruned first.
  @discardableResult
  public func mutate<T>(_ body: (inout [PendingOp]) -> T) -> T? {
    lock.lock()
    defer { lock.unlock() }
    var output: T?
    var coordinationError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: fileURL, options: .forMerging, error: &coordinationError
    ) { url in
      var ops = Self.prune(Self.parse(Self.readText(url)))
      output = body(&ops)
      Self.write(Self.serialize(ops), to: url)
    }
    return output
  }

  public func append(_ op: PendingOp) {
    mutate { $0.append(op) }
  }

  public func update(opID: String, _ change: (inout PendingOp) -> Void) {
    mutate { ops in
      if let index = ops.firstIndex(where: { $0.opID == opID }) { change(&ops[index]) }
    }
  }

  public func remove(opIDs: Set<String>) {
    guard !opIDs.isEmpty else { return }
    mutate { ops in ops.removeAll { opIDs.contains($0.opID) } }
  }

  public func clear() {
    lock.lock()
    defer { lock.unlock() }
    var coordinationError: NSError?
    NSFileCoordinator(filePresenter: nil).coordinate(
      writingItemAt: fileURL, options: .forDeleting, error: &coordinationError
    ) { url in
      try? FileManager.default.removeItem(at: url)
    }
  }

  private static func readText(_ url: URL) -> String {
    guard let data = try? Data(contentsOf: url) else { return "" }
    return String(decoding: data, as: UTF8.self)
  }

  private static func write(_ text: String, to url: URL) {
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? Data(text.utf8).write(to: url, options: [.atomic])
  }
}
