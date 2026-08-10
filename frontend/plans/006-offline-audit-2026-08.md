# 006 — Offline capability audit (2026-08-10)

Audit triggered by three reported symptoms: cold start offline broken, features
dead offline, sync slow/unreliable. All three verified against current
`new-main-fr`. Plans 001–005 and `4e7ccae4` are intact — none of this is a
regression of that work; these are gaps that work never covered.

## Root cause A — the 30s timeout is the whole cold-start story

`ApiConfig.requestTimeout = 30s` (`config/api_config.dart:62`) is applied as
`connectTimeout`/`receiveTimeout`/`sendTimeout` on the main Dio
(`services/api_client.dart:172-181`).

`GroupRepository.loadGroups` (`repositories/group_repository.dart:38-48`) is
documented "cache-first" but is **network-first in practice**: it reads the
cache, then `await _groups.listGroups(...)`, and only returns the cache from the
`catch`. The cached value is never returned early.

`cachedGroupsProvider` (`providers/group_provider.dart:28-34`) wraps it, and
**21 screens/widgets** await it via `_resolveGroupId()`.

Consequence, by scenario:

| Scenario | Behaviour |
|---|---|
| Airplane mode / interface down | Dio fails fast (`connectionError`) → cache returned → fine |
| **Interface up, server unreachable** | **30s hang on every screen before cache is used** |

The second row is the normal case for a self-hosted app: any wifi that isn't
home. The app is not "broken" so much as frozen for 30 seconds, then correct.

### A2 — hysteresis reports "online" on the first probe failure (considered, NOT changed)

`ConnectivityService._record` uses `_failureThreshold = 2`, so the **first**
failed probe still returns `true`, including on a cold start where there is no
established verdict to protect.

Tried undamping the first probe; reverted. The existing rationale — a cold radio
fails a probe as readily as a dead uplink — applies to app launch too, and the
behaviour is deliberate, documented and tested. Once the connect timeout is 5s
rather than 30s (fix A) the cost of a briefly-wrong "online" is small, while a
wrong "offline" suppresses a drain. Left alone on purpose.

## Root cause B — being offline permanently dead-letters good writes

**The most damaging finding, and the likeliest source of "changes vanish".**

`getOutboxBatchByTypes` (`storage/app_database.dart:789-805`) excludes any op
with `attemptCount >= 10`, and `markOutboxAttempt` incremented that counter on
*every* transient failure — including a pure offline connection error.

Every write calls `unawaited(drainOutboxOnce())` directly
(`repositories/list_repository.dart:277, 371, 403, 468, 527, 548, 613, 641, 884,
1157`), bypassing the coordinator's connectivity gate
(`services/outbox_coordinator.dart:76-82`). The per-repo `drainOutboxOnce()` has
no gate of its own.

So: edit offline → each write fires an ungated drain → the head-of-queue op
spends an attempt. The 5s drain backoff caps the rate, so **~50 seconds of
offline editing burns all 10 attempts** and dead-letters a write the server had
never once seen. The user sees a permanent "Failed to save" and must find the
banner's Retry to recover it.

The fix is *not* a connectivity gate — `isOnline()` is damped and can report
online while offline (A2), so a gate would leak anyway. The fix is to stop
counting "never reached the server" as evidence against the op.

## Root cause B2 — server recovery never triggers a drain

`OutboxCoordinator` drains on `ConnectivityService.onStatusChange`
(`services/outbox_coordinator.dart:53-58`), but that stream only ever emitted
from **OS interface** changes (`_onInterfaceChange` was the sole `_controller.add`).

When the server comes back while the interface stays up — the normal
self-hosted case, and every captive-portal/VPN recovery — no event fired, so
nothing drained. The coordinator's 5s/10s retry timers only arm if *the
coordinator's* own drain ran; a repo-level `drainOutboxOnce()` after a write
schedules no retry at all. Queued ops therefore sat until app resume or the
user's next write.

`outboxStateProvider` (`providers/outbox_provider.dart:96`) was already probing
`isOnline()` every 3s for the banner and discarding the answer — the recovery
signal existed, it just wasn't wired to anything.

## Root cause C — post-June features were never given an offline path

20 outbox op types exist. Absent entirely:

