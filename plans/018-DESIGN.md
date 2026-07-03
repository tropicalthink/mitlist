# Plan 018 Design: Household Prior Sync

## Recommendation Summary

Sync raw purchase events through a new batch endpoint and derive co-occurrence on the server from those events. Keep the existing local writes as an immediate cache for offline UX, then merge server-delivered purchase history and derived co-occurrence through the grocery graph delta. Do not sync client-side co-occurrence counters as authoritative data.

No PoC branch was created. The spike deliverable is a design only because the requested batch is closing the plan backlog, and a safe PoC would touch production endpoint, outbox, and delta-apply code across both apps.

## Current Facts

- Local capture happens in `ListRepository._doPurchaseSignal`: checking an item writes `purchase_history` and increments `item_cooccurrence` in Drift only.
- Resolver and restock already consume local history through `getGroupPurchaseHistory` and `getTopCooccurrences`.
- Backend tables and delta models already include `purchase_history` and `item_cooccurrence`.
- The backend currently has no purchase writer.
- The Flutter grocery delta apply path currently ignores `purchase_history` and `item_cooccurrence`.
- `PRIVACY.md` says all household data lives on the operator's own server, with no first-party telemetry by default. Server-side purchase history is acceptable as household data, but it must not become project telemetry.

## 1. Unit of Sync

Recommendation: sync raw purchase events, idempotent by client-generated event id.

Rejected alternative: sync aggregated counters. Counters are smaller, but they create merge ambiguity across devices and make duplicate retries hard to distinguish from real repeat purchases.

Server should derive co-occurrence from events inside the same transaction. The local `incrementCooccurrences` remains a cache for immediate personalization and offline use.

Event fields:

- `id`
- `group_id`
- `canonical_item_id`
- `list_item_id`
- `quantity`
- `unit`
- `purchased_at`
- optional future `user_id`

## 2. Transport

Recommendation: add `POST /groups/{id}/grocery/purchases` accepting a bounded batch of purchase events.

Rejected alternative: piggyback on corrections. Corrections are user review facts; purchase history is behavioral household memory. Mixing them would pollute validation, retention, and audit semantics.

The endpoint should:

- require group membership
- accept at most 200 events per request
- use `WithTx`
- insert events with `ON CONFLICT (id) DO NOTHING`
- increment the grocery version only when at least one event is new
- derive co-occurrence rows for new same-list/same-batch events
- publish `grocery:graph_updated` after commit

## 3. Merge Semantics On Pull

Recommendation: append-only event merge by id, and server-derived co-occurrence snapshots upserted by `(group_id, item_a_id, item_b_id)`.

Rejected alternative: last-writer-wins client counters. Co-occurrence is a counter; LWW loses increments and makes offline retries unsafe.

Client delta apply should consume:

- `purchase_history`: `insertOrIgnore` by event id
- `item_cooccurrence`: upsert by pair, treating the server count as authoritative

Existing Plan 014 pagination bounds first sync and large history pulls.

## 4. Volume And Privacy

Estimate: a household checking off 40 canonical items/week creates about 2,080 purchase events/year. A heavier household at 150/week creates about 7,800/year. At roughly 120 to 200 JSON bytes/event before gzip, this is modest, but first sync should be bounded by the existing 500-row delta pages.

Retention recommendation: keep all events initially, but expose a server config later for retention such as 24 months. Local reads already cap at 500 rows for resolver/restock performance.

Privacy recommendation: document purchase history as household data stored on the operator server, not telemetry. Do not send it to crash reporting or external analytics. If a hosted edition ever appears, make this feature explicit in privacy copy.

## 5. Deletion

Recommendation: group deletion cascades purchase history through existing `group_id` FKs. Account deletion should remove account-owned rows where a future `user_id` is recorded, or anonymize `user_id` while keeping household aggregate rows if the household remains.

Rejected alternative: omit `user_id` forever. That avoids per-user deletion semantics but prevents useful audit and opt-out controls. Add nullable `user_id` to server `purchase_history` in the implementation slice; local schema can remain userless until UI needs it.

## 6. Cold Start Interplay

Recommendation: fresh installs pull purchase history through the grocery delta. Plan 014 pagination means a first sync with 2,000 history rows costs about 4 pages just for history rows. That is acceptable for household-scale data.

Rejected alternative: separate restock/prior endpoint. That reduces delta size but duplicates cursor mechanics and makes cross-device consistency harder.

For very large households, add `?include_history=false` later only if measured first-sync time becomes a problem.

## Implementation Slices

1. Backend purchase ingest endpoint (M): model request, repository `InsertPurchaseBatch`, co-occurrence derivation, validation, integration tests.
2. Client outbox upload (M): enqueue purchase events from `_doPurchaseSignal`, retry through existing outbox drainer, preserve local immediate writes.
3. Client delta apply (S): consume `purchase_history` and `item_cooccurrence` arrays into Drift and add repository tests.
4. Resolver/restock verification (S): prove merged remote rows affect `EnsembleResolver.buildContext` and `RestockService`.
5. Backfill strategy (M): one-time upload of unsynced local history with a cap and user-visible opt-out if needed.

## Open Questions

- Should purchase events include `user_id` immediately or wait for account deletion/product requirements?
- Should retention be hard-coded, operator-configurable, or absent until measured?
- Should same-list co-occurrence derive only within the uploaded batch or across historical list contents by `list_item_id`?

