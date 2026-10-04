# Plan 047: Home screen widgets and quick actions (staged)

> **Executor instructions**: This is a staged feature plan. Implement **one
> stage at a time**, in order unless a stage says it is independent. Before
> starting a stage, re-read "Decisions", "Contracts" and that stage's section,
> run the drift check below, and confirm the "Current state" evidence still
> holds. Each stage has its own done criteria and STOP conditions; if a STOP
> condition occurs, stop and report rather than improvising. When a stage is
> done, update the stage table below and this plan's row in `plans/README.md`.
> Stages are sketched at the level needed to resume work; the first task of
> each stage is to expand its section into exact steps against live code.
>
> **Drift check (run first)**:
>
> ```bash
> git diff --stat 3ebe5ae..HEAD -- \
>   frontend/pubspec.yaml \
>   frontend/lib/storage/app_database.dart \
>   frontend/lib/services/token_store.dart \
>   frontend/lib/services/fcm_service.dart \
>   frontend/lib/services/outbox_request.dart \
>   frontend/lib/repositories/outbox_drainer.dart \
>   frontend/lib/repositories/list_repository.dart \
>   frontend/lib/repositories/chore_repository.dart \
>   frontend/lib/router.dart \
>   frontend/lib/main.dart \
>   frontend/ios/Runner/Runner.entitlements \
>   frontend/ios/Runner.xcodeproj/project.pbxproj \
>   frontend/android/app/build.gradle \
>   frontend/android/settings.gradle \
>   frontend/android/app/src/main/AndroidManifest.xml \
>   backend/internal/services/jwt/jwt.go \
>   backend/internal/middleware/idempotency.go \
>   backend/internal/services/push/push.go \
>   backend/cmd/api/main.go
> ```

## Status

- **Priority**: P2
- **Effort**: XL overall (stages are S–L each)
- **Risk**: MEDIUM: new native targets on both platforms, a new auth
  credential type, and a second write path into the server
- **Depends on**: none
- **Category**: feature / platform
- **Planned at**: commit `3ebe5ae`, 2026-10-02
- **Research**: web research on 2026-10-02 (iOS platform, Android platform,
  competitor UX). Sources at the end.

## Revision history

- **v3 (2026-10-02)**: the founder asked for all stages in one pass. Three
  design changes came out of reading the frontend closely:
  1. **The widget snapshot always comes from the server.** The app fetches
     `GET /widget/snapshot` with its session and hands the JSON to native
     code; native code fetches it with the widget credential when the app is
     not running. There is no Drift-built snapshot: Drift only caches the
     households the user has opened, so an app-built snapshot would be
     incomplete for multi-household users, and a stale Drift cache written
     on `paused` would overwrite fresher server state. `source` is therefore
     always `"server"`.
  2. **`home_widget` is not used.** Every bridge job needs native code
     anyway: the credential must live in the Keychain/Keystore, the ops
     queue needs file coordination Dart cannot do, and push refreshes are
     handled natively (no Dart engine boot). A small app-owned method
     channel (C4) replaces the package.
  3. **Queued ops carry a delivery state** (C2) so the app can tell an op
     the widget already delivered (update Drift from the stored response, no
     resend) from one it still has to send (outbox `widgetRequest` op with
     the stored bytes and `Idempotency-Key = op_id`).

  Contracts C1–C2 were extended and C4–C7 added. D2, D3, D4 and D6 below are
  superseded where they say otherwise.
- **v2 (2026-10-02)**: stage 1 implemented. The design changed in three
  places once the backend was read closely:
  1. The widget token is a new `widget` **kind of the existing integration
     credentials** (`ml_int_…`, built for Home Assistant). They were already
     hashed, scoped by household and area, revocable, and accepted by the
     protected API routes. There is no separate token table.
  2. **There is no `/widget/ops` endpoint.** Widgets write through the
     existing list and chore routes. The auth middleware limits widget
     credentials to exactly four routes.
  3. The snapshot JSON uses snake_case, like the rest of the API.

  D4, D5, C1–C3 and stage 1 below reflect this.
- **v1 (2026-10-02)**: initial plan.

| Stage | Title | Effort | Depends on | Status |
|-------|-------|--------|------------|--------|
| 1 | Backend: widget credential, `/widget/snapshot` | M | — | DONE (2026-10-02) |
| 2 | Flutter bridge: snapshot writer, op importer, composer deep link, token provisioning | M | 1 | DONE (2026-10-03) |
| 3 | Android: shopping list + chores widgets (Glance) | L | 2 | DONE (2026-10-03; emulator-verified, no real device yet) |
| 4 | iOS: shopping list + chores widgets (WidgetKit + App Intents) | L | 2 | BUILT (2026-10-03; builds and signs, not yet run on a device) |
| 5 | Freshness: silent "household changed" push to widgets | M | 1, and 3 or 4 | BUILT (2026-10-03; needs the two-device push test) |
| 6 | Quick capture: icon shortcuts, iOS Controls + Siri, Android quick-add + voice | M–L | 2 (Controls/Siri: 4) | BUILT (2026-10-03; Android quick add verified) |
| 7 | Later: household-today widget, balance, shopping-trip Live Activity, WidgetKit push | L | 3–5 | BUILT except AppFunctions (2026-10-03; WidgetKit push needs an APNs key) |

Stages 3 and 4 are independent of each other and can be done in either
order.

**BUILT** means implemented and checked by builds, tests and (where noted)
the emulator, but the stage's own "Done when" still needs a real device or
external setup. See "Implementation record (v3)" below for what was and was
not verified.

## Why this matters

Users want to act on the household without opening the app, as they do with
Google Keep, Apple Reminders, AnyList and OurGroceries. Competitor research
(2026-10-02) found:

- **Ticking off a single shared list from a home screen widget is already
  solved.** AnyList, OurGroceries, Reminders and Keep all do it. For mitlist
  it is table stakes.
- **Nobody does chores, money or a household overview well.**
  - Tody and Flatastic have no widget, and App Store reviewers ask for one.
    Flatastic replied "noted" to a request for "you have 3 tasks due today".
  - Cozi users complain its chores section has no widget.
  - Splitwise has no widget, Control or Siri support.
  - No app combines due chores, the list, tonight's meal and balances.
- **The top complaint everywhere is stale widgets.** Keep is "not quick to
  update"; Todoist says its widget "may take up to 15 minutes" to sync;
  Reminders does not refresh until the app is opened. Second is widgets that
  only open the app (Microsoft To Do cannot complete tasks from a widget).

mitlist's opening: a shopping list widget that stays fresh when a partner
edits, a chores widget that knows the rotation, and "add to list" / "scan"
reachable from every system surface.

## What we are building (product scope)

**Stages 3–6 (v1):**

1. **Shopping list widget**:
   - Tick items off in place.
   - "+" opens that list in the app with the composer focused.
   - Shows who added what ("Sam added oat milk").
   - The user picks the household and list in the system's widget settings.
   - iOS small/medium/large; Android 2x2 to 4x4, resizable.
2. **Chores today widget**:
   - Due and overdue chores, with a "Done" button on each.
   - Shows who is next in the rotation ("Next: Alex, Thu").
   - Empty state invites action ("Nothing due, add a chore").
3. **Quick capture**:
   - Long-press app icon shortcuts on both platforms: Add item, Scan, Log
     expense, Chores today.
   - iOS 18 Controls for Control Center, the Lock Screen and the Action
     Button: "Add to list" and "Scan receipt".
   - Siri/Shortcuts "Add X to my list", where Siri asks for the text.
   - An Android 1x1/4x1 quick-add widget with a mic button, opening a native
     quick-add popup.

**Stage 7 (later):**
- A "Household today" large widget: due chores, the list, tonight's meal and
  "you owe Sam €12".
- A balance widget.
- A shopping-trip Live Activity ending in "Add expense €xx", mirroring the
  in-app trip-to-expense SnackBar.
- iOS 26 WidgetKit push.
- Gemini actions through AppFunctions, once that API leaves preview.

**Platform fact:** neither platform lets a widget take typed text. Text entry
always goes through a deep link into a focused composer, Siri asking for a
string, voice, or the camera.

## Current state (evidence, as of `3ebe5ae`)