| Feature | State | Note |
|---|---|---|
| **Chore creation** | network-only | no `createChore`/`updateChore`/`deleteChore` op; chores can be *completed* offline but not *created* |
| **Settlements** | network-only | shipped `1f747e29`, after the offline pass; no repository, no ops |
| **Calendar** | network-only, **no cache** | `FutureProvider` straight to service |
| **Meal plans** | network-only, **no cache** | same |
| **Templates / billing** | network-only | billing is arguably correct to keep online |

Calendar and meal plans have no Drift table at all, so they don't just fail to
write offline — they render nothing.

## What is NOT broken (verified, do not re-fix)

- **Auth cold start.** `bootstrapSession` (`services/auth_service.dart:357-370`)
  is purely local — token + pref, no network. Offline launch does not log out.
- **Token refresh.** Plan 020's `transportError`/`authRejected` split is intact
  and correctly consumed (`api_client.dart:106-114`). The defensive
  token-comparison in `_onRefreshFailure` (:137-150) also covers the
  refresh-succeeds-then-retry-fails case.
- Conflicts, dead-letter review, banner Retry, head-of-line `recordPurchase`
  split — all still in place.

## Landed (A, B, B2)

1. **Split connect from response timeout.** New `ApiConfig.connectTimeout` (5s)
   applied to every Dio client; `requestTimeout` (30s) stays as the response
   budget. Cold start against an unreachable server now falls back to cache in
   ~5s instead of 30s, across all 21 screens.

   `loadGroups` was **not** restructured to return the cache eagerly. All 13
   create/join flows use `ref.invalidate(cachedGroupsProvider)` to get a *fresh*
   list — `refreshGroups()` exists but is dead code — so an early cache return
   would have silently stopped a newly joined household from appearing. Fixing
   the timeout gets the win without touching those semantics.

2. **`OutboxErrorDisposition.unreachable`.** Transport failures
   (`connectionError`, `connectionTimeout`, `cancel`, and any error with no
   response) are now distinct from `transient`. Both retry; only `transient`
   spends an attempt. `markOutboxAttempt` gained `countsTowardFailure` so an
   unreachable attempt still stamps the backoff without advancing the counter.
   Being offline can no longer dead-letter a write.

3. **Probe verdicts drive `onStatusChange`.** `_record` emits when the verdict
   *flips*, so the 3s banner probe now doubles as the recovery signal and the
   coordinator drains when the server returns with the interface still up.
   Suppressed for the first verdict and for unchanged verdicts, so a steady
   connection doesn't spam drains.

Tests: 3 new (offline never dead-letters; recovery emits; steady state is
quiet), 2 rewritten for the new disposition. Full suite 564 pass / 2 skip.

## Design for the coverage work (C)

Schema **v12 → v13**, adding three cache tables. All follow the existing
`<X>Caches` blob pattern (`CurrentChoresCaches`, `GroupsCaches`).

**Chore creation.** `ChoreRepository.createOfflineFirst(CreateChoreRequest)`
mints `local-<uuid>`, enqueues `createChore`, and splices a synthetic
`CurrentChore` into the cached blob. The drain handler calls
`_remote.createChore`, then reuses the existing
`rewriteOutboxPayloadIds(old→new)` so a complete/skip queued against the local
id retargets the server id in the same pass — the mechanism `_syncCreateItem`
already relies on.

Offline the server can't run rotation, so the synthetic entry carries a null
`pending_assignment`. `chore_creation_sheet` must therefore skip its
`getChoreDetails` assignee lookup when the create was queued rather than sent,
and say so instead of naming an assignee it cannot know.

**Settlements.** Split by semantics, per the reasoning above:
- *Recording* queues like any write (`createSettlement` op) with an optimistic
  local row. That row is **pending**, and pending settlements do not move the
  balance — balance math counts confirmed only (migration 000036). The
  optimistic entry appears in the settlements list and nowhere else.
- *Approval / decline stays online.* Confirming a counterparty's money transfer
  is an assertion about the real world at the time you make it; queuing it
  offline would let it land against a settlement that was cancelled or already
  declined. The UI disables the action offline with a "needs connection" state
  rather than silently deferring it.

Settlements have no cache today (`expenses_controller.dart:311` hits the
service directly), so this needs a `SettlementsCaches` blob for the optimistic
row to live in.

**Calendar + meal plans.** Both are range queries, so a single-row-per-group
cache would thrash. Key on `(groupId, rangeKey)` with `rangeKey` derived from
the from/to pair, and prune to the most recent N rows per group so browsing
months doesn't grow the DB without bound. Read-caching only — neither gets an
outbox path in this pass.

## Landed — feature coverage (C)

