# Plan 025: Stand up the Flutter localization pipeline and localize one reference screen into English + German

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat fea883d3..HEAD -- frontend/pubspec.yaml frontend/lib/app.dart frontend/lib/screens/auth/welcome_screen.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW (additive; no behavior change for existing English users)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `fea883d3`, 2026-06-13

## Why this matters

The app targets flatshares, and German is clearly an intended market — the
grocery graph already stores `name_de`/`name_en`, and Flatastic (German) is in
the README's competitor table. The Flutter localization toolchain is **declared
but completely dormant**: `pubspec.yaml` already has `intl` and `generate: true`,
yet there are **zero `.arb` files and zero `AppLocalizations` usage** — every UI
string is hardcoded English. This plan does NOT translate the whole app (a bad
single task). It builds the pipeline once, converts ONE reference screen
(`WelcomeScreen`) end to end as the copy-paste pattern, ships English + German
for it, and documents the extraction convention so the rest can proceed
incrementally and in parallel.

## Current state

- `frontend/pubspec.yaml` — has `intl: ^0.19.0` (line ~39) and a Flutter section
  with `generate: true` (line ~89). It does **not** yet depend on
  `flutter_localizations`. There is **no `l10n.yaml`** at `frontend/`.
- `frontend/lib/app.dart` — the root `MaterialApp` (likely `MaterialApp.router`,
  since the app uses `go_router`). It currently sets no
  `localizationsDelegates` / `supportedLocales`. Confirm by reading it.
- `frontend/lib/screens/auth/welcome_screen.dart` — the reference screen, 161
  lines, a `ConsumerStatefulWidget`. Its user-facing literals (verbatim):
  - `'mitlist'` — **brand name; do NOT translate** (leave as a literal).
  - `'Your household, organized.'`
  - `'Lists, chores, money.\nAll in one place.'`
  - `'Built for flatmates who want less friction and more clarity.'`
  - `'Create free household'`
  - `'Sign in'`
  - `'Setting up...'` (the loading label of the guest button)
  - `'Continue as guest'`
  - `'No account needed. Try everything free for 30 days.'`
  - The error SnackBar uses `friendlyErrorMessage(e)` — NOT a literal; leave it.

Verify the literals are still present and unchanged:
`grep -n "Your household, organized\|Create free household\|Continue as guest" frontend/lib/screens/auth/welcome_screen.dart`

## Commands you will need

| Purpose            | Command (from `frontend/`)             | Expected                          |
|--------------------|----------------------------------------|-----------------------------------|
| Fetch deps         | `flutter pub get`                      | exit 0; resolves `flutter_localizations` |
| Generate l10n      | `flutter gen-l10n`                     | exit 0; writes generated `AppLocalizations` |
| Analyze            | `dart analyze lib/`                    | no errors                         |
| Tests              | `flutter test`                         | all PASS                          |

Note: with `generate: true`, `flutter pub get` / a build also triggers l10n
generation; `flutter gen-l10n` runs it explicitly. The generated class lands in
the package's synthetic `flutter_gen` output and is imported as
`package:flutter_gen/gen_l10n/app_localizations.dart` **unless** `l10n.yaml`
sets `synthetic-package: false` (recommended below — then it lands in
`lib/l10n/`). Use whichever import path matches the config you write.

## Scope

**In scope** (create unless noted):
- `frontend/pubspec.yaml` (modify — add `flutter_localizations`)
- `frontend/l10n.yaml` (create)
- `frontend/lib/l10n/app_en.arb` (create)
- `frontend/lib/l10n/app_de.arb` (create)
- `frontend/lib/l10n/README.md` (create — the extraction convention)
- `frontend/lib/app.dart` (modify — wire delegates + supportedLocales)
- `frontend/lib/screens/auth/welcome_screen.dart` (modify — use `AppLocalizations`)
- `frontend/test/` — one widget test (see Test plan)

