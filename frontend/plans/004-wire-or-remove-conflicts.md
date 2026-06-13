# Plan 004: Wire conflict detection to the existing conflict UI — or remove the dead code

> **Executor instructions**: This plan begins with an **investigation gate**.
> Do Step 0 first and decide Branch A (wire) vs Branch B (remove) based on what
> you find. Do not start editing until the gate decision is made. Run every
> verification command. Honor STOP conditions. Update `plans/README.md` when
> done (note which branch you took).
>
> **Drift check (run first, from `frontend/`)**:
> `git diff --stat 6c868661..HEAD -- lib/storage/app_database.dart lib/sheets/conflict_resolution_sheet.dart lib/widgets/offline_banner.dart lib/providers/outbox_provider.dart lib/repositories/outbox_drainer.dart`

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED (Branch A depends on backend behavior this repo can't fully verify)
- **Depends on**: `plans/003-outbox-error-classification.md` (the `conflict` disposition is the hook)
- **Category**: direction / tech-debt
- **Planned at**: commit `6c868661`, 2026-06-13

## Why this matters

The app ships a **complete conflict-resolution feature that can never fire**.
The `Conflicts` Drift table, `lib/sheets/conflict_resolution_sheet.dart` (a
field-by-field local-vs-server diff with "Keep mine" / "Use theirs"), the
`OutboxStatus.conflict` state, and the banner copy "N conflicts need
resolution" (`lib/widgets/offline_banner.dart:107-113,140`) all exist — but
**`insertConflict` has zero callers** in `lib/` (verified by grep). Nothing ever
writes a conflict, so `conflictCount()` is always 0 and the entire path is
dead.

This is a fork in the road: either **wire it up** (route the 409 disposition
from plan 003 into a `Conflict` row so the UI activates) or **delete it** (less
code to maintain, honest about what the app does). The right choice depends on
whether the backend actually returns HTTP 409 with the server's current entity
state on these mutations — which this frontend repo cannot fully confirm on its
own. Step 0 resolves that.

## Step 0 — Investigation gate (do this first, change nothing yet)

Determine whether the backend returns **409 Conflict** with a usable
**server-state body** for the mutating endpoints that go through the outbox
(item create/update/delete, expense create/update/delete, recipe, chore,
pinwall). Gather evidence from whatever is available:

- Search the repo for API/error docs or backend code: from the **repo root**
  (one level up from `frontend/`), try
  `git grep -n -i "409\|conflict\|StatusConflict" -- '*.go' '*.py' '*.ts' 'docs/**' 2>/dev/null`
  and look at `frontend/doc/` and any `PRODUCT.md`/`README.md`.
- Inspect the Retrofit service definitions in `frontend/lib/services/*_service.dart`
  and model classes for any conflict/version fields (e.g. an `updatedAt`/
  `version`/`etag` sent on update that the server could reject).
- Check `frontend/lib/services/api_error_mapper.dart` — it maps 409 to "That
  already exists." (a uniqueness message), which hints 409 may currently mean
  "duplicate," not "edit conflict."

**Decision rule:**
- If you find clear evidence the backend returns 409 **with the current server
  representation in the response body** for edit conflicts → **Branch A (wire)**.
- If 409 is only used for uniqueness/duplicate errors, or there's no evidence of
  conflict responses with server state, or you cannot determine it → **Branch B
  (remove the dead code)**. Removing unreachable code is the safe, honest
  default; do not build a feature on an unverified backend contract.

Record the evidence and your choice in the PR description and in the
`plans/README.md` status note.

> **If you cannot access anything outside `frontend/` and find no conflict
> contract evidence inside it, default to Branch B** and note that Branch A is
> blocked pending backend confirmation.

## Commands you will need

| Purpose   | Command (from `frontend/`)                          | Expected |
|-----------|------------------------------------------------------|----------|
| Analyze   | `dart analyze lib/`                                 | `2 issues found.` (pre-existing); no new issues |
| Tests     | `flutter test`                                      | all pass |

---

## Branch A — Wire conflict detection

**In scope**: `lib/repositories/outbox_drainer.dart`,
`lib/storage/app_database.dart` (use existing `insertConflict` — no schema
change), `lib/sheets/conflict_resolution_sheet.dart` (only if the re-enqueue
type mapping needs fixing), `test/repositories/outbox_drainer_test.dart`.

**Current state to build on:**
- `AppDatabase.insertConflict(ConflictsCompanion)` (line 557) and
  `Conflicts` table columns: `id`, `entityType`, `entityId`,
  `localPayloadJson`, `serverPayloadJson`, `createdAt`, `resolvedAt`.
- The conflict sheet's "Keep mine" (`_keepLocal`,
  `conflict_resolution_sheet.dart:55-70`) re-enqueues via
  `db.enqueueOutbox(id: conflict.id, type: conflict.entityType, payload:
  jsonDecode(conflict.localPayloadJson))`. **Therefore `entityType` stored on
  the conflict MUST be a valid outbox op type** (e.g. `updateItem`), and
  `localPayloadJson` MUST be a payload that op type accepts. Store
  `op.type` as `entityType` and the op's own `payloadJson` as
  `localPayloadJson`.
- Plan 003 left a `case OutboxErrorDisposition.conflict:` branch that currently
  dead-letters. This branch replaces it.