Re-verify these before each stage; the design depends on them.

- **No widget code exists.** There is no `home_widget`, `quick_actions`, App
  Intents, WidgetKit or Glance code. iOS has only the Runner target; Android
  has only `MainActivity.kt` and `DeepLinkActivity.kt` in
  `frontend/android/app/src/main/kotlin/me/mitlist/`.
- **The Drift DB lives in the app's private storage.**
  `frontend/lib/storage/app_database.dart:2548-2553` opens `mitlist_db` under
  `getApplicationSupportDirectory`. An iOS extension cannot read it.
- **Login tokens live in the default keychain group.**
  `frontend/lib/services/token_store.dart:34` uses
  `const FlutterSecureStorage()`: no `groupId` and default accessibility.
  Android's flutter_secure_storage 10 uses its own cipher scheme, so Kotlin
  cannot read these tokens easily either.
- **Access tokens are short-lived.**
  `backend/internal/services/jwt/jwt.go:364-370` defaults to 15 minutes.
- **Reusing a refresh token revokes the session.** Refresh tokens rotate with
  replay revocation: `jwt.go:99-121` (`Rotate`, "commit replay revocation")
  and `RotateRefreshToken` at `jwt.go:224`. If a widget process and the app
  refreshed at the same time, one of them would replay and **log the user
  out**.
- **Idempotency keys are scoped per user and tied to the exact request.**
  `backend/internal/middleware/idempotency.go` stores keys per
  `(user_id, idempotency_key)`. The stored request hash covers
  method + URI + body, and reusing a key for a different request returns
  **409** (`idempotency.go:130-133`). The middleware also needs
  `UserIDFromContext` to be set (`idempotency.go:47`).
- **The client sends `Idempotency-Key` from outbox ops** via `outboxOptions`
  (`frontend/lib/services/outbox_request.dart:8-10`).
- **Push today is visible notifications only.**
  `backend/internal/services/push/push.go` builds FCM messages with an
  optional `notification` plus `data`. It has helpers to send to a household
  with or without the actor (`push.go:107`, `BroadcastToGroupExcluding`).
  There is no data-only "refresh" message and no `content-available`/APNs
  background push type.
- **The background push handler does nothing.**
  `frontend/lib/main.dart:16-21`, `_firebaseMessagingBackgroundHandler`, only
  calls `Firebase.initializeApp()`.
- **The iOS app already allows background push.** `Info.plist` has
  `UIBackgroundModes` = `remote-notification`. Keep it at that only; see the
  `ios-testflight-build` memory.
- **iOS build settings:** deployment target 15.0
  (`project.pbxproj`, `Podfile`), bundle id `me.mitlist`.
  `Runner.entitlements` has push, App Attest and associated domains
  (`applinks:app.mitlist.me`), but **no App Group**.
- **Android build settings:** AGP 8.13.2 and Kotlin 2.1.0
  (`frontend/android/settings.gradle:21-22`). Compose is not enabled. The
  namespace/applicationId is `me.mitlist`.
- **Android links:**
  - `DeepLinkActivity` owns the whole `mitlist://` scheme and forwards links
    to `MainActivity`. Do not add a second `mitlist://` filter; see the
    manifest comment.
  - https App Links already claim `/lists`, `/chores`, `/money`, `/scanner`
    and others.
- **The composer-focus flag can't come from a link yet.** The list detail
  route `/lists/:listId` (`frontend/lib/router.dart:455-467`) supports
  `autoFocusComposer`, but only through `extra` (`ListDetailRouteArgs`), which
  a deep link cannot carry.
- **The app's current household is a single global value.**
  `currentGroupIdProvider` (`frontend/lib/router.dart:64`). Widgets must not
  depend on it.
- **Offline-first write methods already exist:**
  `ListRepository.createItemOfflineFirst` (`list_repository.dart:255`),
  `ChoreRepository.completeOfflineFirst` (`chore_repository.dart:262`) and
  `FinanceRepository.createExpenseOfflineFirst`
  (`finance_repository.dart:310`).
- **Toolchain:** Flutter 3.44 / Dart 3.12 locally; `pubspec.yaml` declares
  `sdk: ^3.6.1`.

## Decisions

### D1. Widget UI is native: SwiftUI (WidgetKit) and Kotlin (Jetpack Glance)

Flutter cannot render inside an iOS widget extension. The extension memory
cap is about 30 MB, and Flutter's own docs advise against Flutter UI in
extensions that get less than about 100 MB. Android widgets only render
RemoteViews, which Glance compiles to. Every maintained Flutter widget
solution, including Google's own Flutter home-widget codelab, renders native
UI.

### D2. `home_widget` is a data bridge only

Use `home_widget` (0.10.x) for three things only:
- writing data into App Group storage (iOS) or SharedPreferences (Android);
- `updateWidget` (reload);
- launch/click URIs.

Do **not** use `registerInteractivityCallback`, which runs Dart in the
background:
- It boots a headless Flutter engine per cold tap: roughly 1–3 s, via
  non-expedited WorkManager on Android.
