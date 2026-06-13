# Plan 020: Invite a flatmate with a shareable link

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 40f73b32..HEAD -- frontend/lib/router.dart frontend/lib/sheets/invite_household_sheet.dart frontend/lib/sheets/join_household_sheet.dart frontend/android/app/src/main/AndroidManifest.xml frontend/ios/Runner/Info.plist`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (touches auth redirect logic and platform manifests)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `40f73b32`, 2026-06-12

## Why this matters

The "second member" moment — turning a personal install into a *household* —
currently requires being in the same room (QR scan) or dictating a code over
the phone. The invite sheet offers only "Copy code" and a QR that encodes the
bare code string (so even scanning it with a phone camera shows text, not
something that opens the app). This plan adds a shareable deep link
(`mitlist://join/<code>`) that survives the full journey: shared via any
messenger → opens the app → lands on a join screen → joins — including when
the recipient isn't signed in yet (the link survives auth via the router's
existing `continue=` mechanism, and guest accounts mean zero registration
friction).

**Scope honesty**: custom-scheme links are not auto-linkified in every
messenger, and they do nothing for someone without the app installed. The
share text is therefore written so the code works standalone (copy-paste into
"Join household"), and HTTPS universal/app links are explicitly deferred —
they require hosted association files and belong with release engineering.

## Current state

- **The `mitlist://` scheme is already registered on both platforms** (used
  by OAuth):
  - `frontend/android/app/src/main/AndroidManifest.xml:31-38`:

    ```xml
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="mitlist"
            android:pathPrefix="/auth/callback" />
    </intent-filter>
    ```

    Note: with no `android:host`, the `pathPrefix` is technically ignored by
    Android's matcher, but do NOT rely on that — add an explicit entry for
    join (Step 1).
  - `frontend/ios/Runner/Info.plist:46-56`: `CFBundleURLTypes` registers the
    whole `mitlist` scheme (name `mitlist.oauth`) — scheme-wide, so
    `mitlist://join/...` already reaches the app on iOS; no plist change
    needed unless you rename the URL type (don't).
- `frontend/lib/router.dart` — the redirect block (lines 88–134) is the
  critical integration point:

  ```dart
  // router.dart:91-110 (abridged)
  redirect: (context, state) {
    final location = state.uri.path;
    final isAuthRoute = _authRoutePrefixes.any((p) => location.startsWith(p));
    if (authBootstrap.isLoading) {
      ...
      final target =
          '${state.uri.path}${state.uri.hasQuery ? '?${state.uri.query}' : ''}';
      return '$_sessionBootstrapPath?continue=${Uri.encodeComponent(target)}';
    }
    if (_isSessionBootstrapPath(location)) {
      if (authState) {
        final cont = state.uri.queryParameters['continue'];
        ... // returns decoded continue target
  ```

  Key facts: while auth bootstraps, any deep-link location round-trips
  through `?continue=` and is restored after auth resolves — a
  `/join/<code>` link arriving during cold start is already preserved.
  But when bootstrap finishes **unauthenticated**, line ~126
  (`if (!authState && !isAuthRoute) return '/welcome';`) drops the location.
  `_authRoutePrefixes` is defined around line 73 (`'/welcome'`,
  `'/auth/callback'`, …).
- `frontend/lib/sheets/invite_household_sheet.dart` — generates an invite via
  `svc.inviteMember(widget.groupId, const InviteMemberRequest(role: 'member'))`
  (lines 82–86) into `_invite` (`GroupInvite`, has `.code`). UI: animated
  code segments, a `QrImageView(data: code.trim(), ...)` (line 218-219), and
  a two-button row "Copy code" / "New code" (lines 261–292).
- `frontend/lib/sheets/join_household_sheet.dart` — code-entry join flow:
  phases `entry/joining/success`, joins via
  `svc.joinGroup(JoinGroupRequest(code: _codeController.text.trim().toUpperCase()))`
  (lines 109–110), minimum code length 4 (line 55), shows the joined group
  on success (line 213+).
- `share_plus: ^10.1.4` is already a dependency (`pubspec.yaml:57`) — no new
  packages.
- Conventions: `AppButton`, `AppIcon` (never `Icons.*`), `MitlistSpacing`
  tokens, sentence-case labels, `showAppBottomSheet` for sheets, reduced
  motion per `widgets/odometer.dart:29-30`, friendly errors via
  `utils/friendly_error.dart` (`friendlyErrorMessage(e)`).

## Commands you will need

| Purpose   | Command                              | Expected on success |
|-----------|--------------------------------------|---------------------|
| Analyze   | `cd frontend && dart analyze lib/`   | exit 0 (2 pre-existing info-level `dart:html` deprecations OK) |
| Tests     | `cd frontend && flutter test`        | all pass (baseline 145 pass / 1 known pre-existing failure in `frontend_flows_test.dart` — if plan 019 already landed, baseline is fully green; do not break it either way) |
| Deps      | `cd frontend && flutter pub get`     | exit 0 |

## Scope

**In scope** (the only files you should modify or create):
- `frontend/lib/router.dart` (add `/join/:code` route + redirect handling)
- `frontend/lib/screens/auth/join_landing_screen.dart` (create)
- `frontend/lib/sheets/invite_household_sheet.dart` (share-link button + QR
  payload)
- `frontend/lib/utils/invite_link.dart` (create — pure link build/parse)
- `frontend/android/app/src/main/AndroidManifest.xml` (one intent-filter
  data entry)
- `frontend/test/utils/invite_link_test.dart` (create)
- `frontend/test/join_landing_screen_test.dart` (create)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch, even though they look related):
- HTTPS universal/app links, `assetlinks.json`, `apple-app-site-association`,
  and anything in `landing/` — deferred to release engineering.
