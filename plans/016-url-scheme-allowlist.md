# Plan 016: Allowlist URL schemes before launching external links

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/lib/sheets/recipe_detail_sheet.dart frontend/lib/utils`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/009-frontend-test-baseline.md
- **Category**: security
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

Recipe `sourceUrl`/`videoUrl` come from the server (and originally from user
input or scraping). They are launched with no scheme validation, so a malicious
or corrupted value (`javascript:`, `file:`, `intent:`, `tel:` …) is handed
straight to the OS. Platform intent filtering blunts most of this, but an
allowlist is one line of defense that costs nothing.

## Current state

- `frontend/lib/sheets/recipe_detail_sheet.dart:499–509`:

  ```dart
  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // URL launch failed; no-op to avoid crashing the sheet.
    }
  }
  ```

- Enumerate ALL launch sites first: `grep -rn "launchUrl\|launchUrlString" frontend/lib/`
  — fix every site that launches **server- or user-provided** URLs the same way.
  Sites launching app-internal constants (e.g. OAuth/native launcher in
  `lib/utils/native_oauth_launcher.dart`, docs links) keep their current
  behavior but verify they use literal constants; report any that don't.
- Utils convention: small helpers live in `frontend/lib/utils/` (e.g.
  `format_currency.dart`, `debounce.dart`) — single-function files, no classes.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Analyze | `dart analyze lib/`          | exit 0              |
| Tests   | `flutter test`               | all pass            |

## Scope

**In scope**:
- New `frontend/lib/utils/safe_launch.dart`
- Every call site launching non-constant URLs (per Step 1 inventory)
- New test `frontend/test/utils/safe_launch_test.dart`

**Out of scope**:
- OAuth/redirect launch flows (custom schemes are required there).
- The url_launcher dependency or LaunchMode choices.

## Git workflow

- Branch: `fix/url-scheme-allowlist` off `new-main-fr`.
- One conventional commit (`fix: allowlist http/https before launching external URLs`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Inventory launch sites

Run the grep above; classify each site: constant URL (leave) vs dynamic
server/user URL (migrate).

### Step 2: Add the helper

`frontend/lib/utils/safe_launch.dart`:

```dart
/// Launches [url] externally only if it parses and its scheme is http/https.
/// Returns true if a launch was attempted.
Future<bool> safeLaunchUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
```

(Keep `canLaunchUrl` out — it produces false negatives on Android 11+ without
queries entries and the try/catch already covers failure.)

### Step 3: Migrate dynamic sites

Replace `_launchUrl`-style bodies with calls to `safeLaunchUrl`. Delete the
now-dead private helpers.

**Verify**: `dart analyze lib/` → exit 0; `grep -rn "launchUrl(" frontend/lib/ | grep -v safe_launch | grep -v native_oauth` → only constant-URL sites remain.

### Step 4: Test

`frontend/test/utils/safe_launch_test.dart`: pure-function part only — assert
scheme filtering via a thin seam (extract the validation into
`bool isSafeExternalUrl(String url)` inside the same file and test THAT:
http/https accepted; javascript:, file:, intent:, data:, empty, garbage rejected).

**Verify**: `flutter test` → all pass.

## Done criteria

- [ ] `dart analyze lib/` exits 0; `flutter test` exits 0
- [ ] `safe_launch.dart` exists; recipe sheet uses it; validation unit-tested
- [ ] Step 3 grep clean
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A dynamic-URL site needs a non-http scheme legitimately (e.g. mailto from a
  profile) — report it; we'll extend the allowlist deliberately.

## Maintenance notes

- New external-link features must use `safeLaunchUrl`.
- Reviewer: confirm OAuth flows untouched.
