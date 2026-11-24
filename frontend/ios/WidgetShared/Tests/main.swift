import Foundation

// Logic tests for the Foundation-only widget core, checked against the
// shared fixtures in contracts/widgets (plan 047). Run with
// `frontend/ios/WidgetShared/Tests/run.sh`.

var failures = 0
var passes = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #file, line: Int = #line) {
  if condition() {
    passes += 1
  } else {
    failures += 1
    print("FAIL (line \(line)): \(message)")
  }
}

let fixtures = URL(fileURLWithPath: CommandLine.arguments[1])
func fixture(_ name: String) -> Data {
  guard let data = try? Data(contentsOf: fixtures.appendingPathComponent(name)) else {
    print("missing fixture \(name)")
    exit(2)
  }
  return data
}

let snapshotData = fixture("snapshot_v1.json")
let opsText = String(decoding: fixture("pending_ops_v1.jsonl"), as: UTF8.self)
let expected = try! JSONSerialization.jsonObject(with: fixture("overlay_expected_v1.json")) as! [String: Any]

let household1 = "11111111-1111-4111-8111-111111111111"
let groceries = "22222222-2222-4222-8222-222222222222"

// MARK: Snapshot parse (C1)

let snapshot = try! WidgetSnapshot.decode(snapshotData)
check(snapshot.version == 1, "version")
check(snapshot.source == "server", "source")
check(snapshot.generatedDate == WidgetDate.parse("2026-10-02T09:00:00Z"), "generated_at parses")
check(snapshot.defaults?.householdID == household1, "defaults.household_id")
check(snapshot.defaults?.listID == groceries, "defaults.list_id")
check(snapshot.households.count == 2, "two households")
let flat = snapshot.households[0]
check(flat.name == "Flat 3B", "household name")
check(flat.lists.count == 2, "two lists")
check(flat.lists[0].openCount == 3 && flat.lists[0].items.count == 3, "groceries counts")
check(flat.lists[0].items[0].quantity == 2 && flat.lists[0].items[0].unit == "l", "quantity/unit")
check(flat.lists[0].items[0].quantityText == "2 l", "quantity text")
check(flat.lists[0].items[1].quantityText == nil, "single item has no quantity text")
check(flat.lists[0].items[2].name == "Coffee beans \"dark\" / 1 kg", "escaped name")
check(flat.lists[0].items[1].addedByName == nil, "optional added_by_name omitted")
check(flat.chores.count == 2 && flat.chores[0].isMine && !flat.chores[1].isMine, "chores")
check(flat.chores[0].nextAssigneeName == "Alex" && flat.chores[1].nextAssigneeName == nil, "next assignee")
check(flat.tonightMeal?.title == "Lasagne" && flat.tonightMeal?.slot == "dinner", "tonight_meal")
check(flat.balance?.netCents == -1200 && flat.balance?.settleWithName == "Sam" && flat.balance?.settleCents == 1200, "balance")
check(snapshot.households[1].lists.isEmpty && snapshot.households[1].tonightMeal == nil, "second household")
check(snapshot.resolveList(nil)?.1.id == groceries, "default list resolves")
check(snapshot.resolveList("22222222-2222-4222-8222-222222222223")?.1.name == "Weekend jobs", "configured list resolves")
check(snapshot.resolveList("missing")?.1.id == groceries, "missing list falls back to default")
check(snapshot.resolveHousehold("66666666-6666-4666-8666-666666666666")?.name == "Mum & Dad", "configured household")

// Tolerance: unknown fields, an "app" source, Go's nanosecond timestamps,
// missing optional arrays.
let tolerant = """
  {"version":1,"generated_at":"2026-10-02T09:00:00.123456789Z","source":"app","future_field":{"x":1},
   "households":[{"id":"h","name":"H","future":true,"lists":[{"id":"l","name":"L","open_count":0}]}]}
  """
