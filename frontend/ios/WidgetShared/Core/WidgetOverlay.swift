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
