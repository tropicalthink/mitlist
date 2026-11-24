import Foundation

/// Applies the queue to a snapshot so widgets show the user's own taps at
/// once (plan 047, contract C2 "Overlay").
public enum WidgetOverlay {
  public static func apply(_ snapshot: WidgetSnapshot, ops: [PendingOp]) -> WidgetSnapshot {
    var result = snapshot
    let generated = snapshot.generatedDate
    for op in ops where affectsOverlay(op, snapshotGeneratedAt: generated) {
      guard let type = op.type,
        let householdIndex = result.households.firstIndex(where: { $0.id == op.householdID })
      else { continue }
      switch type {
      case .listItemCheck:
        guard let listIndex = listIndex(in: result.households[householdIndex], op.listID),
          let itemID = op.itemID
        else { continue }
        var list = result.households[householdIndex].lists[listIndex]
        let before = list.items.count
        list.items.removeAll { $0.id == itemID }
        if list.items.count < before { list.openCount = max(0, list.openCount - 1) }
        result.households[householdIndex].lists[listIndex] = list
      case .listItemAdd:
        guard let listIndex = listIndex(in: result.households[householdIndex], op.listID) else { continue }
        var list = result.households[householdIndex].lists[listIndex]
        let name = op.name ?? op.responseItemName ?? ""
        if op.state == .delivered, let serverID = op.responseItemID {
          if !list.items.contains(where: { $0.id == serverID }) {
            list.items.append(WidgetListItem(id: serverID, name: op.responseItemName ?? name))
            list.openCount += 1
          }
        } else if !list.items.contains(where: { $0.id == op.opID }) {
          // Not delivered yet (or delivered without a readable response):
          // shown greyed, with the op id standing in for the item id.
          list.items.append(WidgetListItem(id: op.opID, name: name, local: true))
          list.openCount += 1
        }
        result.households[householdIndex].lists[listIndex] = list
      case .choreComplete:
        guard let choreID = op.choreID else { continue }
        result.households[householdIndex].chores.removeAll { $0.id == choreID }
      }
    }
    return result
  }

  /// `failed` ops never count. A `delivered` op stops counting once a
  /// snapshot generated after its delivery is on disk: the server state
  /// already includes it.
  public static func affectsOverlay(_ op: PendingOp, snapshotGeneratedAt: Date?) -> Bool {
    switch op.state {
    case .failed:
      return false
    case .pending:
      return true
    case .delivered:
      guard let delivered = op.deliveredDate, let generated = snapshotGeneratedAt else { return true }
      return generated <= delivered
    }
  }

  private static func listIndex(in household: WidgetHousehold, _ listID: String?) -> Int? {
    guard let listID else { return nil }
    return household.lists.firstIndex { $0.id == listID }
  }
}

/// A row the person ticked on a widget, remembered so it can stay on the
/// widget, ticked and struck through, after a refresh has dropped it from
/// the snapshot (iOS only; not part of the C2 queue).
public struct WidgetTick: Codable, Equatable {
  public enum Kind: String, Codable {
    case item
    case chore
  }

  public var kind: Kind
  public var id: String
  public var householdID: String
  public var listID: String?
  /// The row as it was drawn when it was ticked.
  public var item: WidgetListItem?
  public var chore: WidgetChore?
  /// Its position in the list or chore order, to put it back in place.
  public var index: Int
  /// Epoch seconds.
  public var at: Double

  enum CodingKeys: String, CodingKey {
    case kind, id, index, at, item, chore
    case householdID = "household_id"
    case listID = "list_id"
  }

  public static func item(_ item: WidgetListItem, listID: String, householdID: String, index: Int, at: Date) -> WidgetTick {
    WidgetTick(
      kind: .item, id: item.id, householdID: householdID, listID: listID, item: item, chore: nil, index: index,
      at: at.timeIntervalSince1970)
  }