- `frontend/ios/Runner/Info.plist` — the scheme registration already covers
  join; leave it alone.
- `frontend/lib/sheets/join_household_sheet.dart` — the manual code-entry
  flow stays as-is (it's the fallback when links aren't tappable).
- Backend invite/join endpoints — `joinGroup(code)` already does everything.
- The OAuth callback flow and its intent-filter entry.

## Git workflow

- Branch: `feat/invite-link` off `new-main-fr`.
- Conventional commits (e.g. `feat: shareable household invite links`).
  Commit per step or logical unit. Do NOT push or open a PR.

## Steps

### Step 1: Pure link helpers + Android intent filter

1. Create `frontend/lib/utils/invite_link.dart`:
   - `String buildInviteLink(String code)` → `'mitlist://join/<CODE>'`
     (trimmed, uppercased).
   - `String? parseInviteCode(Uri uri)` → the code when
     `uri.scheme == 'mitlist' && uri.host == 'join'` and the first path
     segment is a plausible code (≥ 4 chars, alphanumeric plus `-`);
     null otherwise. (With `mitlist://join/ABCD-1234`, Dart's `Uri` puts
     `join` in `.host` and the code in `.pathSegments` — write the tests in
     Step 4 against exactly this.)
   - `String inviteShareText(String code)` → exactly:
     `'Join my household on mitlist!\nTap: mitlist://join/<CODE>\nOr open mitlist and enter the code: <CODE>'`
     (the code must appear standalone so it works where the link isn't
     tappable).
2. In `AndroidManifest.xml`, inside the existing VIEW/BROWSABLE
   intent-filter (lines 31–38), add a second data element after the
   existing one:

   ```xml
   <data
       android:scheme="mitlist"
       android:host="join" />
   ```

   Touch nothing else in the manifest.

**Verify**: `cd frontend && dart analyze lib/` → exit 0;
`grep -n 'android:host="join"' frontend/android/app/src/main/AndroidManifest.xml` → 1 match.

### Step 2: Join landing screen + route + redirect handling

