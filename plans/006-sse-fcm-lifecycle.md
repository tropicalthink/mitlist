# Plan 006: Fix SSE/FCM stream lifecycle bugs in the Flutter app

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- frontend/lib/services/sse_service.dart frontend/lib/services/fcm_service.dart`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (touches realtime plumbing; manual verification recommended)
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

Three lifecycle defects in the realtime layer: (1) switching households rapidly can leave two SSE retry loops running concurrently, double-connecting and racing on shared state; (2) malformed SSE events are swallowed by an empty catch, so sync silently stops delivering updates with zero diagnostics; (3) FCM stream listeners are registered on every `init()` and never cancelled, so each logout/login cycle stacks duplicate handlers — duplicate token registrations and duplicate in-app notification banners.

## Current state

**(1) Concurrent loops** — `frontend/lib/services/sse_service.dart:54–61`:

```dart
Future<void> connect(String groupId) async {
  if (_currentGroupId == groupId) return;
  _currentGroupId = groupId;
  _httpClient?.close(force: true);
  _httpClient = null;
  unawaited(_startLoop(groupId));
}
```

`_startLoop` (lines 63+) loops `while (!_disposed && _currentGroupId == groupId)` with backoff. The guard `_currentGroupId == groupId` makes a *stale* loop exit only after its current `await` completes — switching A→B→A leaves the original A-loop alive alongside a new A-loop (both pass the guard), double-connecting.

**(2) Swallowed parse errors** — same file, `_parseAndEmit` (~line 165):

```dart
try {
  final map = jsonDecode(json) as Map<String, dynamic>;
  if (!_controller.isClosed) {
    _controller.add(SseEvent.fromJson(map));
  }
} catch (_) {}
```

The class has a `Logger _log` field already (used elsewhere: `_log.w('SSE disconnected, ...')`).

**(3) Uncancelled FCM listeners** — `frontend/lib/services/fcm_service.dart:80–93` inside `init()`:

```dart
messaging.onTokenRefresh.listen((newToken) { _registerToken(dio, newToken); });
FirebaseMessaging.onMessage.listen((message) { _foregroundController.add(message); });
FirebaseMessaging.onMessageOpenedApp.listen((message) { _tapController.add(message); });
```

The class exposes static members (e.g. `checkInitialMessage()`, `unregisterToken(Dio dio)` — the logout hook). Read the whole file first to confirm whether `init` is static and where `_foregroundController`/`_tapController` live.

Conventions: `Logger` from `package:logger`; `unawaited` from `dart:async`; services here are plain classes wired via Riverpod providers in `frontend/lib/providers/` — check `grep -rn "SseService\|FcmService" frontend/lib/providers/ frontend/lib/` to see who calls `connect`/`init`/`dispose` before changing signatures.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|-------------------------------|---------------------|
| Analyze | `dart analyze lib/`           | exit 0              |
| Tests   | `flutter test`                | all pass            |

## Scope

**In scope**:
- `frontend/lib/services/sse_service.dart`
- `frontend/lib/services/fcm_service.dart`
- The call site that performs logout (only to invoke the new FCM `dispose()` — locate via `grep -rn "unregisterToken" frontend/lib/`)
- New tests under `frontend/test/` if feasible

**Out of scope**:
- The backend SSE handler (`backend/internal/sse/`).
- `TokenRefreshInterceptor` / auth flow.
- Changing the public `Stream` API shapes of either service.

## Git workflow

- Branch: `fix/realtime-lifecycle` off `new-main-fr`.
- Conventional commits (`fix: ...`), one per defect is ideal.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Serialize the SSE loop with a generation counter

In `SseService`, add `int _generation = 0;`. In `connect()`: increment `_generation`, capture `final gen = _generation;`, and pass it into `_startLoop(groupId, gen)`. Change every loop/continue guard from `_currentGroupId == groupId` to `_generation == gen` (keep `!_disposed`). A stale loop — regardless of groupId — now exits at its next check, and A→B→A cannot resurrect an old loop. Apply the same `gen` check after each `await` inside `_startLoop`'s catch branches (the existing `if (_disposed || _currentGroupId != groupId) break;` lines become `if (_disposed || _generation != gen) break;`).

**Verify**: `dart analyze lib/` → exit 0.

### Step 2: Log SSE parse failures

Replace `catch (_) {}` in `_parseAndEmit` with:

```dart
} catch (e) {
  _log.w('SSE: dropping malformed event: $e');
}
```

Do not rethrow and do not reconnect — dropping with a log preserves current behavior plus diagnostics.

**Verify**: `dart analyze lib/` → exit 0.

### Step 3: Make FCM init idempotent and disposable

In `FcmService`:

1. Store the three subscriptions: `StreamSubscription<String>? _tokenSub;` etc. (match static/instance to how `init` is declared).
2. At the top of `init()`, cancel any existing subscriptions before re-listening (idempotent re-init), e.g. `await _tokenSub?.cancel();`.
3. Add a `dispose()` (or `static Future<void> reset()`) that cancels all three subscriptions; call it from the logout path right where `unregisterToken(dio)` is already called.
4. Do NOT close `_foregroundController`/`_tapController` if they are static/long-lived broadcast controllers consumed by UI — cancelling the inbound listens is sufficient. Only close them if the class is instance-scoped and recreated per login (determine from the providers wiring; if ambiguous, leave controllers open and note it).

**Verify**: `dart analyze lib/` → exit 0; `grep -n "cancel()" frontend/lib/services/fcm_service.dart` → ≥ 3 matches.

### Step 4: Tests + manual smoke

Add a unit test for the SSE generation logic if `SseService` can be constructed without a live backend (its `connect` immediately starts network I/O — if untestable without refactor, skip the unit test; a refactor for testability is out of scope). Run the suite. For manual verification, note in your report: run the app, switch between two households quickly ~5 times, confirm via debug logs only one `SSE connected` per switch and no duplicate event deliveries.

**Verify**: `flutter test` → all pass.

## Test plan

Existing suite (`frontend/test/`: design_system_test.dart, frontend_flows_test.dart, widget_test.dart) must stay green. New SSE generation unit test is best-effort per Step 4.

## Done criteria

- [ ] `dart analyze lib/` exits 0
- [ ] `flutter test` exits 0
- [ ] `grep -n "catch (_) {}" frontend/lib/services/sse_service.dart` → no matches
- [ ] `_generation`-style guard present in `sse_service.dart`; FCM subscriptions stored and cancelled
- [ ] Logout path calls the new FCM cleanup
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Either file no longer matches the excerpts (drift).
- `FcmService`'s controllers are consumed in a way that makes cancellation ordering ambiguous (e.g. UI re-subscribes on login expecting fresh controllers) — report the wiring you found instead of guessing.
- Fixing the loop requires changing `SseService`'s public API (providers/screens call it from multiple places).

## Maintenance notes

- The generation-counter pattern must be preserved by anyone adding new `await` points inside `_startLoop` — each one needs a `gen` staleness check after it.
- Reviewer: confirm logout → login → logout → login produces exactly one token registration per login (watch backend device-token logs).
- Deferred: making `SseService` constructor-injectable (HttpClient factory) for unit testing — worth doing if realtime bugs recur.