**Out of scope**:
- Every other screen/sheet/widget string — deferred to incremental follow-up
  (this plan ships the pattern + the README that explains how).
- A language picker in settings — the app follows the device locale this plan;
  an in-app override is a deferred follow-up.
- Translating the brand name `mitlist`, error messages routed through
  `friendlyErrorMessage`, or any developer-facing/log strings.

## Git workflow

- Branch: `advisor/025-i18n-foundation`
- Commit per step; conventional-commit style (e.g.
  `feat: add Flutter l10n pipeline and localize the welcome screen (en, de)`).
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add `flutter_localizations`

In `pubspec.yaml`, under `dependencies:` (near `intl`), add:

```yaml
  flutter_localizations:
    sdk: flutter
```

Leave `generate: true` as is.

**Verify**: `flutter pub get` → exit 0.

### Step 2: Create `frontend/l10n.yaml`

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
```

(`synthetic-package: false` makes the generated file land in `lib/l10n/`, so the
import is `package:<app_package>/l10n/app_localizations.dart`. Find the app
package name from the `name:` field at the top of `pubspec.yaml`.)

**Verify**: file exists; `flutter gen-l10n` will be run in Step 4.

### Step 3: Author the ARB files

`frontend/lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "welcomeTagline": "Your household, organized.",
  "@welcomeTagline": { "description": "Subtitle under the app name on the welcome screen" },
  "welcomeCardTitle": "Lists, chores, money.\nAll in one place.",
  "@welcomeCardTitle": { "description": "Headline in the welcome card; contains a line break" },
  "welcomeCardBody": "Built for flatmates who want less friction and more clarity.",
  "welcomeCreateHousehold": "Create free household",
  "welcomeSignIn": "Sign in",
  "welcomeGuestLoading": "Setting up...",
  "welcomeContinueAsGuest": "Continue as guest",
  "welcomeGuestFootnote": "No account needed. Try everything free for 30 days."
}
```

`frontend/lib/l10n/app_de.arb`:

```json
{
  "@@locale": "de",
  "welcomeTagline": "Dein Haushalt, organisiert.",
  "welcomeCardTitle": "Listen, Aufgaben, Geld.\nAlles an einem Ort.",
  "welcomeCardBody": "Gemacht für WGs, die weniger Reibung und mehr Klarheit wollen.",
  "welcomeCreateHousehold": "Kostenlosen Haushalt erstellen",
  "welcomeSignIn": "Anmelden",
  "welcomeGuestLoading": "Wird eingerichtet …",
  "welcomeContinueAsGuest": "Als Gast fortfahren",
  "welcomeGuestFootnote": "Kein Konto nötig. 30 Tage lang alles kostenlos testen."
}
```

(The brand string `mitlist` is intentionally NOT a key — it stays a literal.)

**Verify**: both files are valid JSON (`python3 -m json.tool lib/l10n/app_en.arb >/dev/null` → exit 0; same for `_de`).

### Step 4: Generate and wire the delegates

Run `flutter gen-l10n` → it writes `lib/l10n/app_localizations.dart` (+ per-locale
parts). Confirm: `ls lib/l10n/app_localizations.dart`.

In `lib/app.dart`, on the root `MaterialApp`/`MaterialApp.router`, add:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart'; // adjust relative path to app.dart

// inside the MaterialApp(...):
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
```

(`AppLocalizations.localizationsDelegates` already bundles the Material/Widgets/
Cupertino delegates, so you do not list them individually.)

**Verify**: `flutter gen-l10n` exit 0; `dart analyze lib/app.dart` → no errors.

### Step 5: Convert the welcome screen

