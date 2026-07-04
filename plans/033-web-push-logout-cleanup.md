# Plan 033: Web push unsubscribes on logout so a shared browser doesn't leak notifications

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/services/auth_service.dart frontend/lib/services/push_subscription_service_web.dart frontend/lib/services/push_subscription_service.dart frontend/lib/app.dart`
> On any change, compare live code to the excerpts below first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

On the web build, the push subscription is created once and gated forever by a
`push_subscribed` shared-pref flag, and the logout path never clears that flag or
unsubscribes. On a shared browser: user A subscribes, logs out, user B logs in —
A's push subscription is still active server-side and bound to A's account, so B's
browser keeps receiving A's notifications (a privacy leak), and B never registers
their own subscription because the flag short-circuits `init()`. Clearing the flag
and unsubscribing on logout fixes both.

## Current state

```dart
// frontend/lib/services/push_subscription_service_web.dart:13-24, 69
class PushSubscriptionService {
  static const _subscribedKey = 'push_subscribed';
  ...
  Future<void> init() async {
    if (!kReleaseMode) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_subscribedKey) == true) return;   // ← permanent short-circuit
    ...
    await prefs.setBool(_subscribedKey, true);            // ← set, never cleared
  }
}
```

```dart
// frontend/lib/services/auth_service.dart:392-401  (logout cleanup — no push handling)
Future<void> _clearTokens() async {
  await _tokenStore.clear();
  await _prefs.remove(ApiConfig.userDataKey);
  await _prefs.remove(ApiConfig.persistSessionKey);
  await _prefs.remove(ApiConfig.pendingOAuthRememberMeKey);
  await _prefs.remove('hub_quick_start_dismissed');
  await _prefs.remove('chores_filter_me');
  await _prefs.remove('calendar_view_mode');
  // ← no push_subscribed removal, no unsubscribe
}
```
`PushSubscriptionService().init()` is called once at `frontend/lib/app.dart:56`.
There is a conditional-import indirection: `push_subscription_service.dart` (the
import used by `app.dart`) forwards to `_web` or a stub. The native path
(`FcmService`) already unregisters its token on logout — mirror that for web.

The web class has no `reset()`/`unsubscribe()` method today; you will add one.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Analyze | `cd frontend && dart analyze lib/` | `No issues found!` |
| Test | `cd frontend && flutter test` | pass (sqlite-env note may apply) |

## Scope

**In scope**:
- `frontend/lib/services/push_subscription_service_web.dart`
- `frontend/lib/services/push_subscription_service.dart` (the forwarding entry — add the method to its interface/facade)
- `frontend/lib/services/push_subscription_service_stub.dart` (add a no-op so non-web builds compile)
- `frontend/lib/services/auth_service.dart` (call the unsubscribe on logout)

**Out of scope**:
- `FcmService` — its native unregister is already correct.
- The backend push-subscription endpoints — a DELETE may already exist (see
  Step 2); do not add a new endpoint unless none exists (then STOP and report).

## Git workflow

- Branch: `advisor/033-web-push-logout-cleanup`
- Conventional commit: `fix(push): unsubscribe web push and clear flag on logout`.

## Steps

### Step 1: Add an `unsubscribe()`/`reset()` to the web service

In `push_subscription_service_web.dart`, add a method that:
- gets the current subscription via `reg.pushManager.getSubscription()` and calls
  `.unsubscribe()` on it (guard nulls),
- best-effort DELETEs the server subscription (see Step 2),
- removes the `_subscribedKey` pref so a future `init()` can re-subscribe for the
  next user.
Wrap in try/catch like `init()` does (`debugPrint` on failure) — logout must not
throw.

Add matching signatures to the forwarding `push_subscription_service.dart` facade
and a no-op to `push_subscription_service_stub.dart` so all build targets compile.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 2: Delete the server subscription if an endpoint exists

Check for a delete endpoint (grep backend routes / the frontend for
`push-subscriptions` DELETE, e.g. `DELETE /auth/push-subscriptions`). If one
exists, call it with the subscription endpoint/id. If none exists, skip the
server DELETE (the browser unsubscribe + flag clear still fixes the local leak)
and note it in your report — do NOT invent a backend endpoint here.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 3: Call it from logout

In `auth_service.dart` `_clearTokens()` (or the logout method that calls it),
invoke the push unsubscribe via the forwarding facade and remove the
`push_subscribed` pref. Ordering: unsubscribe before clearing tokens if the
server DELETE needs the access token (Step 2), else after.

**Verify**: `grep -n "push_subscribed\|unsubscribe\|PushSubscriptionService" frontend/lib/services/auth_service.dart`
→ present.

## Test plan

- Web push code uses `dart:js_interop`/`package:web`, which cannot run under
  `flutter test` (VM). A full unit test of `unsubscribe()` is not feasible.
  Verification is: analyze passes, all build targets compile (stub + web facade),
  logout references the unsubscribe, and `flutter test` stays green.
- If the forwarding facade is testable with a fake, add a test asserting logout
  invokes unsubscribe; otherwise state in the report it was not feasible.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `grep -n "getSubscription\|unsubscribe" frontend/lib/services/push_subscription_service_web.dart` → present
- [ ] `grep -n "push_subscribed\|unsubscribe" frontend/lib/services/auth_service.dart` → present (logout clears/unsubscribes)
- [ ] Stub and facade compile (`dart analyze lib/` covers this)
- [ ] `cd frontend && flutter test` passes (only the known welcome-screen case may fail)
- [ ] Report states whether a server-side DELETE endpoint exists and was called
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- There is no server endpoint to remove a subscription AND the leak is considered
  to require server-side revocation — report; a backend endpoint is a separate plan.
- The conditional-import structure differs from the description (drift) — describe
  what you found.

## Maintenance notes

- After this, a second user on a shared browser will re-subscribe on their own
  `init()` because the flag is cleared.
- Reviewer: confirm logout cannot throw if unsubscribe fails, and that the stub
  keeps non-web builds compiling.