**Steps:**
1. Add a method to `AppDatabase` (or inline in the drainer using existing
   `insertConflict`) that records a conflict from a failed op:
   build `ConflictsCompanion.insert(id: <uuid>, entityType: op.type,
   entityId: <derived from payload>, localPayloadJson: op.payloadJson,
   serverPayloadJson: <server body from DioException.response?.data, JSON-encoded;
   '{}' if absent>, createdAt: DateTime.now())`, then **delete the outbox op**
   (`deleteOutboxOp(op.id)`) so it stops retrying. The drainer should
   `continue` after recording (don't block the queue). Deriving `entityId`:
   reuse the same key the op's `_sync*`/handler reads (e.g. `itemId`,
   `expenseId`); if not present, use the temp/entity id in the payload.
2. In the drainer's `conflict` branch, call that recording path instead of
   `markOutboxPermanentFailure`. Add a `Uuid` source (the repos already use
   `package:uuid`); the drainer can take a `Uuid` in its constructor or generate
   inline — match how repositories construct ids.
3. Verify the conflict sheet round-trips: stored `entityType` is a real op type
   so `_keepLocal` re-enqueues a valid op; `_acceptServer` just resolves. If the
   sheet currently can't reconstruct the local row for display, the existing
   field-diff (`_ConflictCard`) already renders arbitrary JSON key/value pairs,
   so any payload shape displays.
4. Test in `test/repositories/outbox_drainer_test.dart`: an op whose handler
   throws `fakeDioException(statusCode: 409)` results in `db.conflictCount() == 1`,
   the outbox op deleted, and the queue continues to the next op.

**Done (Branch A):**
- [ ] A 409 from a handler creates a `Conflicts` row (`conflictCount()` > 0) and removes the outbox op.
- [ ] `OfflineBanner` shows the conflict state (manually or via a widget test) and tapping opens `ConflictResolutionSheet`.
- [ ] Stored `entityType` is a valid outbox op type so "Keep mine" re-enqueues successfully.
- [ ] `dart analyze lib/` clean; `flutter test` passes with the new 409 test.
- [ ] No `schemaVersion` change.

---

## Branch B — Remove the dead conflict code

Delete the unreachable feature so the codebase honestly reflects behavior. With
plan 003 in place, 409s are dead-lettered like other permanent failures (shown
in the banner's failed count), which is acceptable until/unless the backend
grows a real conflict contract.

**In scope**: `lib/sheets/conflict_resolution_sheet.dart` (delete),
`lib/widgets/offline_banner.dart`, `lib/providers/outbox_provider.dart`,
`lib/storage/app_database.dart` (remove now-unused conflict query helpers, keep
the table to avoid a schema migration), `lib/repositories/outbox_drainer.dart`
and `lib/repositories/outbox_error_classifier.dart`.

**Steps:**
1. Remove `OutboxStatus.conflict`, `conflictCount` from `OutboxState`, and the
   `if (conflicts > 0)` branch in `computeState`
   (`outbox_provider.dart:44,50-62,76-83`); drop the `db.conflictCount()` read.
2. In `offline_banner.dart`, remove the `OutboxStatus.conflict` switch arm
   (lines 107-113), the `hasConflicts` usage (the `onTap` that calls
   `ConflictResolutionSheet.show`, lines 140-144 → always `_showDetails`), and
   the `import '../sheets/conflict_resolution_sheet.dart';`.
3. Delete `lib/sheets/conflict_resolution_sheet.dart`.
4. In `outbox_error_classifier.dart`, fold `conflict` into `permanent` (remove
   the enum value and the 409 special-case so 409 → `permanent`), OR keep the
   enum but have the drainer treat `conflict` as `permanent`. Simpler: remove
   the `conflict` value and map 409 → `permanent`. Update the classifier tests.
5. In `app_database.dart`, you may remove `getConflicts`, `conflictCount`,
   `resolveConflict`, `insertConflict` (now unused). **Keep the `Conflicts`
   table declaration** so `schemaVersion` stays 4 (removing a table is a
   migration — out of scope). Confirm nothing else references the removed
   methods (`grep -rn "conflictCount\|getConflicts\|insertConflict\|resolveConflict" lib`).
6. Remove the conflict-count assertions from any tests; ensure
   `outboxStateProvider` no longer reports a conflict status.

**Done (Branch B):**
- [ ] `grep -rn "ConflictResolutionSheet\|OutboxStatus.conflict\|conflictCount" lib` returns no matches (the file is gone, the enum value removed, the helper unused/removed).
- [ ] `lib/sheets/conflict_resolution_sheet.dart` deleted (`git status` shows the deletion).
- [ ] `Conflicts` table still declared; `schemaVersion` still `4`.
- [ ] `dart analyze lib/` → `2 issues found.`, no new issues; `flutter test` passes.

---

## STOP conditions (both branches)

- Plan 003 has not landed (`outbox_error_classifier.dart` missing) — STOP.
- Branch A: you cannot determine a server `serverPayloadJson` source — fall back
  to Branch B and note it; do NOT fabricate server state.
- Either branch requires a `schemaVersion` bump / table drop — STOP and report;
  schema migration is out of scope for this plan.
- Removing conflict code (Branch B) reveals another caller you didn't expect —
  report it.

## Maintenance notes

- If Branch B is taken and the backend later adds a real edit-conflict contract,
  this plan's Branch A is the spec to revive it; the `Conflicts` table was
  intentionally left in place to make that cheap.
- Reviewer should verify the chosen branch is internally consistent: no
  half-wired state where the banner promises conflict resolution that can't
  happen.
