# Plan 018 (SPIKE): Design household prior sync — purchase history + co-occurrence across devices

> **Executor instructions**: This is a DESIGN SPIKE. The deliverable is a
> design document (`plans/018-DESIGN.md`) plus at most a thin proof-of-concept
> branch — no production merge. Investigate, decide, document, list open
> questions for the maintainer. Honor STOP conditions. Update the index row
> when done.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- backend/internal/repositories/grocery_repo.go backend/migrations/000027_add_grocery_graph.up.sql frontend/lib/repositories/list_repository.dart frontend/lib/repositories/grocery_repository.dart`
> Plans 001/005/014 are expected to have landed here; read their diffs as input, not drift.

## Status

- **Priority**: P3 (highest-value direction item, but gated on 001+005+014)
- **Effort**: L (coarse — spike itself is M)
- **Risk**: MED (write-amplification, privacy surface)
- **Depends on**: plans/001, 005, 014 landed; 002 strongly recommended (else there's little signal to sync)
- **Category**: direction
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The resolver's "household prior" (purchase frequency, recency, co-occurrence) is the feature set that personalises resolution and powers restock — and today it is **per-device**: recorded only into local Drift on item check-off, never uploaded, never merged. A second household member gets none of it; a reinstall erases it. The striking part: the entire remote half already exists as dead scaffolding — server tables (`purchase_history`, `item_cooccurrence`, migration 000027:95-116), Go models, delta serialization (`grocery_service.go:62-67`), and even the client's delta-apply loop shape — only the **upload path and server writes are missing**, plus the client ignores those two delta arrays. This spike designs that missing half properly instead of bolting it on.

## What exists (read these first)

- Local capture: `frontend/lib/repositories/list_repository.dart:876-925` — `_recordPurchaseSignal` on item check-off writes `purchase_history` + increments `item_cooccurrence` locally, fire-and-forget, gated on `canonicalItemId != null`.
- Local consumption: `EnsembleResolver.buildContext` (`ensemble_resolver.dart:86-133`) — counts, recency, co-occurrence from local tables; `RestockService` (`restock_service.dart:59+`) — cadence from `getGroupPurchaseHistory` (capped at 500 rows, `app_database.dart:1420`).
- Server scaffolding with zero writers: tables + models (`models/grocery.go:75-95`) + `GetDelta` sections (`grocery_repo.go:170-224`).
- Client gap: `_applyDelta` (`grocery_repository.dart:85-190`) parses four of the six delta arrays; `purchase_history` and `item_cooccurrence` are dropped.
- Offline machinery available: the outbox (`frontend/plans/001-005` hardened it; see `frontend/lib/repositories/list_repository.dart` enqueue patterns and the drainer) — purchase signals are exactly the fire-and-forget, retry-safe events it exists for.

## Questions the design doc must answer

1. **Unit of sync**: raw purchase events (append-only rows, id-deduped — matches the existing table) vs aggregated counters (smaller, but merge conflicts). Recommendation to evaluate first: raw events through the outbox with server-side identity dedupe; co-occurrence *derived server-side* from events rather than synced as a matrix (the local `incrementCooccurrences` then becomes a device-side cache of a server-computable fact — decide who owns derivation).
2. **Transport**: new `POST /groups/{id}/grocery/purchases` batch endpoint stamped through the same `NextVersion` cursor (fits Plan 014's tx + pagination machinery) — or piggyback on the existing corrections endpoint with a new `kind` (rejected? corrections are semantically different; argue it either way in the doc).
3. **Merge semantics on pull**: events are append-only and idempotent by id — the easy case. Co-occurrence rows: last-writer-wins is wrong for counters; if the matrix syncs at all, it must sync as events or server-derived snapshots, never incremental client counters.
4. **Volume/privacy bounds**: a purchase event per check-off, per member — estimate rows/household/year; retention (the local read cap is 500 — mirror server-side?); PRIVACY.md alignment (purchase history is behavioral data — what does the current policy promise? read `PRIVACY.md` and quote it in the doc).
5. **Deletion**: leaving a household / deleting an account — cascade semantics already exist via `group_id` FK; personal deletion within a group (user_id is not even recorded locally today — should it be?).
6. **Cold-start interplay**: after this syncs, a fresh install pulls history via delta — measure/estimate first-sync size against Plan 014's pagination.

## Spike steps

1. Read the listed code + `PRIVACY.md`; write the design doc answering the six questions, each with a recommendation and its rejected alternative.
2. Thin PoC (throwaway branch `spike/018-prior-sync`, never merged): the batch upload endpoint + outbox enqueue on `_doPurchaseSignal` + `_applyDelta` consuming `purchase_history` — enough to demo one purchase appearing on a second client via the existing integration harness. Timebox: if the PoC exceeds a day, stop and ship the doc alone.
3. List the implementation plan slices (likely: 1 backend endpoint+derivation, 2 client outbox+apply, 3 restock/resolver switch to merged data, 4 backfill existing local history) with S/M/L estimates each.

## Done criteria

- [ ] `plans/018-DESIGN.md` exists, answers all six questions with recommendations
- [ ] PoC branch pushed locally (or explicitly skipped with the timebox reason recorded)
- [ ] Implementation slices listed with estimates and dependency order
- [ ] `plans/README.md` status row updated

## STOP conditions

- Plans 001/005/014 not all DONE — the spike's assumptions about cursors/ids/pagination don't hold yet.
- `PRIVACY.md` explicitly rules out server-side behavioral data — the design becomes opt-in-only; flag to maintainer before continuing.

## Maintenance notes

- This spike supersedes the dead scaffolding question from the audit (backend DEBT-01): once the design lands, either the arrays get real data or the doc justifies deleting them — no third state.
