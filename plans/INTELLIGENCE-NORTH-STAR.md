# Intelligence North Star — the on-device, zero-marginal-cost law

> This is not a plan. It is the **constraint every intelligence plan inherits**.
> Plans 028–033 (and anything after) must satisfy the law below or they don't
> ship. When writing or reviewing one of those plans, check it against the
> "Done-criteria gate" at the bottom.

Written 2026-06-13. Owner context: mitlist is an **open-source project whose
hosted version is completely free**. There is no per-user revenue. Therefore:

## The law

**Every prediction runs on-device or was computed at build time. The backend
never runs a model in the request path.**

A "prediction" = resolving an item, ranking a suggestion, embedding a query,
classifying OCR text, assigning an aisle, parsing an ingredient, etc.

Three legal execution tiers — in priority order:

1. **On-device (preferred).** Runs on the phone. Zero marginal cost, private,
   works offline/on a plane. This is the default home for every prediction.
2. **Build-time.** Computed once, offline, on a developer/CI machine — then
   shipped as a **versioned bundle** (the model/graph versioning already exists;
   see `GrocerySeedLoader` + the grocery delta-sync). Examples: distilling the
   static embedder, precomputing the 3,239 canonical-item vectors, deriving the
   Open Food Facts index, mining a substitutes/co-occurrence graph.
3. **Backend, sync/distribution only.** The server stores household data, syncs
   it, and **hands out versioned bundles**. It must not run an LLM/encoder per
   request. (Matches `intelligence/plan.md`: "the backend is for sync, taxonomy
   updates, and model distribution — never required for a prediction.")

**Illegal:** any per-request cloud inference in the hosted free tier. The
existing CrofAI/kimi cloud scan call is the one current violation — it becomes
opt-in / self-host-only (plan 032), then is retired by an on-device VLM (033).

## Why the constraint is the moat (not a limitation)

Commercial rivals (Bring!, Samsung Food, Whisk) run cloud AI per user and
monetize the data to pay for it. A free+open project **cannot** carry per-call
cost — so we make on-device the architecture, and the things that fall out of
it (privacy, offline, no account required, zero cost, self-hostable) are exactly
the differentiators those rivals can't match. The constraint we're forced into
is the product wedge we'd have chosen anyway.

**Disruptive wedge:** crowd-sourced store/price/aisle intelligence built from
*users' own scans* (the Open Food Facts model applied to the shopping trip) —
not from supermarket APIs or partnerships. The household grocery brain that owes
nothing to any supermarket, runs on your phone, and is free.

## How the law applies to the big pieces

- **The 470 MB Phase-8 embeddings model** → **build-time only, never served.**
  Use it offline to (a) distill the tiny on-device static embedder and (b)
  precompute the canonical-item vectors. It never runs in production — not on
  device, not on the server. (This also resolved the 027 NO-GO: the size problem
  was always only the phone; the cost problem rules out serving it too.)
- **Recipe-scrape resolution** → precomputed catalog vectors + cosine in Go /
  on-device, plus alias match. No live encoder.
- **Open Food Facts** → ship a trimmed, versioned **offline bundle** (barcode
  index + nutrition/Nutri-Score/eco/allergens + category taxonomy + multilingual
  aliases). Backend distributes it; the device queries it locally.
- **Substitutes / "bought-together"** → mined offline into a shipped graph
  bundle, refreshed on a cadence. Never a live query.
- **Scanning** → on-device OCR (ML Kit, already) + on-device classifier resolve
  most scans now; a small on-device VLM (SmolVLM/Moondream) handles the hard
  cases later. Cloud is opt-in/self-host only.

## License green-list (required for free + open)

Use only permissive / share-alike sources. Confirmed acceptable:

| Source | License | Use |
|---|---|---|
| Open Food Facts | ODbL | product/barcode/nutrition bundle (attribute; keep derived index separable) |
| Wikidata | CC0 | food entities, multilingual labels, related-item edges |
| FoodOn ontology | CC-BY | food hierarchy / substitutes |
| SmolVLM, Moondream, gte-multilingual | Apache-2.0 | on-device VLM / embedding teacher |
| Model2Vec, e5, bge, ingredient-parser | MIT | static distillation, teachers, ingredient NER |

**Avoid:** RecipeNLG, Recipe1M+ (research-only — incompatible with a freely
hosted project, even for offline mining). Not needed: OFF + Wikidata + the
household's own data cover co-occurrence and substitutes.

## The plan map (consolidated — pre-prod, so plans are big coherent jumps)

Six granular plans were merged into four: the Open Food Facts bundle folds into
the embedder plan (they share the build-time bundle pipeline), and the on-device
VLM folds into the scanning plan (same surface, same goal).

| Plan | Scope | Tier |
|---|---|---|
| 028 | **On-device grocery brain**: OFF-enriched seed bundle + Model2Vec static embedder + precomputed catalog vectors → semantic autocomplete, semantic resolver fallback, barcode lookup (folds old 030) | build-time bundle + on-device |
| 029 | **Recipe → canonical shopping**: open ingredient parser + canonical resolution (alias now, 028's vectors later) on the scrape payload + add-to-list dedup/aisle-sort | build-time + on-device/Go |
| 031 | **Activate dormant signals**: predictive restock from `purchase_history`, pantry subtraction from `products` | on-device |
| 032 | **Fully on-device scanning**: default to on-device + gate CrofAI behind opt-in (phase 1), then on-device VLM (SmolVLM/Moondream) for hard cases to retire cloud (phase 2, folds old 033) | on-device |

Recommended order: **032 phase 1** (stops cost today) → **028** (the brain + the
multiplier) → **029** (recipe woah) → **031** (dormant signals) → **032 phase 2**
(retire cloud). 028 supersedes the 027 on-device NO-GO.

Build-time pipeline note: all build-time bundles extend the existing
`intelligence/ml/build_app_seed.py` → `frontend/assets/grocery/*.json`
(versioned, version-gated reseed via `GrocerySeedLoader`) pattern. New bundles
(embedder table, catalog vectors, OFF barcode/nutrition index) ship the same way.

## Done-criteria gate (paste into every 028–033 plan)

A plan in this series is not done unless:

- [ ] No new code path performs cloud inference in the hosted free tier
      (`grep` the diff for new network calls to model/LLM endpoints — there must
      be none, or they must be behind an explicit opt-in/self-host flag).
- [ ] Every prediction it adds runs on-device or reads a build-time/shipped
      bundle.
- [ ] Any third-party data/model it introduces is on the license green-list
      above (named in the plan, with the license).
- [ ] Shipped assets are versioned (reuse the seed/bundle versioning), so the
      device can update them without an app release.