Schema **v13** (`settlements_caches`, `calendar_caches`, `meal_plan_caches`),
all three added to `clearAllUserData` so logout still wipes cleanly.

4. **Chore creation** — `createOfflineFirst` (op `createChore`, in the same
   drain pass as complete/skip so `rewriteOutboxPayloadIds` retargets queued
   ops). `refreshCurrentChores` re-splices pending creates.
   `chore_creation_sheet` waits up to 1.5s for the create to land: if it does,
   the assignee confirmation works exactly as before; if not, it stays quiet
   rather than naming a rotation the server has not computed.
5. **Settlements** — `recordSettlementOfflineFirst` + `loadSettlements`
   (cache-backed; the list was previously in-memory only and lost on restart).
   Approval/decline stays online and is now *unreachable* rather than merely
   failing: `needsMyResponse` is false for unsynced rows, `respondToSettlement`
   refuses a `local-` id, and cancel on an unsynced row drops the queued op
   instead of POSTing an id the server has never seen. The row reads "Pending
   sync" so it is not mistaken for one the counterparty can already act on.
6. **Calendar + meal plans** — range-keyed read caches
   (`CalendarRepository`, `MealPlanRepository`), pruned to the 24 most recent
   windows per household. Both cache the **server's raw JSON** rather than
   re-serialised models: `CalendarEvent` has five optional nested payloads and
   no `toJson`, so writing one would have created a second, drifting definition
   of the wire format.

An unfetched window returns null, not empty — "never loaded this month" must
not render as "nothing is scheduled".

Tests: +29 (593 pass / 2 skip). Highest-value ones are the refresh-wipe guards
for chores and settlements, and the queued-complete id retarget.

## Follow-up pass: expense conflicts + true cache-first resolve

### Expenses are no longer last-write-wins

Everything except list items silently clobbered on concurrent edit: two people
edit the same expense, both drain, second wins, no conflict and no trace. Same
family as the offline dead-lettering — data lost while the app reports success —
except here it costs somebody money.

The client **discarded `updated_at` for expenses entirely** (absent from the
model *and* the Drift table), so there was no base to send. Schema **v13 → v14**
adds a nullable `expenses_table.updated_at`, deliberately un-backfilled: a row
with no known server version falls back to last-write-wins rather than
conflicting falsely.

- Backend: `UpdateExpense` gained `expected_updated_at` → 409 with `current`,
  mirroring `list.go` including the second-granularity truncation (Drift stores
  DateTime as unix seconds, so an untruncated compare 409s on *every* edit).
  Omitting the field stays last-write-wins, so other clients are unaffected.
- Client: `updateExpenseOfflineFirst` captures the base, skipping it for a
  chained edit on an already-queued change (that chain is ours — the
  locally-bumped value would self-conflict). The drainer's generic 409 →
  `conflict` disposition already routed it to the `Conflicts` table.
- `conflict_resolution_sheet` was entirely list-item-shaped — title, field
  summary, and both buttons hardcoded `listRepositoryProvider`. Now routed by
  `conflict.entityType`, with per-entity field sets.

### loadGroups is genuinely cache-first

Previously it awaited the network and only fell back on failure, so all 21
screens that resolve their active group waited a full round-trip. Now it returns
the cache immediately and refreshes behind, with `forceRefresh` for the paths
that need certainty. No cache → network is awaited (nothing to be first with).

The create/join sites could not simply keep calling `ref.invalidate`, which
would now hand back the stale list without the new household. New
`refreshCachedGroups(ref, {ensure})`:

- `ensure` writes the household the server just returned straight into the
  cache, so it is present even when the follow-up refetch fails — which is
  exactly when it matters. An earlier draft threw on refresh failure instead;
  that surfaced an error for a household the server had already accepted, which
  is a worse lie than a slightly stale list. The refresh is best-effort and
  never throws.
- Logout sites keep a bare `invalidate` — the list is emptied anyway.

Migration-test note: the grocery migration fixtures build a *partial* older
schema, so they broke on `ALTER TABLE expenses_table`. Fixed by adding the table
to the fixtures — a real v11 database has it, and the fixture was simply not
faithful. Any future migration touching a table absent from those fixtures will
fail the same way.

## Still not offline

- Chore **update/delete** (create was the reported gap).
- Meal-plan and calendar **writes** — read-cached only.
- Attachments (uploads inherently need a network).
- Conflict detection remains list-item-only; everything else is LWW.