- On iOS it relies on `ForegroundContinuableIntent`, deprecated in iOS 26,
  and it does not run once the app is killed (home_widget issues #345 and
  #318).
- It interferes with other plugins' callbacks (#408).
- A second engine would hold its own `SecureTokenStore` cache and could race
  the main isolate on refresh-token rotation, which logs the user out.

### D3. Widgets never open Drift

The widget reads a small JSON **snapshot** (see Contracts). Reasons:
- **iOS:** keeping SQLite in the shared App Group container gets the app
  killed with `0xdead10cc` when it is suspended while holding a file lock.
  Keep Drift in Application Support.
- **Android:** writes from a second engine do not update the main isolate's
  `watch()` streams.

### D4. Widget writes: change the widget's own display, queue, then deliver with a widget token

A widget tap (an iOS AppIntent in the widget extension, or an Android Glance
`ActionCallback`) does four things:

1. Updates the snapshot so the widget shows the change at once (the
   "optimistic patch"), and reloads the widget.
2. Appends the op to a shared **pending-ops queue** file, storing the exact
   method, path and body it will send.
3. Sends that request to the **existing route** with the widget credential,
   `X-Mitlist-Group-ID: <household>` and `Idempotency-Key: <opId>`. The
   routes:
   - `PATCH /lists/{id}/items/{item_id}` with `{"checked":true}`;
   - `POST /lists/{id}/items`;
   - `POST /chores/{id}/complete`.
4. On a 2xx response, removes the op from the queue.

On launch and resume, the Flutter app imports whatever is left in the queue
into the Drift outbox. It sends the **same method, path and body with the same
key** using its own session. Idempotency keys are scoped per user, not per
credential, so the server replays the first result (`Idempotency-Replayed:
true`) when the widget's request succeeded but its response was lost. The
end-to-end test proves this. Matching bytes matter because the middleware
returns 409 on a body or URI mismatch.

### D5. A scoped widget credential; never the app's login tokens

The widget credential is an integration credential with `kind = 'widget'`:
- an opaque `ml_int_…` token, stored hashed;
- one live credential per device install; it expires after 90 days;
- covers every household the user belonged to when it was issued;
- allowed **only** on the four widget routes (snapshot, add item, update
  item, complete chore). The auth middleware enforces this through
  `widgetCredentialAllowsRoute`.

The app issues and renews it while it is in the foreground (it has the real
session), and re-issues it when the user's set of households changes. It
stops working when:
- the app signs out (`DELETE /auth/widget-credential`);
- the user's auth cutoff moves: password change or reset, account deletion,
  guest conversion;
- it expires.

It is stored natively:
- **iOS:** the Keychain, with the App Group as the access group (no Keychain
  Sharing entitlement needed), accessibility `afterFirstUnlock` so Lock
  Screen and background use work.
- **Android:** a Keystore-backed store written from Kotlin.

This removes the refresh-rotation race entirely and lets widgets and
extensions sync without Flutter running.

### D6. Freshness comes from a server push, not polling

When household data a widget shows changes, the backend sends a data-only
"widgets stale" push to the household's other members:
- **Android:** an FCM data message. A native `FirebaseMessagingService` or
  the Dart background handler fetches `GET /widget/snapshot` with the widget
  token, writes it, and calls `updateAll`.
- **iOS v1:** a silent push (`content-available`, `apns-push-type:
  background`) wakes the app, which does the same. Apple says to send no more
  than 2–3 such pushes an hour, and they are dropped after a force-quit.
- **iOS later (stage 7):** WidgetKit push (iOS 26+, `apns-push-type:
  widgets`) refreshes the widget directly and the extension fetches with the
  widget token. FCM does not support this push type, so Go needs a direct
  APNs (.p8) client.

Periodic refresh is only a backstop:
- Android: `updatePeriodMillis=0` plus an optional 60-minute WorkManager job
  with a network constraint.
- iOS: timeline `.after(1h)`.

### D7. Widgets are bound to a household/list ID

Configuration lives in the system's own widget settings:
- **iOS:** `AppIntentConfiguration` with household and list `AppEntity`s
  read from the snapshot.
- **Android:** a configuration activity with
  `widgetFeatures="reconfigurable|configuration_optional"`.

If the user hasn't configured a widget, it uses `defaults` from the snapshot.
Never follow `currentGroupIdProvider`, or switching household in the app
silently changes every widget.

### D8. Platform API choices

**iOS:**
- Interactive widgets need iOS 17, so the widget extension target's minimum
  is 17.0; the app stays at 15.0.
- Controls need iOS 18 (`#available`).
- Use `supportedModes` (iOS 26), falling back to the older API on earlier
  versions.
- On iOS 27, pin widget intents with
  `allowedExecutionTargets = .widgetKitExtension`.
- AppIntents shared between targets must be `public`, or release builds
  cannot find them.

**Android:**
- Glance **1.2.x** stable. Do not use the 1.3 alphas: they need AGP 9.2+ and
  compileSdk 37.
- Enable Compose in `:app` with the Kotlin compose compiler plugin matching
  Kotlin 2.1.0.
- `SizeMode.Responsive` with about 3 breakpoints.
- Generated previews via `setWidgetPreviews` on Android 15+. It is limited to
  about 2 calls an hour; call it after sign-in.
- Lock-screen widgets (Android 16 QPR2) show with the phone locked: opt the
  balance widget out with `widgetCategory="not_keyguard"` (`xml-36`).

### Is this the most modern Flutter approach? (assessed 2026-10-02)

Yes, for an app with mitlist's constraints. "Flutter widget" in 2026 means
native widget UI with Flutter supplying data. The options compared:

| Option | Verdict |
|---|---|
| `home_widget` bridge + native SwiftUI/Glance UI (this plan) | The standard approach and the one Google's codelab teaches. |
| `home_widget` interactive Dart callbacks for writes | The tutorial path for simple apps. **Rejected** for mitlist (D2): cold-boot latency, iOS 26 deprecations, does not run after the app is killed, token-rotation race. |
| `home_widget_generator` / `home_widget_cli` (Dart DSL → SwiftUI/Glance) | Display-only, no interactive buttons, version 0.4. **Revisit** for the display-only stage 7 widgets (balance). |
| `renderFlutterWidget` (Flutter widget → image) | Not interactive, ignores tinted/clear modes, uses extension memory. **Rejected**. |
| `app_intents` package (Swift App Intents from Dart annotations) | Needs Dart ≥3.10 (we have 3.12 locally, `^3.6.1` in pubspec). Its own architecture opens the app through a URL because intents may run where Flutter is unavailable. **Revisit** for stage 6 Siri/Shortcuts "open" intents only; background writes stay native. |
| Shared Drift DB in the App Group | **Rejected** (D3). |
| Widget calls the API with the app's login tokens | **Rejected** (D5): 15-minute access TTL plus replay revocation. |
| Glance + RemoteCompose (I/O 2026) | Alpha, needs AGP 9.2. **Revisit** when it is stable. |

The cost of this approach: two small native codebases (Swift and Kotlin) for
widget UI and the tap actions. That is inherent to every Flutter app with
real widgets.

## Contracts

These three contracts are the heart of the design. Define each once and
share it through a golden JSON fixture that both the Go and Dart test suites
check.

### C1. Snapshot (schema v1)

Producers:
- the Flutter app (from Drift, after relevant local changes, debounced about
  2 s, and on `paused`);
- the backend `GET /widget/snapshot` (for refreshes while the app is not
  running). Implemented in
  `backend/internal/services/widget_service.go` (`WidgetSnapshot`).

Consumers: SwiftUI and Glance. Written to:
- **iOS:** App Group container, `widget_snapshot.json`.
- **Android:** the app's files directory, with a pointer in home_widget
  SharedPreferences.

```json
{
  "version": 1,
  "generated_at": "2026-10-02T09:00:00Z",
  "source": "server",
  "user_id": "…",
  "defaults": { "household_id": "…", "list_id": "…" },
  "households": [
    {
      "id": "…",
      "name": "Flat 3B",
      "lists": [
        {
          "id": "…", "name": "Groceries", "type": "shopping", "open_count": 7,
          "items": [
            { "id": "…", "name": "Oat milk", "quantity": 2, "unit": "l", "added_by_name": "Sam" }
          ]
        }
      ],
      "chores": [
        {
          "id": "…", "title": "Bins out", "due_at": "…", "due_status": "due_today",
          "is_mine": true, "assignee_name": "Me", "next_assignee_name": "Alex"
        }
      ]
    }
  ]
}
```

**v3 additions (stage 7, optional fields, no version bump):** each
household may also carry

```json
"tonight_meal": { "title": "Lasagne", "slot": "dinner", "recipe_id": "…" },
"balance": {
  "currency": "EUR",
  "net_cents": -1200,
  "settle_with_name": "Sam",
  "settle_cents": 1200
}
```

- `tonight_meal`: today's (server date) dinner meal plan, else the last
  planned slot of today. Omitted when nothing is planned.
- `balance.net_cents`: the user's net position in the household's base
  currency. Positive: others owe the user. Negative: the user owes.
  `settle_with_name`/`settle_cents` (always positive) name the largest
  suggested settlement involving the user; both are omitted when settled.
  `balance` is omitted when the household has no expenses.

Rules:
- `source` is always `"server"` (v3). Readers must still accept `"app"`.
- **Timestamps** (`generated_at`, `due_at`) are RFC 3339 in UTC with whole
  seconds (`2026-10-02T09:00:00Z`). Readers should still accept fractional
  seconds and offsets.
- Size caps:
  - at most 20 households, and 12 lists per household;
  - 30 open items per list, while `open_count` counts all open items;
  - 20 chores per household.
- **Chores** (server side): the server keeps those with `due_status`
  `overdue`, `due_today` or `due_soon`, puts mine first, then sorts by
  `due_at`. The server's "today" is UTC, so widgets decide "today" from
  `due_at` in the device's time zone.
- **Defaults:** `defaults` is the first household and its first `shopping`
  list (otherwise its first list).
- **`"local": true`** marks an item the *native overlay* adds for a queued
  `list_item.add` op that has not been delivered yet (its id is the
  `op_id`). Widgets show it greyed and do not offer a tick for it. The
  server never sends `local`.
- **Optional fields:** `quantity`, `unit`, `added_by_name`, `due_at`,
  `assignee_name` and `next_assignee_name` are omitted when empty.
- **Versioning:**
  - Later stages add `balance` and `tonight_meal` as optional fields without
    bumping the version.
  - Readers ignore unknown fields.
  - Writers bump `version` only for breaking changes.

### C2. Pending ops queue (v3)

The queue is a JSON-lines file, one op per line, oldest first. Writers
rewrite the whole file atomically (write a temp file, then rename) while
holding the lock:
- **iOS:** `<App Group container>/widgets/pending_ops.jsonl`, every
  read-modify-write inside one `NSFileCoordinator` write.
- **Android:** `<filesDir>/widgets/pending_ops.jsonl`, every
  read-modify-write under a process-wide lock plus a `FileChannel` lock on
  `pending_ops.lock` (the quick-add activity, widget callbacks, workers and
  the method channel can all run at once).

```json
{"op_id":"<uuid v4>","created_at":"2026-10-02T09:00:00Z","source":"ios_widget","type":"list_item.check","household_id":"…","list_id":"…","item_id":"…","method":"PATCH","path":"/lists/<list>/items/<item>","body":"{\"checked\":true}","state":"pending","attempts":0}
```

- `method`, `path` (relative to the API base, starting with `/`) and `body`
  are the **exact request**. The widget and the app both send them verbatim
  (see D4); the server's idempotency hash covers method + URI + body bytes.
  Generate `body` once, when the op is created, and never re-serialise it.
- `source`: `ios_widget`, `ios_siri`, `ios_control`, `android_widget`,
  `android_quick_add`.
- Entity fields: `list_id` (list ops), `item_id` (`list_item.check`), `name`
  (`list_item.add`), `chore_id` (`chore.complete`).
- `state`:
  - `pending`: not delivered yet (offline, 5xx, timeout, or 401).
  - `delivered`: a 2xx came back. The writer also sets `delivered_at` and
    `response` (the response body as a string, capped at 16 KB; omitted if
    larger).
  - `failed`: a 400/403/404/409/422 came back. Never retried. `last_error`
    holds the status.
- `attempts` counts delivery tries; `last_error` holds the last failure.
- **Who removes lines:** the app, after importing them (C4
  `ackPendingOps`). Native code also prunes `delivered`/`failed` ops older
  than 7 days and `pending` ops older than 7 days (the server forgets
  idempotency keys after 7 days, so a later replay could duplicate).
- **Overlay:** widgets always render *snapshot + queue*:
  - `list_item.check` (`pending` or `delivered`, see the last rule): hide
    the item, decrement `open_count`.
  - `list_item.add` `pending`: append `{id: op_id, name, local: true}`,
    increment `open_count`. `delivered` with a `response.id` the list lacks:
    append it with the server id (tickable).
  - `chore.complete`: hide the chore.
  - `failed`: no effect.
  - A `delivered` op stops affecting the overlay once a snapshot with
    `generated_at` later than its `delivered_at` has been written: the server
    state already includes it.
- `household_id` goes into `X-Mitlist-Group-ID` on the widget's request.
- Op `type`s in v1, with what each sends:

  | `type` | Request | Body |
  |---|---|---|
  | `list_item.check` | `PATCH /lists/{id}/items/{item_id}` | `{"checked":true}` |
  | `list_item.add` | `POST /lists/{id}/items` | `{"name":…}` |
  | `chore.complete` | `POST /chores/{id}/complete` | `{}` |

  `chore.complete` must send `{}`, not an empty body: `decodeJSON` rejects
  an empty body. `notes` is optional.

### C3. Widget API (as built in stage 1)

- **`POST /auth/widget-credential`** issues the device's widget credential
  and revokes its previous one. It needs session auth; integration
  credentials get 401.
  - Body: `{ "device_id": "<install id, 8–128 chars of [A-Za-z0-9-_.:]>" }`.
  - Response `201`: the credential (`id`, `kind`, `group_ids`, `scopes`,
    `expires_at`, …) plus `token`, which is shown once.
- **`DELETE /auth/widget-credential?device_id=…`** revokes it. It returns
  `204` even when the device had none.
- **`GET /widget/snapshot`** returns C1. It accepts a widget credential
  (limited to its `group_ids`) or a session (all households).
- **Writes** use the existing routes listed in C2, with the widget
  credential plus `X-Mitlist-Group-ID` (required for list and chore routes)
  and `Idempotency-Key: <op_id>`.
- **Error handling for widget writes:**
  - `404`: the item or chore is gone. Drop the op; the widget refreshes.
  - `403`: no longer a member, or a route outside the four. Drop the op.
  - `401`: the credential is dead. Keep the op for the app to deliver, and
    mark the widget "open the app to sync".
  - `409` on a replay mismatch is a bug: log it and drop the op.
- **Not in the list of integrations:** `GET /auth/integration-credentials`
  does not list widget credentials.

### C4. Native storage and the `me.mitlist/widgets` channel (v3)

**iOS** (App Group `group.me.mitlist`, on Runner and the extension):

| What | Where |
|---|---|
| Snapshot | `<container>/widgets/snapshot.json` (atomic write) |
| Ops queue | `<container>/widgets/pending_ops.jsonl` (C2) |
| Flags | `UserDefaults(suiteName: "group.me.mitlist")`: `widget.auth_failed` (Bool), `widget.last_fetch_at` (Double, epoch s), `widget.refresh_requested` (Bool) |
| Credential | Keychain generic password, service `me.mitlist.widget-credential`, account `default`, access group `group.me.mitlist`, accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Value: the credential JSON below. |

**Android** (`me.mitlist`, all in the app process):

| What | Where |
|---|---|
| Snapshot | `<filesDir>/widgets/snapshot.json` (atomic write) |
| Ops queue | `<filesDir>/widgets/pending_ops.jsonl` + `pending_ops.lock` (C2) |
| Flags | SharedPreferences `mitlist_widget_state`: `auth_failed`, `last_fetch_at` (Long, epoch ms), `refresh_requested` |
| Per-widget config | SharedPreferences `mitlist_widget_config`: `<appWidgetId>.household_id`, `<appWidgetId>.list_id` |
| Credential | SharedPreferences `mitlist_widget_credential`: `iv` + `ciphertext` (Base64), AES-256-GCM with key alias `mitlist_widget_credential` in `AndroidKeyStore`. A key that fails to decrypt (restore to a new device) means "no credential". Excluded from backup. |

**Credential JSON** (what Dart hands over, what native stores):

```json
{"token":"ml_int_…","expires_at":"2027-01-01T00:00:00Z","api_base_url":"https://api.mitlist.me/api/v1","user_id":"…","device_id":"…"}
```

`api_base_url` is exactly the app's Dio base URL
(`ApiConfig.baseUrl + ApiConfig.apiPrefix`), so the widget's request URI
equals the app's when it replays an op.

**Channel** `me.mitlist/widgets` (registered by `MainActivity` and
`AppDelegate` on the main engine; Dart → native only):

| Method | Arguments | Result |
|---|---|---|
| `setCredential` | the credential JSON as a map | `null` |
| `clearAll` | — | `null`. Deletes credential, snapshot, queue and flags; widgets show "Sign in to mitlist". |
| `writeSnapshot` | `{"json": String}` | `null`. Writes the snapshot, clears `refresh_requested`, sets `last_fetch_at`, reloads every widget. |
| `readPendingOps` | — | `List<String>`: raw queue lines |
| `ackPendingOps` | `{"op_ids": List<String>}` | `null`. Removes those ops. |
| `consumeAuthFailure` | — | `bool`: whether a widget saw a 401 since the last call; clears the flag. |
| `hasCredential` | — | `bool`: whether a readable, unexpired credential is stored (false after a restore to a new device, where the Keystore/Keychain item cannot be read). |
| `reloadWidgets` | — | `null` |
| `requestRefresh` | — | `null`. Native delivers pending ops and refetches the snapshot with the widget credential, in the background. |
| `startShoppingTrip` | `{"household_name", "items_left", "items_total", "total_cents", "currency"}` | iOS 16.2+: activity id; otherwise `null` |
| `updateShoppingTrip` | `{"items_left", "items_total", "total_cents"}` | `null` |
| `endShoppingTrip` | `{"total_cents", "currency", "add_expense_url"}` | `null` |

Unknown methods return `notImplemented`; Dart treats every failure as a
no-op (widgets are best-effort, never block the app).

**Native delivery** (widgets, Siri, controls, quick add): the request is
`<method> <api_base_url><path>` with headers `Authorization: Bearer <token>`,
`X-Mitlist-Group-ID: <household_id>`, `Idempotency-Key: <op_id>`,
`Content-Type: application/json` and the stored `body` bytes. Status
handling follows C3: 2xx → `delivered`; 401 → stays `pending`, set
`auth_failed`; 400/403/404/409/422 → `failed`; anything else or no network →
`pending`, `attempts + 1`.

**Native refresh**: `GET <api_base_url>/widget/snapshot` with the widget
credential; on 200 write it as `writeSnapshot` does. Triggers: a widget
action (after delivery), the refresh push (C6), the periodic backstop
(Android WorkManager 60 min with a network constraint; iOS timeline
`.after(30 min)`), and `requestRefresh`. iOS widgets fetch inside
`getTimeline` when `refresh_requested` is set or the snapshot is older than
15 minutes. No credential or no snapshot → widgets show "Open mitlist to set
up widgets".

### C5. Links widgets open (v3)

All links use the custom scheme with an empty host, which both platforms
already route to go_router (`DeepLinkActivity` on Android,
`FlutterDeepLinkingEnabled` on iOS). The optional `group` parameter makes
the app switch to that household first.

| Link | Opens |
|---|---|
| `mitlist:///lists/<list_id>?group=<hh>` | the list |
| `mitlist:///lists/<list_id>?group=<hh>&add=1` | the list with the composer focused |
| `mitlist:///lists?group=<hh>` | the lists tab |
| `mitlist:///chores?group=<hh>` | the chores tab |
| `mitlist:///money?group=<hh>` | the money tab |
| `mitlist:///money?group=<hh>&add=1[&amount_cents=<n>]` | the expense sheet (prefilled amount) |
| `mitlist:///scanner` | the scanner |
| `mitlist:///home?group=<hh>` | the household hub |

### C6. Widget refresh push (v3)

Data-only FCM message to every device of every member of the household
who holds a live widget credential (the actor included: their other devices'
widgets need it too):

- `data`: `{"type": "widget_refresh", "group_id": "<hh>"}`. No
  `notification` block.
- Android: `priority: normal`, `collapse_key: widgets:<hh>`.
- APNs: payload `{"aps": {"content-available": 1}}`, headers
  `apns-push-type: background`, `apns-priority: 5`,
  `apns-collapse-id: widgets:<hh>`.
- Sent at most once per household per 60 s per API process (trailing edge,
  so the last change in a burst is included).
- Handled natively: Android `WidgetPushReceiver` (a
  `com.google.android.c2dm.intent.RECEIVE` receiver, as FlutterFire's own
  receiver is) enqueues the refresh worker; iOS `AppDelegate`
  `didReceiveRemoteNotification` sets `widget.refresh_requested` and calls
  `WidgetCenter.reloadAllTimelines()`, then calls `super` so FlutterFire
  still sees the message. The Dart background handler ignores this type.

**WidgetKit push (stage 7, iOS 26+)**: when `APNS_KEY_P8`, `APNS_KEY_ID`,
`APNS_TEAM_ID` are configured, the backend additionally sends a WidgetKit
push (`apns-push-type: widgets`, topic `me.mitlist.push-type.widgets`,
payload `{"aps":{"content-changed":true}}`) to every widget push token
registered by the user's widget extensions. The extension registers its
token with `PUT /widget/push-token` `{"token": "<hex>"}` using the widget
credential; the token is stored on that device's widget credential row.

### C7. Widget catalogue (v3)

| Widget | iOS kind / families | Android receiver / sizes |
|---|---|---|
| Shopping list | `ShoppingListWidget`: small, medium, large, accessoryRectangular, accessoryInline | `me.mitlist.widgets.ShoppingListWidgetReceiver`: 2x2–4x5, resizable |
| Chores today | `ChoresWidget`: small, medium, large, accessoryRectangular, accessoryInline | `me.mitlist.widgets.ChoresWidgetReceiver`: 2x2–4x5 |
| Household today (stage 7) | `HouseholdTodayWidget`: large, extraLarge | `me.mitlist.widgets.HouseholdTodayWidgetReceiver`: 4x4 |
| Balance (stage 7) | `BalanceWidget`: small (amounts `privacySensitive`) | `me.mitlist.widgets.BalanceWidgetReceiver`: 2x1–2x2, `not_keyguard` |
| Quick add (stage 6) | — (Controls instead) | `me.mitlist.widgets.QuickAddWidgetReceiver`: 1x1 and 4x1 |
| Controls (stage 6, iOS 18) | `AddItemControl`, `ScanReceiptControl` | Quick Settings tile `QuickAddTileService` |
| Shopping trip (stage 7) | Live Activity `ShoppingTripAttributes` | — |

Configuration (D7): iOS `AppIntentConfiguration` with `HouseholdEntity` and
`ListEntity` read from the snapshot; Android a configuration activity
writing `mitlist_widget_config`. Unconfigured widgets use
`defaults.household_id`/`defaults.list_id`.

## Stages

### Stage 1: Backend widget credential and snapshot (M): DONE 2026-10-02

**Built:**
- **Migration** `000076_add_widget_credentials`: adds `kind`, `device_id`
  and `expires_at` to `integration_credentials`.
  - A check constraint requires a device id and an expiry on widget rows.
  - A partial unique index allows one live widget credential per
    `(user_id, device_id)`.
- **Repository** (`integration_credential_repo.go`):
  - `ReplaceWidgetCredential` revokes the old credential and inserts the new
    one in one transaction.
  - `RevokeWidgetCredential`.
  - `GetActiveByHash` now also rejects expired credentials, and widget
    credentials created before `users.auth_valid_after`.
  - `ListByUser` hides widget credentials.
  - The insert returns the database's `created_at`, so the cutoff
    comparison uses one clock.
- **Service** (`integration_credential_service.go`):
  - `IssueWidgetCredential`: covers all current households, scopes
    `widget:read lists:write chores:write`, 90-day expiry.
  - `RevokeWidgetCredential`.
  - Device id validation.
  - `CredentialIdentity.Kind`.
- **Middleware** (`middleware/auth.go`):
  - `widgetCredentialAllowsRoute` limits widget credentials to the four
    routes.
  - Adds the `widget` domain to `integrationDomain`.
- **Snapshot:** `WidgetService` (`services/widget_service.go`) builds C1 from
  `GroupService`, `ListService` and `ChoreService`, so membership checks are
  unchanged. `WidgetHandler` serves `GET /widget/snapshot`.
- **Credential routes:** `POST`/`DELETE /auth/widget-credential` on
  `IntegrationCredentialHandler`.
- **Wiring:** the container and `cmd/api/main.go`.
- **AGENTS.md:** the migration table and the endpoint table.

**Verified:**
- `go build ./...`, `go vet ./...` and `gofmt -l` are clean.
- New tests:
  - `middleware/widget_auth_test.go`: the route allowlist, household scoping
    and the domain scope through the real `AuthWithCredentials`.
  - `services/widget_service_test.go`: the snapshot shape, caps, chore
    ordering, credential household filter, issue/revoke and device-id
    validation.
  - `handlers/widget_test.go`, against Postgres 16 with all migrations: the
    full flow.
    - Issue a credential, read the snapshot, tick an item.
    - The same op later sent with the app's session is replayed rather than
      applied twice.
    - The same key with a different body gets 409.
    - Routes outside the four get 403.
    - Re-issuing kills the old token, and so do the auth cutoff, sign-out
      and expiry.
    - Widget credentials are hidden from the integrations list.
- The 000076 down and up migrations were applied by hand on the test
  database.
- With `TEST_DATABASE_URL` set, the full backend suite passes except
  `TestList_SetListReminder`, which is **pre-existing and unrelated**:
  `newListRouter` in `handlers/setup_test.go` never registers
  `PUT /lists/{id}/reminder`, so it 404s. Fix it separately.

**To run the database tests locally:**

```bash
docker run -d --rm --name mitlist-test-pg -e POSTGRES_USER=mitlist \
  -e POSTGRES_PASSWORD=mitlist -e POSTGRES_DB=mitlist_test -p 55432:5432 postgres:16-alpine
TEST_DATABASE_URL="postgres://mitlist:mitlist@localhost:55432/mitlist_test?sslmode=disable" \
  go test ./internal/api/handlers/ -run TestWidget -count=1
```

Without a database, the handler suite prints `SKIP` and reports ok.

**Found while building (not fixed; outside this plan):**
- **The household scope of integration credentials is only checked against
  the header.** The middleware checks `X-Mitlist-Group-ID`/`group_id`
  against the credential's households. But routes addressed by entity id
  (`/lists/{id}/items/{item_id}`, `/chores/{id}/complete`, …) never check
  that the entity belongs to that household.
  - So a Home Assistant credential scoped to household A can modify
    household B's entities, if the owner belongs to both, by sending A's id
    in the header.
  - Widget credentials cover all of the owner's households, so this does not
    widen what a widget can do. It does matter for Home Assistant
    credentials.
  - Fix: have the services, or a shared check, compare the entity's group
    with the credential's.

**Deploy note:** this ships a migration. Since the HA cutover, migrations do
not run on their own in production; apply them with a one-off container
before deploying a tag that uses them.

### Stage 2: Flutter bridge (M)

**Goal:** the app keeps a correct snapshot on disk, imports queued widget ops,
holds a widget token, and opens a focused composer from a link. No widget UI
yet.

**Scope:**
- Add the `home_widget` package (bridge only, per D2).
- A `WidgetSnapshotService` that builds C1 from Drift (reuse the existing
  repositories and queries), debounced, written on relevant local writes and
  on `AppLifecycleState.paused`, then calls `updateWidget` for each widget
  kind.
- A `WidgetOpsImporter`, run on launch and resume, before the sync session
  starts. For each line in the queue:
  1. Apply the local optimistic change to Drift (check item, add item,
     complete chore).
  2. Enqueue an outbox op that sends the stored `method`/`path`/`body`
     verbatim with `Idempotency-Key = op_id` (C2).
  3. Call `noteLocalWrite()`.
  4. Truncate the lines it imported.

  Respect AGENTS.md: never start a drain inside `_db.transaction`. This may
  need a raw-body outbox request kind; check `outbox_request.dart` and the
  drainer. Map temporary ids for `"local": true` items.
- `WidgetCredentialProvisioner`: issue or renew the widget credential
  (`POST /auth/widget-credential`) while signed in and in the foreground.
  - Renew when the credential is older than 7 days, when the set of
    households changes, after sign-in, or when a widget has recorded a 401.
  - Hand the token to native storage over a small method channel.
  - On sign-out, call `DELETE /auth/widget-credential?device_id=…` (best
    effort) and wipe the native copy.
  - `device_id` is a random install id kept in shared preferences.
- A deep link `/lists/:listId?add=1` that sets `autoFocusComposer`. Handle
  it in `router.dart` for both `mitlist://` (via `DeepLinkActivity`) and
  `https://app.mitlist.me/lists/...`, plus the iOS universal link.
- Golden-fixture test: the Dart snapshot serialiser output equals the
  backend fixture's shape.

**Done when:**
- `dart analyze lib/` and `flutter test` pass.
- Unit tests cover the importer (dedupe, temporary-id mapping, no drain
  inside a transaction) and the snapshot builder (caps, `local` flag,
  defaults).
- `adb shell am start -d "https://app.mitlist.me/lists/<id>?add=1"` opens
  the list with the keyboard up.

**STOP if:** the outbox cannot carry a raw verbatim body without changing how
existing ops serialise.

**Built (v3, 2026-10-02)** — the scope above as revised in v3 (no
`home_widget`, no Drift-built snapshot):
- `lib/services/widgets/widget_bridge.dart`: the C4 channel; every call is a
  no-op on web/desktop and swallows native failures.
- `widget_credential_provisioner.dart`: issues/renews per the rules above,
  plus when `hasCredential` is false (restore to a new device). Sign-out
  revokes it from `AuthService.logout`, and `clearLocalSession`'s wipe hook
  calls `clearAll`, so a forced sign-out also blanks the widgets.
- `widget_snapshot_sync.dart`: fetches `/widget/snapshot` with the session
  (bypassing the response cache) and hands the exact body to native code;
  debounced 2 s. Triggers: sign-in, resume, pause, the outbox draining to
  zero, household changes, and live (SSE) list/chore/member/meal/money
  events.
- `repositories/widget_ops_repository.dart`: imports the queue on start
  and on every resume *before* the outbox drains. Pending ops become
  `widgetRequest` outbox ops (outbox id = idempotency key = `op_id`, so a
  repeated import queues once) carrying method/path/body verbatim; the
  cache shows the change at once (`ListRepository.applyExternal*`,
  `ChoreRepository.applyExternalCompletion`). Delivered ops update the cache
  from the stored response without resending. A refused replay (400/403/404/
  409 without `Retry-After`/410/422) is dropped and its optimistic row
  undone. The coordinator drains `widgetRequest` after the other domains;
  the failed-changes sheet labels it like the in-app op.
- `home_widgets_controller.dart` + `providers/home_widgets_provider.dart`
  tie it to the app lifecycle (`app.dart`).
- Links (C5): `utils/app_link_intent.dart` and the router's redirect handle
  `group=` and `/money?add=1[&amount_cents=]`; the list route reads
  `add=1` into `autoFocusComposer`.
- Tests: `test/services/widgets/*`, `test/repositories/widget_ops_repository_test.dart`,
  `test/utils/app_link_intent_test.dart` (golden queue parsing, import,
  dedupe, exact replay bytes and headers, refusal rollback, offline retry,
  provisioning rules, link parsing, shortcut links, snapshot write).

### Stage 3: Android widgets (L)

**Goal:** shopping list and chores widgets on Android that meet Google's
Tier 2 widget quality bar, aiming for Tier 1.

**Scope:**
- **Build setup:** enable Compose and the compose compiler plugin; add
  `androidx.glance:glance-appwidget:1.2.x` and `glance-material3`.
- **Widgets:** `ShoppingListWidget` and `ChoresWidget`, each a
  `GlanceAppWidget` with a `GlanceAppWidgetReceiver` (or home_widget's
  `HomeWidgetGlanceWidgetReceiver`).
- **Lists and taps:**
  - `LazyColumn` with stable `itemId`s.
  - A `CheckBox`/"Done" `ActionCallback` that does D4 steps 1–4 in Kotlin,
    calling the API with OkHttp or HttpURLConnection and the widget token
    from the Keystore.
  - "+" uses `actionStartActivity` with the `?add=1` link. Callbacks cannot
    start activities on Android 12+ because of the trampoline restriction.
- **Configuration:** a configuration activity for household/list (D7).
- **States and previews:**
  - Empty, loading and error states, plus a manual refresh button.
  - Generated previews (API 35+) and a static `previewImage` for older
    versions.
- **Accessibility:** 48dp touch targets and `contentDescription`s.
- **Theming:** `GlanceTheme` with mitlist colours, plus dynamic colour.
- **Corners and fonts:**
  - The system corner radius on the outer container, with square 2px
    outlines inside.
  - System font only: custom fonts are drawn as bitmaps, which breaks screen
    readers and text scaling.
- **After a force-stop:** re-push all widgets on app start. Android 15
  cancels widget PendingIntents on force-stop.

**Done when:**
- Tested on a device or emulator:
  - Ticking an item updates the widget in under 300 ms.
  - The op reaches the server online.
  - In airplane mode it queues, then syncs on the next app open; check that
    no duplicate appears in another member's app.
  - The widget follows its configured household even after switching
    household in the app.
- `flutter build apk` passes; see the flutter-apk-build memory for flags.

**STOP if:** Glance 1.2 needs a higher AGP/compileSdk than the project
allows.

### Stage 4: iOS widgets (L)

**Goal:** the same two widgets on iOS 17+, plus Lock Screen accessory
variants.

**Scope:**
- **Targets and entitlements:**
  - A Widget Extension target (deployment target 17.0) and
    `group.me.mitlist` App Group entitlements on Runner and the extension.
  - Use Xcode, or the Xcode MCP per the xcode-mcp memory, to add the target;
    do not hand-edit `project.pbxproj` blind.
  - Provisioning: the new extension bundle id `me.mitlist.widgets`, and App
    Group capability enabled for both ids.
- **Intents** (`public`, compiled into both targets): `ToggleListItemIntent`
  and `CompleteChoreIntent`, which do D4 steps 1–4 with `URLSession` and the
  widget token. Also `ListEntity`/`HouseholdEntity` for
  `AppIntentConfiguration`.
- **Widgets:**
  - systemSmall: list name, count and "+".
  - systemMedium/Large: items with `Toggle`s and "+" as a `Link` to
    `?add=1`.
  - accessoryRectangular/Inline: "Groceries · 7 left" and "2 chores due".
- **Rendering modes and margins:**
  - `containerBackground(for: .widget)`.
  - Test full-colour, accented (tinted and iOS 26 clear) and vibrant modes;
    use `widgetAccentable()`.
  - 16 pt margins.
- **Token storage:** move the widget token into the shared keychain group
  (stage 2's channel writes it there). The login tokens stay where they are.

**Done when:**
- Tested on a device:
  - A toggle flips instantly and the op reaches the server.
  - It works offline and syncs on the next open.
  - Lock Screen buttons work after unlock.
  - The widget survives a reinstall of the app.
  - Memory stays well under the extension cap (Xcode memory gauge).
- A TestFlight build passes processing (see the ios-testflight-build memory).

**STOP if:** App Group or keychain-group provisioning needs Apple Developer
portal changes the agent cannot make. Hand those steps to the founder.

### Stage 5: Freshness push (M)

**Goal:** a partner's edit appears on my widget within about a minute,
without me opening the app.

**Scope:**
- **Backend sender:** a `WidgetRefresh` push type, data-only, sent with
  `BroadcastToGroupExcluding` (the actor is excluded) when list items or
  chores change.
  - Debounce per household (for example at most one per 60 s).
  - Collapse key `widgets:<groupId>`.
  - Only to devices that have a widget token (proof the device runs widgets).
  - iOS: `apns-push-type: background`, `apns-priority: 5`,
    `content-available: 1`. Android: normal priority.
- **Client handler:** `_firebaseMessagingBackgroundHandler` (`main.dart:16`),
  or a native `FirebaseMessagingService`, recognises the type and calls
  `GET /widget/snapshot` with the widget token, *not* the login tokens (D5).
  It then writes the snapshot and calls `updateWidget`.
- **Testing:** check that a data-only message does not show an empty
  notification on either platform.

**Done when:** in a two-device test, an edit on device A updates device B's
widget while B's app is in the background. Also record the force-quit
behaviour on iOS in this plan.

**Built, backend (v3, 2026-10-02):**
- `sse.Hub.OnPublish`: observers see every event this process publishes
  (not ones relayed from other API instances, so each change is seen once).
- `services/widget_refresh.go` `WidgetRefreshNotifier`: list, chore (not
  subtask), member, meal plan, expense, settlement and group update/delete
  events arm a per-household timer: the push goes 5 s after the first
  change, then at most once per 60 s per household (trailing edge). It
  targets members holding a live widget credential
  (`repositories/widget_device_repo.go`), the actor included.
- `push.SendWidgetRefresh`: the C6 data-only FCM message (no notification
  block; Android normal priority; APNs `background`, priority 5,
  `content-available`). Unregistered tokens are pruned as for
  notifications. `sendFCM` was split so the message builder and the HTTP
  post are separate (`postFCM`).
- Stage 7's WidgetKit push rides on the same notifier (see stage 7).
- Tests: `services/widget_refresh_test.go` (batching, pacing per household,
  relevance filter, only members with widgets, dead WidgetKit tokens
  forgotten), `push/widget_refresh_test.go` (exact silent message),
  `sse/hub_test.go` (observer sees local publishes once),
  `handlers/widget_test.go` (refresh targets against Postgres).
- Not yet done: the two-device test on real phones, and recording iOS
  force-quit behaviour (Apple drops background pushes to a force-quit app;
  the WidgetKit push and the timeline backstop still refresh the widget).

### Stage 6: Quick capture (M–L)

**Scope:**
- **Long-press icon shortcuts:** use `quick_actions` or native
  `shortcuts.xml` plus `UIApplicationShortcutItem`s: Add item, Scan, Log
  expense, Chores today. iOS allows at most 4.
- **iOS 18 Controls:** "Add to list" (`OpenIntent` to `?add=1`) and "Scan
  receipt" (`/scanner`), in both targets. These work in Control Center, on
  the Lock Screen and on the Action Button.
- **Siri/Shortcuts:**
  - `AddItemIntent(itemName: String, list: ListEntity)`. Siri asks for the
    text. It runs in the extension and uses the queue and token path (D4).
  - `App Shortcuts` phrases.
  - `IndexedEntity` for lists in Spotlight.
- **Android quick add:**
  - A 1x1 and 4x1 quick-add widget: "+" and mic.
  - A native Kotlin dialog-themed `QuickAddActivity`: `excludeFromRecents`,
    `taskAffinity=""`, `stateVisible` keyboard, a list chip read from the
    snapshot, and voice via `RecognizerIntent` (add a `<queries>` entry for
    `RecognitionService`). It writes via D4 and does not start Flutter.
- **Optional:** an Android Quick Settings tile, "Add to list".

### Stage 7: Later

- **Household today widget:** iOS large/extra-large, Android 4x4. Due chores,
  the list, tonight's meal and "You owe Sam €12". Can reuse the `/calendar`
  aggregate.
- **Balance widget:** off the Android lock screen by default
  (`not_keyguard`); offer a "hide amounts" option on iOS Lock Screen widgets.
- **Shopping-trip Live Activity:**
  - Items left, running total, and a final "Add expense €xx".
  - `LiveActivityIntent` runs in the **app process**, so make the cold
    background boot safe.
  - Co-shopper updates go through FCM Live Activity push.
- **iOS 26 WidgetKit push** via a direct APNs client in Go.
- **Gemini:** AppFunctions (Android 16+) for "add to my shopping list", once
  out of preview. Do not build the old Google Assistant integration
  (App Actions): Gemini does not call third-party App Actions.

## Implementation record (v3, 2026-10-03)

All stages were built in one pass at the founder's request. Stage 1 is
recorded in its own section, and stages 2 and 5 in theirs.

### Android (stages 3, 5 receiver, 6, 7)

Code: `frontend/android/app/src/main/kotlin/me/mitlist/widgets/`.
- **Versions:** Glance `glance-appwidget` 1.2.0 (needs compileSdk 35+ and
  AGP 8.6+; we have 36 and 8.13.2), the Kotlin compose plugin 2.1.0, and
  WorkManager 2.10.5 (2.11 is built with a newer Kotlin than ours).
  `glance-material3` is not used: Glance's `ColorProvider`s cover the theme.
- **Core:**
  - snapshot and queue models, and the overlay;
  - the queue under a process lock plus a file lock, with atomic rewrite;
  - the AES-GCM Keystore credential;
  - `WidgetApi`, `WidgetSync` and `WidgetSyncWorker` (immediate, expedited
    for taps, plus a 60-minute backstop);
  - the `me.mitlist/widgets` channel in `MainActivity`;
  - `WidgetPushReceiver` (C6). FlutterFire 16 registers its own receiver
    the same way.
- **Widgets:**
  - shopping list, chores, household today, balance (`not_keyguard`);
  - the 1x1/4x1 quick add, with a native `QuickAddActivity` (voice via
    `RecognizerIntent`) and a Quick Settings tile;
  - a configuration activity.
- **Text and backup:** strings in en/de/fr/es/nl. Backup rules exclude the
  credential, the flags and `files/widgets/`.
- **Debug only:** `src/debug/.../WidgetDebugActivity` pins widgets and loads
  snapshots from adb.
- **Tests:** 21 JVM tests against `contracts/widgets`. Run them with
  `./gradlew :app:testDebugUnitTest`.

### iOS (stages 4, 5 receiver, 6, 7)

Code:
- `frontend/ios/MitlistWidgets/`: the widget extension (bundle
  `me.mitlist.widgets`, iOS 17.0);
- `frontend/ios/WidgetShared/`: compiled into both targets;
- `frontend/ios/Runner/WidgetChannel.swift`,
  `ShoppingTripActivityController.swift` and `MitlistAppShortcuts.swift`.

Details:
- **Project:** the target was added with the xcodeproj gem bundled with
  CocoaPods. It is embedded before Flutter's "Thin Binary" phase. The App
  Group `group.me.mitlist` is on both targets, and push is on the extension.
  Xcode registered the bundle id and App Group itself with automatic
  signing, and a signed Release device build succeeded.
- **Widgets:**
  - shopping list and chores (system sizes plus Lock Screen accessories);
  - household today (large and extra large);
  - balance (small, `privacySensitive`);
  - Controls: add to list and scan receipt (iOS 18);
  - Siri `AddItemIntent` with App Shortcuts phrases (per-language
    `AppShortcuts.strings`, since the app targets iOS 15);
  - the shopping-trip Live Activity: the "Add expense" state stays an hour,
    and an unfinished trip ends at once;
  - the WidgetKit push handler (iOS 26), which registers its token with
    `PUT /widget/push-token`.
- **iOS-only flags:** `widget.signed_out`, `widget.pending_push_token`,
  `widget.registered_push_token`.
- **Tests:** 102 Foundation-only logic tests against `contracts/widgets`.
  Run them with `frontend/ios/WidgetShared/Tests/run.sh`.
- **Rendering:** widget views were rendered to images (light and dark, every
  size and state) and checked.
- **Not done:**
  - placing widgets on a simulator or device home screen;
  - Spotlight `IndexedEntity` for lists (optional).
- **Side effect:** building bumped GoogleUtilities 8.1.3 → 8.1.4 in both
  `Package.resolved` files.

### Flutter (stages 6, 7)

- **App icon shortcuts:** `quick_actions`, in `services/widgets/app_shortcuts.dart`:
  - "Add item" (the snapshot's default list with `add=1`);
  - Scan;
  - "Log expense" (`/money?add=1`);
  - "Chores today".

  Titles are in all five languages.
- **Live Activity:** the shopping-trip screen drives it through the channel.
  It starts when a trip with items opens, updates on every basket change,
  and ends on "Done" with a link that opens the prefilled expense sheet.
- **Opening from a widget:** opened from outside the app, the list composer
  re-requests the keyboard once the window is focused
  (`ListDetailScreen._focusComposer`). Android otherwise drops the request on
  a cold start.

### End-to-end check (2026-10-03)

Setup: Android emulator (API 36), the real debug app, and a local API on
Postgres with a two-person household. Checked:
- **Sign-in:** issues the credential (scopes and 90-day expiry correct) and
  writes the server snapshot natively. The widget shows the real list.
- **Ticks and replay:**
  - A widget tick reaches the server under the op id. On opening the app,
    the delivered op is imported without being resent.
  - An offline tick, with the app then opened offline, is imported into the
    outbox and sent once when the network returns.
  - An offline tick, with the network back and the app closed, is delivered
    by the native worker in about 3 s.
  - **Lost response:** forcing a delivered op back to `pending` makes the app
    replay the identical bytes, and the server answers from its idempotency
    record (200, one record, no duplicate).
- **Other actions:**
  - Quick add (native dialog) adds the item; the app shows it once.
  - Chore "Done" completes today's turn; the widget then shows tomorrow's.
  - "+" opens the list with the keyboard up, warm and cold.
  - A partner's edit reaches the widget within seconds while the app is open
    (SSE → snapshot).
- **Sign-out:**
  - Log out revokes the credential on the server, and the widgets show
    "Sign in".
  - A session not set to be remembered gets no widget credential, and a
    signed-out start clears the widgets.

### Not verified yet

These are the steps that still need a person or external setup:
1. **Real devices.** Neither platform's widgets have run on a phone.
   - iOS: placing widgets, a Lock Screen toggle, the Controls, Siri, and the
     Live Activity on a device.
   - Then a TestFlight build.
2. **Stage 5 two-device test.** The refresh push needs FCM, which the local
   setup does not have. Test on staging with two phones, and record the iOS
   force-quit behaviour here.
3. **WidgetKit push.** Needs an APNs auth key: `APNS_KEY_P8`, `APNS_KEY_ID`
   and `APNS_TEAM_ID` on the API stacks. Until then, widgets refresh through
   FCM and their timelines.
4. **Android generated previews** (API 35+) were not observed. The static
   previews show.
5. **Gemini AppFunctions** are skipped: the library is still
   `1.0.0-alpha12`. Revisit when it is stable.
6. **Self-hosted servers on plain `http://`** do not work for native widget
   requests in release Android builds (cleartext policy). HTTPS works, and
   debug builds allow 10.0.2.2 and localhost.
7. **Deploy:** migrations 000076 and 000077 must be applied by hand in
   production (see the stage 1 deploy note).

## Design rules for every widget

- **One job per widget and a different layout per size**, not the same
  layout stretched. Make widget surfaces glanceable, not mini-apps.
- **Tappable everywhere:**
  - Every row deep-links to the exact entity.
  - Touch targets are at least 44 pt (iOS) and 48 dp (Android).
  - Every control has an accessibility label.
- **Colour:** brand orange is an accent only; tinted and clear modes wash it
  out, so status must never rely on colour alone.
- **States:** ship an empty state with a call to action, a placeholder
  preview, and an "updated X ago" line when data may be stale.
- **Free:** no premium gate on basic widgets. Competitors that paywall them
  (Cozi on iOS) draw complaints.
- **Privacy on locked screens:** the Android 16 lock screen and the iOS Lock
  Screen and StandBy show data with the phone locked. Default to counts, not
  names or amounts.

## Open questions for the founder

1. Widget token lifetime and renewal: 90-day expiry renewed weekly while the
   app is used? Revoke on logout from all devices: yes (assumed).
2. Should ticking an item from the widget also log the purchase signal the
   in-app check-off records (grocery prior, plan 046)? The default assumption
   is yes, because it goes through the same service.
3. Chores widget: show only my chores, or all household chores with mine
   first? The proposed default is mine first, then others'.
4. Is extra-large or iOS 27 work in scope for v1? Proposed: no (stage 7).

## Sources (researched 2026-10-02)

Some of these post-date the planning model's training (WWDC 2026 / iOS 27,
Google I/O 2026, Glance 1.2 stable, home_widget 0.10). Re-check version
numbers when a stage starts.

- **Apple, widget interactivity and processes:**
  [adding interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities),
  [keeping widgets up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date),
  [WidgetKit push](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications),
  [controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system),
  [`supportedModes`](https://developer.apple.com/documentation/appintents/appintent/supportedmodes),
  [`IntentExecutionTargets`](https://developer.apple.com/documentation/appintents/intentexecutiontargets),
  [HIG widgets](https://developer.apple.com/design/human-interface-guidelines/widgets),
  [background pushes](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app),
  [sharing keychain items](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps)
- **Shared-container SQLite crash:**
  [M. Tsai 2025](https://mjtsai.com/blog/2025/05/15/sqlite-databases-in-app-group-containers-dont/)
- **Android:**
  [Glance releases](https://developer.android.com/jetpack/androidx/releases/glance),
  [Glance interaction](https://developer.android.com/develop/ui/compose/glance/user-interaction),
  [generated previews](https://developer.android.com/develop/ui/compose/glance/generated-previews),
  [widget quality tiers](https://developer.android.com/docs/quality-guidelines/widget-quality),
  [lock-screen widgets FAQ](https://android-developers.googleblog.com/2025/03/widgets-on-lock-screen-faq.html),
  [Quick Settings tiles](https://developer.android.com/develop/ui/views/quicksettings-tiles),
  [AppFunctions](https://developer.android.com/ai/appfunctions),
  [FCM priority](https://firebase.google.com/docs/cloud-messaging/android-message-priority)
- **Flutter:**
  [home_widget](https://pub.dev/packages/home_widget),
  [home_widget interactive widgets](https://docs.page/ABausG/home_widget/features/interactive-widgets),
  [Flutter app extensions](https://docs.flutter.dev/platform-integration/ios/app-extensions),
  [app_intents](https://pub.dev/packages/app_intents),
  [quick_actions](https://pub.dev/packages/quick_actions)
- **Competitors:**
  [Keep widgets](https://support.google.com/keep/answer/13302793),
  [Keep widget redesign](https://www.androidpolice.com/google-keep-new-widgets/),
  [Todoist Android widgets](https://www.todoist.com/help/articles/use-a-todoist-widget-on-your-android-device-632pZA),
  [Todoist iOS Controls](https://www.todoist.com/help/articles/use-todoist-controls-on-ios-XZDxdz9y4),
  [AnyList widgets](https://help.anylist.com/articles/anylist-widgets/),
  [OurGroceries user guide](https://ourgroceries.com/user-guide),
  [Microsoft To Do widgets](https://support.microsoft.com/en-us/todo/ios-widgets-and-microsoft-to-do),
  [Cozi iOS widget](https://www.cozi.com/blog/cozi-ios-widget)
