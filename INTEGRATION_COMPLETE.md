## INTEGRATION_COMPLETE

This repository now contains a verified integration between:
- Go backend (`backend/`)
- Flutter frontend (`frontend/`)

### What was verified (evidence-based)
- **Build/test gates**
  - Backend: `go test ./...` and `go build ./...` passed.
  - Frontend: `flutter analyze` and `flutter test` passed.
- **Live backend reachability (docker)**
  - `GET /api/v1/auth/me` without a token returns `401` with a JSON error envelope.
  - Guest auth → create group → create vault item → list vault items works end-to-end after mounting vault routes.
  - Details are recorded in `LIVE_INTEGRATION_RESULTS.md`.

### Integration map
See `INTEGRATION_MAP.md` (joined from `BACKEND_SURFACE.md` and `FRONTEND_CONSUMPTION.md`).

### Findings and resolutions
All findings were triaged and tracked in `INTEGRATION_AUDIT.md`. Current status:
- **CRITICAL**: 0
- **HIGH**: 0
- **MEDIUM**: 0
- **LOW**: 1 (finance amount range/precision contract risk for Flutter web)

Key resolved items include:
- Vault endpoints mounted and wired in backend container.
- Backend error envelope standardized so responses reliably include `error` (stable code) and `message`.
- Flutter auth refresh hardened with single-flight coordination and reliable session invalidation propagation (all service clients now inject `Ref`).
- Group-scoped screens guard against missing/invalid `group_id`.
- Pagination wiring added to major list screens (offset/limit).
- Flutter models no longer invent missing backend fields (counts/flags treated as unknown when omitted).
- Request DTOs omit nullable keys instead of sending explicit JSON `null` that Go decodes into empty strings.

### Deferred / assumptions
- **Finance amount type**: backend uses `int64`, Flutter uses `int`. This is safe on native runtimes but can be risky if the Flutter app is compiled to web and very large values appear; monitor and consider a 64-bit safe representation.
- **Admin/member permissions UX**: backend enforces permissions; frontend now handles failures more consistently, but full role-aware UI gating would require an explicit membership/role contract.
- **Notifications / realtime**: Flutter now has a notifications inbox screen and can manage notification preferences; push subscription device registration is still not integrated (only API client methods exist). See `INTEGRATION_GAPS_realtime-background.md`.

