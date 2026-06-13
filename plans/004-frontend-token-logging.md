# Plan 004: Stop logging bearer tokens and PII from the Dio client

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- frontend/lib/services/api_client.dart`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

The shared Dio client unconditionally attaches a `LogInterceptor` with `requestBody: true, responseBody: true`, routed through the `logger` package. Every API call's `Authorization: Bearer <token>` header and full response payload (emails, names, household financial data) is handed to the logging pipeline. Today the only thing preventing this in release builds is the `logger` package's *default* filter behavior — an implicit guard that breaks silently if anyone passes a custom filter, changes log level, or wires logs to a remote sink (the repo already has a GlitchTip/Sentry-compatible reporter in `frontend/lib/services/error_reporter.dart`). Make the guard explicit and redact credentials even in debug.

## Current state

`frontend/lib/services/api_client.dart:150–176`:

```dart
Dio createApiClient([Ref? ref]) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      ...
    ),
  );

  dio.interceptors.add(TokenRefreshInterceptor(dio, ref));
  dio.interceptors.add(AuthInterceptor());

  final logger = Logger();
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (object) => logger.d(object),
  ));

  return dio;
}
```

Note `LogInterceptor`'s default `requestHeader: true` also prints headers, which is where the bearer token leaks. Conventions: this file already imports `package:logger/logger.dart`; Flutter's debug-mode constant is `kDebugMode` from `package:flutter/foundation.dart`.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|-------------------------------|---------------------|
| Analyze | `dart analyze lib/`           | exit 0, no issues   |
| Tests   | `flutter test`                | all pass            |

## Scope

**In scope**:
- `frontend/lib/services/api_client.dart`

**Out of scope**:
- `TokenRefreshInterceptor`, `AuthInterceptor` — unrelated.
- `frontend/lib/services/error_reporter.dart` — verify it doesn't capture request bodies, but change nothing; if it does, report it as a finding.
- Backend logging.

## Git workflow

- Branch: `fix/redact-api-logging` off `new-main-fr`.
- Conventional commit, e.g. `fix: gate Dio logging behind kDebugMode and redact auth headers`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Gate and redact the interceptor

Replace the `LogInterceptor` block with an explicitly debug-only, header-redacting version:

```dart
if (kDebugMode) {
  final logger = Logger();
  dio.interceptors.add(LogInterceptor(
    requestHeader: false,
    responseHeader: false,
    requestBody: false,
    responseBody: false,
    logPrint: (object) => logger.d(object),
  ));
}
```

Keep request/response *lines* (method, URI, status) by leaving `request: true` / `responseHeader: false` defaults as shown — the goal is: no headers, no bodies, debug builds only. Add the `kDebugMode` import (`package:flutter/foundation.dart`) if not already imported.

If developers actively rely on body logging for debugging (you cannot know this; assume not), they can flip the booleans locally — note this in the commit message.

**Verify**: `dart analyze lib/` → exit 0.

### Step 2: Confirm no other body-logging sites

`grep -rn "LogInterceptor\|requestBody: true\|responseBody: true" frontend/lib/` → only the (now-gated) site in `api_client.dart` should match. Also `grep -rn "Authorization" frontend/lib/services/error_reporter.dart` → if the error reporter attaches headers/bodies to reports, do not change it; record in your report.

**Verify**: grep output as described.

### Step 3: Run tests

**Verify**: `flutter test` → all pass (3 existing test files at planning time).

## Test plan

No new tests required — this is configuration of a third-party interceptor; `dart analyze` + existing suite suffice. If the repo later gains an HTTP-layer test harness, a regression test asserting no `Authorization` string in captured log output would be the right follow-up.

## Done criteria

- [ ] `dart analyze lib/` exits 0
- [ ] `flutter test` exits 0
- [ ] `grep -n "kDebugMode" frontend/lib/services/api_client.dart` matches; `grep -n "requestBody: true" frontend/lib/` matches nothing
- [ ] Only `api_client.dart` modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `api_client.dart` no longer matches the excerpt (drift).
- You find evidence (comments, a debug screen reading these logs) that body logging feeds a user-visible feature.

## Maintenance notes

- If anyone adds remote log shipping (the GlitchTip reporter exists), re-audit every `logger` call site for PII — this plan only fixes the Dio interceptor.
- Reviewer: confirm the interceptor ordering (TokenRefresh → Auth → Log) is unchanged.
