# Plan 008: Attach the grocery repository to SSE so graph updates arrive live

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/repositories/grocery_repository.dart frontend/lib/screens/lists/list_detail_controller.dart frontend/lib/providers/grocery_provider.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-fix-grocery-sync-spine.md (there is nothing to receive until the server can emit versions; the wiring itself is independent, but verify 001 first so manual testing is meaningful)
- **Category**: bug
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

`GroceryRepository` has complete SSE plumbing — `attachSse` subscribes to `grocery:graph_updated` events and triggers `pullDelta` — and the backend publishes that exact event after every correction and aisle write (`backend/internal/services/grocery_service.go:178-188`). But `attachSse` has **zero callers**: chores, pinwall, and lists all attach their repositories to the shared SSE stream; grocery never does. So a partner's correction reaches this device only on the next cold-start shell preload (a best-effort pull with a 3-second timeout). One `attachSse` call in the right lifecycle closes the gap.

## Current state

- `frontend/lib/repositories/grocery_repository.dart:41-62` — the unused plumbing:

```dart
  void attachSse(SseService sseService, String groupId) {
    if (_sseService == sseService && _sseGroupId == groupId) return;
    _sseSub?.cancel();
    ...
    _sseSub = sseService.events.listen(_handleSseEvent);
  }

  void detachSse() { ... }

  Future<void> _handleSseEvent(SseEvent event) async {
    if (_sseGroupId == null) return;
    if (event.type == 'grocery:graph_updated') {
      await pullDelta(_sseGroupId!);
    }
  }
```

`grep -rn "attachSse" frontend/lib` shows callers for chore/pinwall/list repositories only.

- The exemplar this plan follows — `frontend/lib/screens/lists/list_detail_controller.dart:174-177` attaches the *list* repository once the list's group is known:

```dart
      // Attach SSE so edits from other household members appear in real time.
      final sseService = ref.read(sseServiceProvider);
      repo.attachSse(sseService, list.groupId);
```

(An alternative exemplar with explicit detach-on-dispose: `frontend/lib/widgets/hub/pinwall_section.dart:58-75`.)

- `frontend/lib/providers/grocery_provider.dart:60-72` — `groceryGraphSyncProvider` is the bounded shell preload; its comment explains why IT must not hold an SSE loop open ("widget tests should not be held open by a persistent SSE loop"). Respect that: do not attach inside this provider.

- Grocery data matters on the lists surface (suggestions, resolution, restock all read the graph), so the list-detail controller — which already manages an SSE attachment lifecycle for the same group — is the right host.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Regression | `cd frontend && flutter test` | all pass (this is the suite that catches held-open streams in widget tests) |

## Scope

**In scope**:
- `frontend/lib/screens/lists/list_detail_controller.dart`
- `frontend/lib/repositories/grocery_repository.dart` (only if a comment/doc tweak is needed)

**Out of scope**:
- `groceryGraphSyncProvider` — stays a bounded preload, per its comment.
- Attaching on the hub/scanner screens — one attachment point is enough for now (the SSE service is shared and `attachSse` self-dedupes); more surfaces can attach later if usage shows gaps.
- Backend SSE emission — already works.

## Git workflow

- Branch: `advisor/008-grocery-sse-attach`
- Commit style: `fix(grocery): attach grocery repository to SSE for live graph invalidation`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Attach in the list-detail controller

In `list_detail_controller.dart`, at the point where the list repo attaches (after `repo.attachSse(sseService, list.groupId);` at ~line 176), add the grocery attachment, storing the repo reference for detach:

```dart
      // Grocery graph shares the same SSE stream: corrections/aisles from
      // other members invalidate the local graph live.
      try {
        final groceryRepo = await ref.read(groceryRepositoryProvider.future);
        if (!_disposed) {
          _groceryRepo = groceryRepo;
          groceryRepo.attachSse(sseService, list.groupId);
        }
      } catch (_) {}
```

Add the field `GroceryRepository? _groceryRepo;` and, in the controller's `dispose()` (find it — the class already disposes `suggestionsRevision` at line ~115), call `_groceryRepo?.detachSse();`. Follow the import style of the file for `grocery_provider.dart` / `grocery_repository.dart`.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Full test sweep

The risk of SSE attachments is widget tests hanging on open streams — the existing suites for list detail exercise this controller.

**Verify**: `cd frontend && flutter test` → all pass, no timeouts

### Step 3 (manual, only if a dev backend is running): end-to-end check

With `backend` running and two clients (or one client + `curl` POST to `/groups/{gid}/grocery/corrections` with a valid token): post a correction, observe the client log line `Grocery graph applied delta maxVersion=N` (`grocery_repository.dart:189`) without restarting the app. If no dev backend is available, skip and note it in the report.

## Test plan

No new unit test — the value is the wiring; the regression risk (hung widget tests) is covered by the full suite in Step 2. If `flutter test` hangs on a list-detail test after Step 1, the detach path is wrong — see STOP conditions.

## Done criteria

- [ ] `grep -rn "attachSse" frontend/lib --include="*.dart" | grep grocery` → exactly one caller (the controller)
- [ ] `grep -n "detachSse" frontend/lib/screens/lists/list_detail_controller.dart` → present in dispose
- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `cd frontend && flutter test` exits 0 with no timeout
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Any widget test times out after the change — report which test; do not "fix" by removing the detach or wrapping in zones.
- `list_detail_controller.dart` no longer has the SSE attach block at ~line 176 (refactored since planning).
- `groceryRepositoryProvider` resolution inside the controller creates a provider-lifecycle error (e.g. `ref` used after dispose) — the `_disposed` guard shown should prevent it; if not, report the stack.

## Maintenance notes

- If a future screen needs live grocery updates without a list open (e.g. the scanner), attach there too — `attachSse` self-dedupes per service+group.
- When Plan 001 + 005 land, this wiring is what makes a partner's correction visible mid-session; until then it's dormant but harmless.
- Reviewer should scrutinize: detach on dispose, and that the attach is inside the existing post-load path (not `build`).