let tolerantSnapshot = try? WidgetSnapshot.decode(Data(tolerant.utf8))
check(tolerantSnapshot != nil, "tolerant decode")
check(tolerantSnapshot?.source == "app", "app source accepted")
check(tolerantSnapshot?.households.first?.chores.isEmpty == true, "missing chores defaults to empty")
check(tolerantSnapshot?.generatedDate != nil, "nanosecond timestamp parses")
check(WidgetDate.parse("2026-10-02T11:00:00+02:00") == WidgetDate.parse("2026-10-02T09:00:00Z"), "offset timestamp")
// Microseconds with an offset, as the server sent before it normalised to
// whole-second UTC.
check(WidgetDate.parse("2026-10-03T23:57:45.643731+02:00") == WidgetDate.parse("2026-10-03T21:57:45.643Z"), "microseconds + offset")
check(WidgetDate.parse("2026-10-03T21:57:45Z") != nil && WidgetDate.parse("2026-10-03T21:57:45.5Z") != nil, "whole and short fractions")
check(WidgetDate.parse("") == nil && WidgetDate.parse("yesterday") == nil, "garbage timestamps")
let microQueue = PendingOpsQueue.parse(#"{"op_id":"m","created_at":"2026-10-03T23:57:45.643731+02:00","delivered_at":"2026-10-03T21:57:46.1234567Z","state":"delivered"}"#)
check(microQueue.first?.createdDate != nil && microQueue.first?.deliveredDate != nil, "queue timestamps with long fractions")

// MARK: Queue parse (C2)

let ops = PendingOpsQueue.parse(opsText)
check(ops.count == 5, "five ops parsed")
check(ops[0].type == .listItemCheck && ops[0].state == .pending && ops[0].attempts == 1, "op 1")
check(ops[0].body == #"{"checked":true}"#, "check body verbatim")
check(ops[1].type == .listItemAdd && ops[1].name == "Butter" && ops[1].body == #"{"name":"Butter"}"#, "op 2")
check(ops[2].state == .delivered && ops[2].responseItemID == "88888888-8888-4888-8888-888888888888", "op 3 response id")
check(ops[3].type == .choreComplete && ops[3].body == "{}" && ops[3].method == "POST", "op 4")
check(ops[4].state == .failed && ops[4].lastError == "404", "op 5")
check(PendingOpsQueue.parse("\n  \nnot json\n{\"no_id\":1}\n").isEmpty, "garbage lines skipped")

// Round trip keeps every field, including unknown ones and the exact body.
let withUnknown = PendingOp(line: #"{"op_id":"x","created_at":"2026-10-02T09:00:00Z","body":"{\"name\":\"a\\/b \\u00e9\"}","future":[1,2]}"#)!
let reparsed = PendingOp(line: withUnknown.jsonLine()!)!
check(reparsed.body == withUnknown.body, "body survives a rewrite")
check((reparsed.fields["future"] as? [Int]) == [1, 2], "unknown field survives a rewrite")
let roundTrip = PendingOpsQueue.parse(PendingOpsQueue.serialize(ops))
check(roundTrip.map(\.opID) == ops.map(\.opID) && roundTrip.map(\.body) == ops.map(\.body), "queue round trip")

// MARK: Overlay (C2) == overlay_expected_v1.json

let rendered = WidgetOverlay.apply(snapshot, ops: ops)
let renderedList = rendered.household(household1)!.lists.first { $0.id == groceries }!
check(renderedList.openCount == expected["list_open_count"] as! Int, "overlay open_count \(renderedList.openCount)")
check(renderedList.items.map(\.id) == expected["list_item_ids"] as! [String], "overlay item ids \(renderedList.items.map(\.id))")
check(renderedList.items.filter(\.isLocal).map(\.id) == expected["local_item_ids"] as! [String], "overlay local ids")
check(rendered.household(household1)!.chores.map(\.id) == expected["chore_ids"] as! [String], "overlay chore ids")
check(renderedList.items.first { $0.id == "88888888-8888-4888-8888-888888888888" }?.name == "Eggs", "delivered add uses response name")

// A delivered op stops counting once a later snapshot is on disk.
var later = snapshot
later.generatedAt = "2026-10-02T09:10:00Z"
let renderedLater = WidgetOverlay.apply(later, ops: ops)
let laterList = renderedLater.household(household1)!.lists.first { $0.id == groceries }!
check(!laterList.items.contains { $0.id == "88888888-8888-4888-8888-888888888888" }, "delivered add ignored after a newer snapshot")
check(laterList.items.contains { $0.id == "77777777-7777-4777-8777-777777777772" }, "pending add still shown after a newer snapshot")
check(!WidgetOverlay.affectsOverlay(ops[4], snapshotGeneratedAt: nil), "failed op never counts")

// Overlay is idempotent for a delivered add the snapshot already contains.
var containing = snapshot
containing.households[0].lists[0].items.append(WidgetListItem(id: "88888888-8888-4888-8888-888888888888", name: "Eggs"))
containing.households[0].lists[0].openCount = 4
let renderedContaining = WidgetOverlay.apply(containing, ops: [ops[2]])
check(renderedContaining.households[0].lists[0].items.filter { $0.id.hasPrefix("8888") }.count == 1, "no duplicate delivered add")
check(renderedContaining.households[0].lists[0].openCount == 4, "no double count")

// MARK: Pruning

let now = WidgetDate.parse("2026-10-09T09:01:30Z")!  // 7 days after 09:01, 6d23h after 09:02
let pruned = PendingOpsQueue.prune(ops, now: now)
check(pruned.map(\.opID) == Array(ops.dropFirst().map(\.opID)), "ops older than seven days pruned: \(pruned.map(\.opID))")
check(PendingOpsQueue.prune([PendingOp(fields: ["op_id": "bad", "created_at": "nope"])]).isEmpty, "unreadable created_at pruned")

// MARK: Status → state (C3/C4)

check(DeliveryOutcome.forStatus(200) == .delivered && DeliveryOutcome.forStatus(201) == .delivered, "2xx delivered")
check(DeliveryOutcome.forStatus(401) == .authFailed, "401")
for status in [400, 403, 404, 409, 422] { check(DeliveryOutcome.forStatus(status) == .failed, "\(status) failed") }
for status in [nil, 408, 429, 500, 502, 503] as [Int?] {
  check(DeliveryOutcome.forStatus(status) == .retry, "\(String(describing: status)) retried")
}

var op = PendingOp.add(householdID: household1, listID: groceries, name: "Oat \"barista\" / 1l", source: "ios_widget", now: now)
check(op.state == .pending && op.attempts == 0 && op.method == "POST", "new add op")
check(op.path == "/lists/\(groceries)/items", "add path")
check((try? JSONSerialization.jsonObject(with: Data(op.body.utf8)) as? [String: String])?["name"] == "Oat \"barista\" / 1l", "add body is JSON of the name")
let originalBody = op.body
DeliveryOutcome.apply(.retry, to: &op, status: nil, responseBody: nil, error: "offline", now: now)
check(op.state == .pending && op.attempts == 1 && op.lastError == "offline", "retry keeps pending")
DeliveryOutcome.apply(.authFailed, to: &op, status: 401, responseBody: nil, error: nil, now: now)
check(op.state == .pending && op.attempts == 2 && op.lastError == "401", "401 keeps pending")
let response = Data(#"{"id":"srv","name":"Oat"}"#.utf8)
DeliveryOutcome.apply(.delivered, to: &op, status: 201, responseBody: response, error: nil, now: now)
check(op.state == .delivered && op.deliveredDate == now && op.responseItemID == "srv", "delivered keeps response")
check(op.body == originalBody, "body never re-serialised")
var big = PendingOp.completeChore(householdID: household1, choreID: "c", source: "ios_widget", now: now)
DeliveryOutcome.apply(.delivered, to: &big, status: 200, responseBody: Data(count: WidgetConstants.maxStoredResponseBytes + 1), error: nil, now: now)
check(big.response == nil && big.state == .delivered, "large response not stored")
var failed = PendingOp.check(householdID: household1, listID: groceries, itemID: "i", source: "ios_widget", now: now)
DeliveryOutcome.apply(.failed, to: &failed, status: 404, responseBody: nil, error: nil, now: now)
check(failed.state == .failed && failed.lastError == "404", "404 failed")

// MARK: Requests (C4)

let credential = WidgetCredential(
  token: "ml_int_abc", expiresAt: "2099-01-01T00:00:00Z", apiBaseURL: "https://api.mitlist.me/api/v1/",
  userID: "u", deviceID: "d")
let request = WidgetRequests.delivery(for: ops[1], credential: credential)!
check(request.url?.absoluteString == "https://api.mitlist.me/api/v1/lists/\(groceries)/items", "delivery URL \(request.url!)")
check(request.httpMethod == "POST", "delivery method")
check(request.value(forHTTPHeaderField: "Authorization") == "Bearer ml_int_abc", "auth header")
check(request.value(forHTTPHeaderField: "X-Mitlist-Group-ID") == household1, "household header")
check(request.value(forHTTPHeaderField: "Idempotency-Key") == ops[1].opID, "idempotency key")
check(request.value(forHTTPHeaderField: "Content-Type") == "application/json", "content type")
check(request.httpBody == Data(#"{"name":"Butter"}"#.utf8), "exact body bytes")
let check1 = WidgetRequests.delivery(for: ops[0], credential: credential)!
check(check1.httpMethod == "PATCH" && check1.httpBody == Data(#"{"checked":true}"#.utf8), "check request")
check(WidgetRequests.snapshot(credential: credential)?.url?.absoluteString == "https://api.mitlist.me/api/v1/widget/snapshot", "snapshot URL")
let push = WidgetRequests.pushToken("abcd", credential: credential)!
check(push.httpMethod == "PUT" && push.url?.path == "/api/v1/widget/push-token", "push token request")
check(!credential.isExpired(), "credential not expired")
check(WidgetCredential(token: "t", expiresAt: "2020-01-01T00:00:00Z", apiBaseURL: "x", userID: nil, deviceID: nil).isExpired(), "expired credential")
let decodedCredential = try! JSONDecoder().decode(
  WidgetCredential.self,
  from: Data(#"{"token":"ml_int_x","expires_at":"2027-01-01T00:00:00Z","api_base_url":"https://api.mitlist.me/api/v1","user_id":"u","device_id":"d"}"#.utf8))
check(decodedCredential.apiBaseURL == "https://api.mitlist.me/api/v1" && decodedCredential.deviceID == "d", "credential JSON (C4)")

// MARK: Queue file (coordinated read-modify-write)

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mitlist-widget-tests-\(UUID().uuidString)")
let queue = PendingOpsQueue(directory: tmp)
check(queue.readOps().isEmpty, "missing file reads empty")
let fresh = PendingOp.check(householdID: household1, listID: groceries, itemID: "a", source: "ios_widget")
queue.append(fresh)
queue.append(PendingOp.completeChore(householdID: household1, choreID: "c", source: "ios_widget"))
check(queue.readOps().count == 2, "append")
queue.update(opID: fresh.opID) { DeliveryOutcome.apply(.delivered, to: &$0, status: 200, responseBody: nil, error: nil) }
check(queue.readOps().first?.state == .delivered, "update")
check(queue.readLines().count == 2, "readLines")
queue.remove(opIDs: [fresh.opID])
check(queue.readOps().count == 1, "remove")
queue.clear()
check(queue.readOps().isEmpty, "clear")
try? FileManager.default.removeItem(at: tmp)

// MARK: Formatting

check(WidgetFormat.money(1200, currency: "EUR", locale: Locale(identifier: "en_IE")) == "€12.00", "money \(WidgetFormat.money(1200, currency: "EUR", locale: Locale(identifier: "en_IE")))")
let utc = { () -> Calendar in var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
let noon = WidgetDate.parse("2026-10-02T12:00:00Z")!
check(WidgetFormat.isOverdue(flat.chores[1], now: noon, calendar: utc), "overdue chore")
check(!WidgetFormat.isOverdue(flat.chores[0], now: noon, calendar: utc), "due today not overdue")

// Links (C5)
check(WidgetLinks.list(groceries, household: household1, add: true).absoluteString == "mitlist:///lists/\(groceries)?group=\(household1)&add=1", "add link \(WidgetLinks.list(groceries, household: household1, add: true))")
check(WidgetLinks.scanner.absoluteString == "mitlist:///scanner", "scanner link")
check(WidgetLinks.money(household: "h", add: true, amountCents: 2340).absoluteString == "mitlist:///money?group=h&add=1&amount_cents=2340", "money link")

// MARK: Widget kinds for the installedWidgets channel call

check(WidgetKinds.channelKind(WidgetKinds.shoppingList) == "shopping_list", "shopping list kind")
check(WidgetKinds.channelKind(WidgetKinds.chores) == "chores", "chores kind")
check(WidgetKinds.channelKind(WidgetKinds.quickAdd) == "quick_add", "quick add kind")
check(WidgetKinds.channelKind(WidgetKinds.householdToday) == "household", "household kind")
check(WidgetKinds.channelKind(WidgetKinds.balance) == nil && WidgetKinds.channelKind("Other") == nil, "unreported kinds")
check(WidgetLinks.widgetsSetup.absoluteString == "mitlist:///you/widgets", "widgets set-up link")
check(WidgetLinks.list(groceries, household: household1, add: true).path == "/lists/\(groceries)", "quick add path")

// MARK: Credential rotation (401 while the app replaced the credential)

let oldCredential = WidgetCredential(token: "old", expiresAt: "2099-01-01T00:00:00Z", apiBaseURL: "https://x/api/v1", userID: nil, deviceID: nil)
var newCredential = oldCredential
newCredential.token = "new"
check(WidgetAuthRetry.shouldRetry(usedToken: "old", stored: newCredential, alreadyRetried: false), "retry with the replaced credential")
check(!WidgetAuthRetry.shouldRetry(usedToken: "old", stored: newCredential, alreadyRetried: true), "retry only once")
check(!WidgetAuthRetry.shouldRetry(usedToken: "old", stored: oldCredential, alreadyRetried: false), "same credential: no retry")
check(!WidgetAuthRetry.shouldRetry(usedToken: "old", stored: nil, alreadyRetried: false), "deleted credential: no retry")
var expiredNew = newCredential
expiredNew.expiresAt = "2020-01-01T00:00:00Z"
check(!WidgetAuthRetry.shouldRetry(usedToken: "old", stored: expiredNew, alreadyRetried: false), "expired replacement: no retry")
check(WidgetAuthRetry.shouldFlag(usedToken: "old", stored: oldCredential), "flag when the failing token is still stored")
check(!WidgetAuthRetry.shouldFlag(usedToken: "old", stored: newCredential), "no flag after a replacement")
check(!WidgetAuthRetry.shouldFlag(usedToken: "old", stored: nil), "no flag after sign-out")

// MARK: Display overlay: ticked rows stay, struck through

let display = WidgetOverlay.display(snapshot, ops: ops, ticks: [], now: noon)
let displayList = display.household(household1)!.lists.first { $0.id == groceries }!
check(displayList.openCount == renderedList.openCount, "display open_count matches the C2 overlay")
let checkedID = ops[0].itemID!
check(displayList.items.first { $0.id == checkedID }?.checked == true, "pending check stays, ticked")
check(displayList.items.filter { !$0.checked }.map(\.id) == renderedList.items.map(\.id), "unticked rows equal the C2 overlay rows")
let completedChore = ops[3].choreID!
check(display.household(household1)!.chores.first { $0.id == completedChore }?.done == true, "completed chore stays, done")
check(WidgetChores.counts(display.household(household1)!.chores, now: noon, calendar: utc).due
  == WidgetChores.counts(rendered.household(household1)!.chores, now: noon, calendar: utc).due, "done chores not counted")

// A newer snapshot no longer has the ticked item: the tick puts it back,
// ticked, in place, without counting it as open.
let tickedItem = flat.lists[0].items[1]
var afterServer = snapshot
afterServer.generatedAt = "2026-10-02T09:10:00Z"
afterServer.households[0].lists[0].items.remove(at: 1)
afterServer.households[0].lists[0].openCount = 2
let tick = WidgetTick.item(tickedItem, listID: groceries, householdID: household1, index: 1, at: noon)
let shown = WidgetOverlay.display(afterServer, ops: [], ticks: [tick], now: noon.addingTimeInterval(30))
check(shown.households[0].lists[0].items.map(\.id) == flat.lists[0].items.map(\.id), "ticked item back in place")
check(shown.households[0].lists[0].items[1].checked, "ticked item flagged")
check(shown.households[0].lists[0].openCount == 2, "ticked item not counted")
let expired = WidgetOverlay.display(afterServer, ops: [], ticks: [tick], now: noon.addingTimeInterval(WidgetConstants.tickFeedbackDuration + 1))
check(expired.households[0].lists[0].items.count == 2, "expired tick dropped")
let tickedStill = WidgetOverlay.display(snapshot, ops: [], ticks: [tick], now: noon)
check(tickedStill.households[0].lists[0].items.count == 3 && !tickedStill.households[0].lists[0].items[1].checked, "tick never duplicates a row the snapshot has")
let tickRoundTrip = WidgetTick.decode(WidgetTick.encode([tick]))
check(tickRoundTrip == [tick], "ticks round trip")

// A completed chore whose next turn (same id) is in the newer snapshot shows that turn.
let chore0 = flat.chores[0]
let choreTick = WidgetTick.chore(chore0, householdID: household1, index: 0, at: noon)
var nextTurn = snapshot
nextTurn.households[0].chores[0].dueAt = "2026-10-03T09:00:00Z"
let shownNext = WidgetOverlay.display(nextTurn, ops: [], ticks: [choreTick], now: noon)
check(shownNext.households[0].chores.filter { $0.id == chore0.id }.count == 1 && !shownNext.households[0].chores[0].done, "next turn shown, not done")
var choreGone = snapshot
choreGone.households[0].chores.remove(at: 0)
let shownGone = WidgetOverlay.display(choreGone, ops: [], ticks: [choreTick], now: noon)
check(shownGone.households[0].chores.first?.id == chore0.id && shownGone.households[0].chores.first?.done == true, "completed chore back, done")

// Ticks in storage: cleared by a refresh, kept by the fetch after a tap.
let tickDir = FileManager.default.temporaryDirectory.appendingPathComponent("mitlist-widget-ticks-\(UUID().uuidString)")
let tickDefaults = UserDefaults(suiteName: "mitlist-widget-tests-\(UUID().uuidString)")!
let tickStorage = WidgetStorage(directory: tickDir, defaults: tickDefaults)
tickStorage.recordTick(tick, now: noon)
tickStorage.recordTick(tick, now: noon)
check(tickStorage.ticks.count == 1, "same row ticked twice is one tick")
check(tickStorage.nextTickExpiry(now: noon) == noon.addingTimeInterval(WidgetConstants.tickFeedbackDuration), "tick expiry")
check(tickStorage.writeSnapshot(snapshotData, now: noon, keepTicks: true) && tickStorage.ticks.count == 1, "fetch after a tap keeps ticks")
check(tickStorage.writeSnapshot(snapshotData, now: noon) && tickStorage.ticks.isEmpty, "refresh clears ticks")
check(tickStorage.renderedSnapshot(now: noon) != nil, "rendered snapshot reads the file")

// MARK: Refresh threshold

check(!tickStorage.needsRefresh(now: noon.addingTimeInterval(30)), "fresh: no refetch")
check(tickStorage.needsRefresh(now: noon.addingTimeInterval(WidgetConstants.refetchOnReloadAfter + 1)), "a minute old: refetch on reload")
check(tickStorage.needsRefresh(now: noon.addingTimeInterval(-120)), "clock set back: refetch")
tickStorage.refreshRequested = true
check(tickStorage.needsRefresh(now: noon), "requested: refetch")
tickStorage.clearReason = "not_remembered"
tickStorage.deleteAll()
check(tickStorage.clearReason == nil && tickStorage.readSnapshot() == nil, "deleteAll clears reason and snapshot")
try? FileManager.default.removeItem(at: tickDir)

// MARK: Chores: Overdue / Today / Soon, mine first (both platforms)

func chore(_ id: String, _ due: String?, status: String? = nil, mine: Bool = false) -> WidgetChore {
  WidgetChore(id: id, title: id, dueAt: due, dueStatus: status, isMine: mine)
}
let mixed = [
  chore("soon-mine", "2026-10-04T08:00:00Z", status: "due_soon", mine: true),
  chore("today-theirs", "2026-10-02T18:00:00Z", status: "due_today"),
  chore("overdue-theirs", "2026-10-01T08:00:00Z", status: "overdue"),
  chore("today-mine", "2026-10-02T20:00:00Z", status: "due_today", mine: true),
  chore("overdue-mine", "2026-09-30T08:00:00Z", status: "overdue", mine: true),
  chore("no-date-today", nil, status: "due_today"),
]
check(WidgetChores.ordered(mixed, now: noon, calendar: utc).map(\.id) == [
  "overdue-mine", "overdue-theirs", "today-mine", "today-theirs", "no-date-today", "soon-mine",
], "chore order \(WidgetChores.ordered(mixed, now: noon, calendar: utc).map(\.id))")
let counts = WidgetChores.counts(mixed, now: noon, calendar: utc)
check(counts == ChoreCounts(overdue: 2, today: 3, soon: 1) && counts.due == 5, "chore counts")
// Device time zone decides "today": 23:30 UTC on the 2nd is the 3rd in Berlin.
var berlin = Calendar(identifier: .gregorian)
berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
let late = chore("late", "2026-10-02T23:30:00Z", status: "due_today")
check(WidgetChores.urgency(late, now: noon, calendar: berlin) == .soon && WidgetChores.urgency(late, now: noon, calendar: utc) == .today, "local day decides")
var doneChore = mixed[2]
doneChore.done = true
check(WidgetChores.counts([doneChore], now: noon, calendar: utc).due == 0, "done chore not counted")

let en = Locale(identifier: "en")
_ = en
check(WidgetFormat.choreSummary(ChoreCounts()) == "Nothing due", "summary nothing")
check(WidgetFormat.choreSummary(ChoreCounts(overdue: 2, today: 1)) == "2 overdue · 1 due today", "summary \(WidgetFormat.choreSummary(ChoreCounts(overdue: 2, today: 1)))")
check(WidgetFormat.choreSummary(ChoreCounts(soon: 3)) == "3 coming up", "summary soon")
check(WidgetFormat.householdLead(ChoreCounts(overdue: 2, today: 4), openItems: 7) == "2 overdue · 7 to buy", "household lead \(WidgetFormat.householdLead(ChoreCounts(overdue: 2, today: 4), openItems: 7))")
check(WidgetFormat.householdLead(ChoreCounts(today: 1), openItems: 0) == "1 due today", "lead today")
check(WidgetFormat.householdLead(ChoreCounts(soon: 1), openItems: 0) == "All done for today", "lead nothing")

print("\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