  public static func chore(_ chore: WidgetChore, householdID: String, index: Int, at: Date) -> WidgetTick {
    WidgetTick(
      kind: .chore, id: chore.id, householdID: householdID, listID: nil, item: nil, chore: chore, index: index,
      at: at.timeIntervalSince1970)
  }

  public var date: Date { Date(timeIntervalSince1970: at) }

  public func isLive(now: Date) -> Bool {
    let age = now.timeIntervalSince(date)
    return age >= -60 && age <= WidgetConstants.tickFeedbackDuration
  }

  public static func encode(_ ticks: [WidgetTick]) -> Data? { try? JSONEncoder().encode(ticks) }

  public static func decode(_ data: Data?) -> [WidgetTick] {
    guard let data else { return [] }
    return (try? JSONDecoder().decode([WidgetTick].self, from: data)) ?? []
  }
}

extension WidgetOverlay {
  /// What a widget draws: the C2 overlay, except that a ticked item or a
  /// completed chore stays in place, flagged `checked`/`done`, instead of
  /// disappearing; and rows ticked on the widget that a newer snapshot no
  /// longer has come back the same way until [WidgetTick.isLive] ends or the
  /// next refresh clears them. Counts follow the C2 overlay: a ticked item no
  /// longer counts as open.
  public static func display(
    _ snapshot: WidgetSnapshot, ops: [PendingOp], ticks: [WidgetTick] = [], now: Date = Date()
  ) -> WidgetSnapshot {
    var result = snapshot
    let generated = snapshot.generatedDate
    for op in ops where affectsOverlay(op, snapshotGeneratedAt: generated) {
      guard let type = op.type,
        let h = result.households.firstIndex(where: { $0.id == op.householdID })
      else { continue }
      switch type {
      case .listItemCheck:
        guard let l = displayListIndex(in: result.households[h], op.listID), let itemID = op.itemID,
          let i = result.households[h].lists[l].items.firstIndex(where: { $0.id == itemID }),
          !result.households[h].lists[l].items[i].checked
        else { continue }
        result.households[h].lists[l].items[i].checked = true
        result.households[h].lists[l].openCount = max(0, result.households[h].lists[l].openCount - 1)
      case .listItemAdd:
        // Same as the C2 overlay.
        let single = apply(
          WidgetSnapshot(version: result.version, generatedAt: result.generatedAt, households: [result.households[h]]),
          ops: [op])
        if let household = single.households.first { result.households[h] = household }
      case .choreComplete:
        guard let choreID = op.choreID,
          let c = result.households[h].chores.firstIndex(where: { $0.id == choreID })
        else { continue }
        result.households[h].chores[c].done = true
      }
    }

    for tick in ticks where tick.isLive(now: now) {
      guard let h = result.households.firstIndex(where: { $0.id == tick.householdID }) else { continue }
      switch tick.kind {
      case .item:
        guard var item = tick.item, let l = displayListIndex(in: result.households[h], tick.listID),
          !result.households[h].lists[l].items.contains(where: { $0.id == tick.id })
        else { continue }
        // Gone from the snapshot: the server has it ticked. It no longer
        // counts as open, so the count stays as the server sent it.
        item.checked = true
        item.local = nil
        var items = result.households[h].lists[l].items
        items.insert(item, at: min(max(0, tick.index), items.count))
        result.households[h].lists[l].items = items
      case .chore:
        guard var chore = tick.chore else { continue }
        // Still there: the C2 overlay (pending op) already flags it, or a
        // later turn of the same chore is due (different due_at): show that.
        guard !result.households[h].chores.contains(where: { $0.id == tick.id }) else { continue }
        chore.done = true
        var chores = result.households[h].chores
        chores.insert(chore, at: min(max(0, tick.index), chores.count))
        result.households[h].chores = chores
      }
    }
    return result
  }

  private static func displayListIndex(in household: WidgetHousehold, _ listID: String?) -> Int? {
    guard let listID else { return nil }
    return household.lists.firstIndex { $0.id == listID }
  }
}