In `welcome_screen.dart`, import the generated class and replace each literal
listed in "Current state" with its key. In `build`, capture once:
`final l10n = AppLocalizations.of(context)!;` then e.g.
`Text(l10n.welcomeTagline, ...)`, button `text: l10n.welcomeCreateHousehold`,
guest button `text: _isGuestLoading ? l10n.welcomeGuestLoading : l10n.welcomeContinueAsGuest`,
etc. Leave the `'mitlist'` logo `Text` and the `friendlyErrorMessage(e)`
SnackBar untouched.

**Verify**: `grep -n "'Your household, organized.'\|'Create free household'\|'Continue as guest'" frontend/lib/screens/auth/welcome_screen.dart`
returns **no matches** (all literals replaced); `dart analyze lib/` → no errors.

### Step 6: Document the convention

Create `frontend/lib/l10n/README.md`: a short guide — where ARB files live, the
key-naming convention (`<screen><Thing>`, camelCase), how to add a string (add
to `app_en.arb` with an `@`-description, add the same key to `app_de.arb`, run
`flutter gen-l10n`, reference via `AppLocalizations.of(context)!`), what NOT to
localize (brand name, log/dev strings, `friendlyErrorMessage` output), and how
placeholders/plurals work in ARB (link to
`https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization`).

**Verify**: file exists.

### Step 7: Tests + full suite (see Test plan).

**Verify**: `flutter test` → all PASS.

## Test plan

- New widget test `frontend/test/welcome_localization_test.dart`: pump
  `WelcomeScreen` inside a `MaterialApp` configured with
  `localizationsDelegates: AppLocalizations.localizationsDelegates` and
  `supportedLocales`, once with `locale: const Locale('en')` asserting
  `find.text('Create free household')`, and once with `locale: const Locale('de')`
  asserting `find.text('Kostenlosen Haushalt erstellen')`. Model the
  ProviderScope/override setup on an existing widget test in `frontend/test/`
  (e.g. the join-landing or flows test — `grep -rln "ProviderScope" frontend/test/`).
  If `WelcomeScreen` needs `authServiceProviderAsync` overridden to pump without
  hitting a real service, follow the override pattern in AGENTS.md "Testing".
- Verification: `flutter test test/welcome_localization_test.dart` → PASS, then
  `flutter test` → all PASS.

## Done criteria

ALL must hold:

- [ ] `flutter pub get` exits 0 (resolves `flutter_localizations`)
- [ ] `flutter gen-l10n` exits 0 and `lib/l10n/app_localizations.dart` exists
- [ ] `dart analyze lib/` reports no errors
- [ ] `flutter test` all PASS, including the new en/de localization test
- [ ] `grep -rn "Your household, organized." frontend/lib/screens/auth/welcome_screen.dart`
      returns no matches (literals replaced)
- [ ] `frontend/l10n.yaml`, `app_en.arb`, `app_de.arb`, and `lib/l10n/README.md`
      all exist
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The welcome-screen literals don't match "Current state" (drift since `fea883d3`).
- `flutter gen-l10n` produces the class at an import path different from what
  `l10n.yaml` implies and you cannot resolve the correct import — report the
  actual generated path.
- `app.dart` already wires `localizationsDelegates` (someone added l10n since) —
  reconcile rather than duplicate, and report.
- Adding `flutter_localizations` triggers an SDK/version solve conflict (the repo
  pins the Dart SDK per `project_mitlist`/pubspec notes) — report the conflict;
  do not bump the SDK pin.

## Maintenance notes

- This ships the **pattern**, not full coverage. Follow-up work: extract the
  remaining screens incrementally (each PR converts a screen + adds its keys to
  both ARB files). The README is the contract for that work.
- A device-locale-following app needs no language picker; if users ask for an
  in-app override, add a `locale` provider feeding `MaterialApp.locale` — a
  small, separate plan.
- Reviewer scrutiny: confirm German strings render without overflow on the
  reference screen (German is ~30% longer — watch `Text` widgets without
  `maxLines`/`overflow` in constrained rows, per the AGENTS.md anti-patterns).
- Keep the brand name `mitlist` out of the ARB files permanently.