1. Create `frontend/lib/screens/auth/join_landing_screen.dart` —
   `JoinLandingScreen({required String code})`, a small full screen (not a
   sheet — it's a cold-start entry point):
   - Shows the code in the segmented mono style (visual reference:
     `invite_household_sheet.dart:157-196`; a simpler static rendering is
     fine — no animation needed) under a headline `'Join this household?'`.
   - Primary `AppButton` `'Join household'` → calls
     `svc.joinGroup(JoinGroupRequest(code: code.trim().toUpperCase()))` via
     `groupServiceProviderAsync` (mirror `join_household_sheet.dart:103-116`
     including its error handling with `friendlyErrorMessage`); on success
     shows the joined group name and a `'Go to household'` button →
     `context.goNamed('home')`. Set the joined group as current the same way
     `join_household_sheet.dart` does post-join (read its success phase,
     lines 213+, and mirror whatever provider/state update it performs —
     copy the mechanism, don't invent one).
   - Secondary outline button `'Not now'` → `context.goNamed('home')`.
   - Invalid/expired code error → `AppAlert` with the friendly message and
     the manual-entry hint `'You can also enter a code from the household
     switcher.'`
2. In `router.dart`:
   - Register `GoRoute(path: '/join/:code', name: 'joinLanding',
     parentNavigatorKey: _rootNavigatorKey, builder: ... JoinLandingScreen(
     code: state.pathParameters['code']!))` as a top-level route (sibling of
     `/welcome`, not inside the shell).
   - Redirect handling: when bootstrap has finished and the user is
     **unauthenticated** with `location.startsWith('/join/')`, redirect to
     `'/welcome?invite=<code>'` instead of bare `/welcome`. When
     **authenticated** and on `/join/...`, fall through (return null) so the
     landing screen shows. The auth-loading case needs no work — the
     existing `continue=` round-trip already preserves `/join/<code>`.
   - In `WelcomeScreen` — wait: `welcome_screen.dart` is NOT in scope. Do
     not modify it. Instead, handle the post-auth hop in the redirect: when
     the user becomes authenticated while `state.uri.queryParameters['invite']`
     is present on an auth route, redirect to `'/join/<that code>'`. (The
     existing rule `if (authState && isAuthRoute) return '/home';` is the
     line to extend — invite param wins over `/home`.) Validate the param
     with `parseInviteCode`-style checks (≥ 4 chars alphanumeric/`-`) before
     building the location; otherwise ignore it.
3. The welcome screen keeps working untouched: an invited user lands on
   `/welcome?invite=CODE`, signs in or taps "Continue as guest" as normal,
   and the redirect rule from 2 sends them to `/join/CODE` afterward
   (the query param persists across the auth flow because go_router
   preserves the location while `isAuthRoute` returns null — verify this
   assumption in the widget test; if the param is lost during OAuth's
   external round-trip, that's acceptable v1: guest and password flows are
   the primary path. Document what you observe in NOTES).

**Verify**: `dart analyze lib/` → exit 0; `flutter test` → no regressions.

### Step 3: Share button + QR payload in the invite sheet

In `invite_household_sheet.dart`:

1. Change the QR payload (line 219) from `code.trim()` to
   `buildInviteLink(code)` — a camera scan now opens the app instead of
   showing raw text. Update the caption (line 251) to
   `'Scan with a phone camera to join, or share the code below.'`
2. Add a third action: a full-width `AppButton` `'Share invite link'`
   (primary, `AppIcon(name: 'share', ...)` — if the icon vocabulary lacks
   `share`, check `widgets/app_icon.dart` for the closest existing name and
   use it; do not add raw `Icons.*`) below the existing two-button row,
   `MitlistSpacing.sm` above it, calling
   `Share.share(inviteShareText(code))` from `package:share_plus`.
   Disabled while `code.isEmpty`.

**Verify**: `dart analyze lib/` → exit 0.

### Step 4: Tests

See Test plan.

**Verify**: `cd frontend && flutter test` → all pass, ≥ 10 new tests.

## Test plan

- `frontend/test/utils/invite_link_test.dart` (pure):
  - `buildInviteLink('ab-12')` → `'mitlist://join/AB-12'`,
  - `parseInviteCode(Uri.parse('mitlist://join/ABCD-1234'))` → `'ABCD-1234'`,
  - rejects: wrong scheme (`https://join/X`), wrong host
    (`mitlist://auth/callback`), too-short code, empty path,
  - `inviteShareText` contains the bare code at least twice (link + standalone).
- `frontend/test/join_landing_screen_test.dart` (widget — reuse the minimal
  GoRouter pattern from `frontend/test/tonight_card_test.dart` if plan 019
  landed; otherwise build one: routes for `joinLanding` and a `'HOME'`
  marker route named `home`). Override `groupServiceProviderAsync` with a
  fake (extend `frontend/test/support/fakes.dart`'s `FakeGroupService` with
  a `joinGroup` recording stub if it lacks one):
  - renders the code and `'Join this household?'`,
  - tapping `'Join household'` calls `joinGroup` with the uppercased code
    and shows the success state,
  - failure (fake throws) shows an `AppAlert` and no success state,
  - `'Not now'` lands on the `'HOME'` marker.
- Router redirect coverage (same widget test file): pump the real
  `routerProvider`'s redirect logic only if it's cheaply testable with the
  existing auth fakes in `fakes.dart`; if the auth bootstrap can't be faked
  without touching out-of-scope files, document the manual check instead:
  `adb shell am start -a android.intent.action.VIEW -d "mitlist://join/TEST-CODE"`
  (note it in your report as not-automated).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0 (modulo 2 pre-existing infos)
- [ ] `cd frontend && flutter test` exits 0; ≥ 10 new tests across the two new files
- [ ] `grep -n 'android:host="join"' frontend/android/app/src/main/AndroidManifest.xml` → 1 match
- [ ] `grep -n "joinLanding" frontend/lib/router.dart` → ≥ 1 match
- [ ] `grep -n "buildInviteLink" frontend/lib/sheets/invite_household_sheet.dart` → ≥ 1 match (QR payload)
- [ ] `grep -n "Share.share" frontend/lib/sheets/invite_household_sheet.dart` → 1 match
- [ ] `grep -rn "Icons\." frontend/lib/screens/auth/join_landing_screen.dart frontend/lib/sheets/invite_household_sheet.dart` → no matches
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The router redirect block no longer matches the excerpt (something else
  changed auth routing since `40f73b32`).
- Setting the current group after join turns out to require state changes
  outside `join_landing_screen.dart` (i.e. `join_household_sheet.dart`'s
  success phase mutates a provider whose API you'd have to change) — report
  what it actually does rather than modifying out-of-scope providers.
- The `GroupInvite` model lacks `.code` or `inviteMember` has changed shape.
- The invite query param demonstrably cannot survive the guest sign-in flow
  without modifying `welcome_screen.dart` or auth providers — STOP and
  report; expanding scope into auth screens is the maintainer's call.
- Any change to the OAuth intent-filter entry seems necessary — it never is
  for this plan.

## Maintenance notes

- **Deferred, deliberately**: HTTPS universal/app links (needs
  `assetlinks.json` + AASA hosting — bundle with release engineering / the
  landing site), a join page on `landing/` for recipients without the app,
  and invite-code TTL/expiry UX (whatever the backend enforces today is
  surfaced only as the join error message).
- The share text hardcodes English; when i18n lands this string moves with it.
- If the backend ever scopes invite codes per-instance (self-host), the
  scheme link still works because it carries no host — but a future HTTPS
  link must encode the instance URL; design that with release engineering.
- Reviewer scrutiny: the redirect changes must not alter behavior for any
  location that doesn't start with `/join/` or carry `invite=` (diff the
  redirect function carefully); the QR payload change means old screenshots/
  printed QRs encode bare codes — the join sheet's manual entry still
  accepts those, so nothing breaks.
