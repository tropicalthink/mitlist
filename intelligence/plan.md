# Grocery Intelligence System — Refined Plan (v2)

This version merges the original system plan and the handwriting-first document into one coherent plan. Handwriting is now a core scanner requirement (not an appendix), the two overlapping correction-memory systems are unified into one, the local-LLM stance is made explicit, and gaps around localization, cold start, privacy, and sync are filled.

---

## 1. Vision

Build a grocery intelligence system that understands what a household buys, how they write and describe items, where those items are located in their stores, and what they are likely to need next.

This is not an OCR scanner with AI sprinkled on top. It is a household-specific grocery brain that improves through scans, typed items, corrections, completed trips, recipes, and receipts.

Guiding principles:

> LLMs teach. Small models execute. The graph remembers. User corrections train.

> Handwriting is the primary scan input, not an edge case. A handwritten list is the most common real-world grocery artifact.

> The system must know when it is unsure. No silent hallucination.

North-star product metric:

```text
Scanning a list (handwritten or printed) must be faster than typing it.
```

If review takes longer than typing, the system has failed regardless of model accuracy.

---

## 2. Architecture Overview

Four layers, one pipeline:

1. **Capture & enhancement layer** — camera guidance, frame selection, document cleanup
2. **Recognition & extraction layer** — routing, OCR, handwriting recognition, grocery extraction model
3. **Grocery graph & household memory** — canonical items, aliases, corrections, aisles, history
4. **Intelligence layer** — aisle prediction, suggestions, confidence, review

Runtime flow:

```text
image / typed text / receipt / recipe
→ capture quality gate (multi-frame, sharpest selected)
→ document detection (crop / rotate / deskew / dewarp / de-glare)
→ document-type + region routing (print / handwriting / mixed / receipt / recipe)
→ recognition (route-specific strategy, multi-candidate)
→ grocery extraction & correction model (one small model)
→ canonical graph resolution (aliases, corrections, embeddings)
→ aisle + suggestion layer
→ confidence gate → review UI
→ user feedback updates graph + correction memory
```

Everything above runs on-device by default. The backend is for sync, taxonomy updates, and model distribution — never required for a prediction.

---

## 3. Capture & Image Quality

Recognition quality is won or lost before any model runs.

Real-time camera guidance:

```text
move closer · hold steady · too dark · glare detected
paper edge not found · text is blurry · rotate slightly
```

Burst capture: take several frames, select the best by:

```text
sharpness · lighting · angle · document boundary quality
text contrast · motion blur
```

Then enhance: crop, rotate, deskew, dewarp (curved paper), shadow and glare reduction.

---

## 4. Document & Region Routing

Before recognition, classify the document and its regions. Different inputs need different strategies:

Document types:

```text
handwritten_list · printed_list · receipt · recipe_card · mixed · unknown
```

Region types:

```json
{
  "region_id": "region_04",
  "type": "handwritten_text",   // printed_text | handwritten_text | mixed_text | non_text | crossed_out_text | uncertain
  "confidence": 0.91,
  "bbox": { "x": 80, "y": 220, "width": 620, "height": 74 }
}
```

Routing consequences:

```text
printed receipt   → layout-aware OCR, price/quantity extraction, store inference
handwritten list  → handwriting recognition, aggressive grocery correction, mark detection
recipe card       → ingredient extraction, recipe-to-shopping conversion (later phase)
mixed             → per-region routing
```

### Visual mark detection (crossed-out / checked items)

Detect per-line marks:

```text
strikethrough · checkbox · checkmark · circle · bullet · scribble
```

```json
{
  "text": "milk",
  "status": "crossed_out",
  "suggested_action": "ignore",
  "confidence": 0.86
}
```

Crossed-out/checked items go into a separate "Ignored" section of the review screen, restorable with one tap. Never silently drop them.

---

## 5. Recognition Strategy

### Multi-pass, multi-candidate recognition

Never trust a single OCR result for handwriting. Each line produces candidates:

```json
{
  "raw_region": "line_05",
  "candidates": [
    { "text": "pnut butr",     "confidence": 0.62, "source": "handwriting_ocr" },
    { "text": "pnut buttr",    "confidence": 0.58, "source": "alternate_pass" },
    { "text": "peanut butter", "confidence": 0.91, "source": "grocery_correction" }
  ],
  "selected": "Peanut Butter"
}
```

Selection signals, in order of weight:

```text
exact household alias / past correction
grocery vocabulary match
current list context (co-occurrence plausibility)
item purchase frequency
OCR confidence
aisle/category plausibility
```

### OCR output contract

Whatever engine is used must produce:

```json
{
  "text": "PNT BUTTR 340G",
  "bbox": { "x": 120, "y": 440, "width": 260, "height": 48 },
  "confidence": 0.68,
  "line_id": "line_08",
  "region_id": "region_04"
}
```

Bounding boxes are mandatory — the review UI shows the original image strip per row, and corrections must map back to image regions for training data.

---

## 6. Grocery Extraction & Correction Model

One small grocery-focused model handles, in a single pass:

```text
OCR cleanup · shorthand expansion · item parsing
quantity/unit extraction · size extraction · price extraction
category hint · confidence
```

Input:

```text
2x pnut buttr 340g $3.99
```

Output:

```json
{
  "raw_text": "2x pnut buttr 340g $3.99",
  "corrected_name": "Peanut Butter",
  "quantity": 2,
  "unit": "jar",
  "size_value": 340,
  "size_unit": "g",
  "price_cents": 399,
  "category_hint": "spreads",
  "confidence": 0.91
}
```

### Grocery-aware correction, not spellcheck

The correction layer must learn grocery shorthand:

```text
mlk → Milk          egz → Eggs          bred → Bread
banannas → Bananas  pnut butr → Peanut Butter
avo → Avocado       tom → Tomatoes      chkn brst → Chicken Breast
dish tabs → Dishwasher Tablets          tom 500g → Tomatoes, 500g
```

Correction uses:

```text
global grocery vocabulary · household correction memory · known aliases
OCR confusion patterns · store-specific product history · co-occurrence context
```

Example of context-driven correction:

```text
Current list: bread, bananas
OCR sees:     pnut butr
Correction:   Peanut Butter
Reason:       common item, known alias pattern, frequently bought with bread
```

### Training the model for handwriting

This single model must be trained with handwriting-like noise from day one — there is no separate "handwriting model." Training data includes:

```text
real handwritten examples · synthetic handwriting OCR errors
abbreviated items · misspelled items · low-confidence OCR outputs
receipt/list mixed examples · user-corrected examples
German and English items, metric units, € prices
```

---

## 7. Canonical Grocery Graph

The graph is the core intelligence and the long-term moat.

```text
Peanut Butter
  aliases:        pnut butter, pnut buttr, PB, peanut spread, bnna-style household shorthand
  variants:       crunchy, smooth, organic
  default aisle:  Pantry / Spreads
  store aisles:   REWE home → Spreads · Aldi → Pantry
  bought with:    Jam, Bread, Bananas
  corrections:    pnut buttr → Peanut Butter (household, user_confirmed)
```

### Unified correction memory

The original plan had two overlapping stores (ocr_corrections and handwriting aliases). Unify them into **one correction memory** with a source field:

```json
{
  "raw_text": "bnna",
  "corrected_item": "Bananas",
  "canonical_item_id": "bananas",
  "household_id": "...",
  "source": "handwriting_correction",   // ocr_correction | typed_correction | suggestion_feedback
  "confidence": "user_confirmed",
  "scope": "household"                  // household | user | global_candidate
}
```

One lookup path, one learning loop, one sync model. A confirmed correction applies automatically next time, regardless of whether it came from print or handwriting.

Graph capabilities:

```text
canonical item resolution · alias lookup · correction memory
aisle prediction · store-specific aisle learning · item similarity
suggestions · household preferences · substitutions
```

The graph lives on-device (fast, offline) and syncs across household members.

### Graph structure (Epicure-style, shopping-adapted)

Nodes:

```text
items · aliases · brands · aisles · stores · recipes · shopping trips · households
```

Edges:

```text
alias_of · variant_of · bought_with · same_aisle · bought_at_store
corrected_to · ingredient_of · substitute_for · usually_after
```

Embeddings over this graph power similarity, substitutes, suggestions, canonical matching, and aisle inference — semantic behavior without calling an LLM per prediction.

### Cold start (new in v2)

A new household has an empty graph. Day-one quality comes from:

```text
shipped global taxonomy (top ~2,000 grocery items, DE + EN)
shipped global alias table (common shorthand and OCR confusions)
shipped default aisle taxonomy
optional onboarding: "scan your last receipt" to seed history
```

The household layer then personalizes on top. Never require weeks of usage before the scanner is useful.

---

## 8. Aisle Intelligence

Aisles are store-specific and household-specific. Prediction priority:

```text
1. Exact user override
2. Store-specific item aisle
3. Household aisle preference
4. Global taxonomy
5. Embedding/model fallback
6. User review if confidence is low
```

```text
Oat Milk
  Global default:        Dairy Alternative
  Household preference:  Drinks
  REWE store aisle:      Shelf-Stable Milk
  Aldi store aisle:      Drinks / Pantry
```

End goal: the list sorts by shopping path through the selected store, not alphabetically.

---

## 9. Suggestion Engine

Signals:

```text
frequently bought · recently bought · bought together · overdue staples
recipe ingredients · seasonal patterns · store-specific habits
accepted/dismissed feedback · current list context
```

Every suggestion must carry a reason:

```text
Bad:  "You may also need vegetables."
Good: "Add salsa? You bought it 8 of the last 10 times you bought tortillas."
```

```text
Current list: tortillas, ground beef, cheese, lettuce
Suggestions:
  Salsa — often bought with tortillas
  Sour cream — usually added for taco meals
  Avocado — bought with these items several times
  Tomatoes — missing from your usual taco set
```

---

## 10. Confidence System & Review UI

Every prediction carries a confidence score. Decision logic:

```text
exact household alias / confirmed correction → auto-accept
high-confidence graph match                  → auto-accept
medium model confidence                      → yellow review chip
low confidence / unknown                     → ask user, offer "create new item"
```

```text
OCR: "bannas"   → Bananas (0.97)        → auto-correct
OCR: "pnt br"   → Peanut Butter (0.48)  → ask user
OCR: "xylitol gum" → unknown            → create new item / ask user
```

### Review UI

Per row, the user sees:

```text
original image strip · recognized text · corrected item
quantity/unit · aisle · confidence color · quick alternatives
```

```text
✓ Milk — Dairy
✓ Bananas — Produce
? "Bred" → Bread — Bakery          [Bread | Brie | edit]
? "Tomatos 500" → Tomatoes, 500g   [confirm | edit]
Ignored:
  Milk — crossed out               [restore]
```

Interactions:

```text
tap image strip to see the detected region
pick from alternatives · edit directly
confirm all green items at once
save a correction as a household alias (one tap)
restore ignored/crossed-out items
```

The review UI is the learning loop, not a UX afterthought. Every action becomes training data. Optimize it ruthlessly for speed — confirm-all for greens, single-tap fixes for yellows.

---

## 11. Feedback Loop

Three learning levels:

```text
Global model:     general grocery intelligence (shipped, periodically retrained)
Household graph:  what this household buys, writes, and prefers
Store graph:      where items live in specific stores
```

Event → learning mapping:

```text
"Bred" → "Bread"                       → save correction (unified memory)
move Peanut Butter Pantry → Spreads    → save store/household aisle preference
accept "Jam" suggestion                → strengthen PB ↔ Jam edge
dismiss "Salsa" suggestion             → lower that suggestion for this household
buy Coffee weekly                      → mark as recurring staple
restore a "crossed_out" item           → mark-detection training signal
```

---

## 12. Data Model

Core tables:

```text
canonical_items · item_aliases · item_variants
aisles · stores · store_layouts · store_item_aisles
shopping_events · purchase_history · item_cooccurrences
corrections            (unified: OCR + handwriting + typed)
suggestion_feedback · model_predictions
household_item_preferences · recipe_ingredients
scan_artifacts         (image refs, regions, marks — for review + training)
```

List item shape:

```json
{
  "id": "...",
  "raw_text": "pnut buttr 340g",
  "display_name": "Crunchy Peanut Butter",
  "canonical_item_id": "peanut_butter",
  "quantity": 1, "unit": "jar",
  "size_value": 340, "size_unit": "g",
  "aisle_id": "spreads", "store_id": "rewe_home",
  "price_cents": 399,
  "source": "scan",
  "ocr_confidence": 0.72, "parse_confidence": 0.91, "aisle_confidence": 0.88,
  "mark_status": null,
  "user_corrected": true,
  "bbox": { "x": 123, "y": 441, "width": 220, "height": 44 }
}
```

The critical separation:

```text
raw_text           = what the system saw
display_name       = what the user sees
canonical_item_id  = what the system learns from
```

### Sync model (new in v2)

```text
local-first writes, background sync
last-write-wins per field for preferences
corrections are append-only events (no conflicts possible)
graph bundles and taxonomy are versioned; client states its version, server sends deltas
```

---

## 13. Model Strategy

Deployed runtime stack — small and fixed:

```text
document/image enhancement
+ OCR/text detector with handwriting capability
+ region/route classifier (document type, handwriting vs print, marks)
+ one grocery extraction/correction model
+ grocery graph + alias/correction memory + embedding index
+ confidence/review system
```

The five capabilities (OCR correction, parsing, canonical matching, aisle prediction, suggestions) are logical tasks, not five deployed models:

```text
correction + parsing + normalization → one extraction model
canonical matching + suggestions     → graph, aliases, embeddings, history
aisle prediction                     → store/household memory + taxonomy fallback
```

### Local LLM: explicit non-goal (clarified in v2)

The original plan was ambiguous ("avoid if possible" vs. a dedicated Phase 9). Resolved stance:

```text
No local LLM in the core product.
The pipeline must reach quality targets without one.
A downloadable local LLM is a post-v1 experiment behind a flag,
only for: weird handwriting, natural-language expansion, recipe understanding.
If the core scanner needs an LLM to hit its metrics, fix the pipeline instead.
```

This removes a large dependency risk and keeps the app small, fast, private, and offline-capable.

### Distillation

Large LLMs/vision models are teachers during development only:

```text
large model → generate structured labels → train small grocery model → quantize → ship
```

Teacher label example:

```json
{
  "raw_handwriting_ocr": "pnut butr",
  "corrected_name": "Peanut Butter",
  "canonical_item_id": "peanut_butter",
  "aisle_hint": "Spreads",
  "confidence": 0.94
}
```

---

## 14. Localization (new in v2)

The first market is Germany (REWE, Aldi are already in the examples). The plan must say so explicitly:

```text
bilingual vocabulary: German + English items and shorthand
  (Mlch → Milch, Brt → Brot, Khlschrnktabs → ...)
metric-first units (g, kg, ml, l, Stück), € prices, comma decimals
German receipt layouts (REWE, Aldi, Edeka, Lidl formats)
German handwriting conventions (e.g., crossed 7s, ß, umlauts in shorthand)
taxonomy localized: aisle names per language, canonical items language-agnostic
```

Canonical items are language-neutral IDs; display names and aliases are per-language. This makes adding languages later a data problem, not an architecture problem.

---

## 15. Privacy (new in v2)

```text
images and recognition run on-device by default
scan images are never uploaded without explicit opt-in
synced data: graph events, corrections, preferences — not raw images
training-event sharing is opt-in, anonymized, and excludes image data
household data is scoped to the household; no cross-household learning
  except via the aggregated global model pipeline
```

---

## 16. Backend Responsibilities

Sync, training, and distribution — never in the prediction loop:

```text
sync household graph, aliases, corrections, preferences
serve canonical taxonomy + alias table updates (versioned deltas)
serve model and graph bundle updates
receive opt-in training events
optional cloud fallback for hard scans (explicit user action only)
multi-device / multi-user household support
```

APIs:

```text
GET  /grocery/graph?since_version=...
POST /grocery/events
POST /grocery/corrections
POST /grocery/aisle-feedback
POST /grocery/suggestion-feedback
GET  /grocery/models/latest
GET  /grocery/aisles?store_id=...
GET  /grocery/canonical-items/search
```

---

## 17. Flutter Services

```text
ScanPipelineService          (one entry point)
CaptureGuidanceService       (burst, frame selection, live hints)
DocumentEnhancementService
DocumentRoutingService       (type + region + mark classification)
OcrService
GroceryExtractionService
CanonicalItemResolver
GroceryGraphRepository
CorrectionMemoryService      (unified corrections/aliases)
AislePredictionService
SuggestionService
PredictionConfidenceService
ModelRuntimeService
SyncService
```

```dart
final result = await scanPipeline.processImage(image);

class GroceryScanResult {
  final List<GroceryPrediction> items;     // includes mark_status
  final List<GrocerySuggestion> suggestions;
  final List<ReviewWarning> warnings;
}
```

The UI never knows whether a prediction came from an alias, the graph, embeddings, or the model — only structured predictions, confidence, and review actions.

---

## 18. Build Phases (restructured in v2)

Handwriting moves up — it is core scanner capability, not a late add-on. Each phase has an exit criterion.

```text
Phase 1 — Data Foundation
  Graph schema, canonical items, unified corrections table, stores, aisles,
  purchase history, suggestion feedback, scan artifacts.
  Exit: every scan/correction/purchase is recorded in the new schema.

Phase 2 — Scanner v2 (capture + routing)
  Burst capture, live guidance, enhancement, document/region routing,
  mark detection (crossed-out/checked), bounding boxes, editable review screen.
  Exit: clean image strips per row; crossed-out items separated; review usable.

Phase 3 — Extraction & Correction v1
  Rules + shipped alias table + global vocabulary; quantity/unit/price parsing;
  multi-candidate selection; unified correction memory live (corrections stick).
  Exit: a previously corrected item is never asked about again.

Phase 4 — Canonical Graph
  Canonical resolution (milk 1L / whole milk / organic milk are related,
  not identical). Real purchase history begins accumulating.
  Exit: history and aliases resolve to canonical IDs across scans and typing.

Phase 5 — Aisle Intelligence
  Default taxonomy → household → store-specific learning; manual aisle moves
  are remembered; per-store sorting.
  Exit: aisle accuracy beats global taxonomy baseline on household data.

Phase 6 — Suggestions
  Frequency, recency, co-occurrence, staples, missing-from-group;
  every suggestion has a reason; feedback adjusts ranking.
  Exit: suggestion acceptance rate is measured and above floor target.

Phase 7 — Distilled Extraction Model
  Teacher-labeled training data (heavy on handwriting noise, DE+EN);
  train, quantize, ship the small extraction model; replaces Phase-3 rules core.
  Exit: model beats the rules pipeline on the handwriting eval set.

Phase 8 — Grocery Embeddings
  Epicure-style graph embeddings for similarity, substitutes, suggestions,
  canonical matching, aisle inference, recipe-to-shopping.
  Exit: embedding fallback improves unknown-item resolution measurably.

Phase 9 — Continuous Learning & Evaluation
  Permanent eval sets (see §19), metric dashboards, retraining cadence,
  model/graph versioning and rollback.
  Exit: ongoing — quality trends are visible and regressions are caught.

(Local LLM: post-v1 experiment, not a phase.)
```

---

## 19. Evaluation & Metrics

### Eval sets (new in v2)

Build fixed, versioned eval sets before shipping models:

```text
handwritten lists (real, varied writers, DE+EN)
printed lists · receipts (REWE/Aldi/Edeka/Lidl)
low-light / glare / curved-paper photos
crossed-out and checked lists
shorthand-heavy lists
```

Handwriting is evaluated separately from print — never blended into one accuracy number.

### Metrics

North star:

```text
scan-to-confirmed-list time  vs  typing the same list manually
```

Supporting:

```text
handwritten item detection rate · recognition accuracy (handwriting vs print)
correction acceptance rate · corrections per scan · repeat correction rate
% auto-accepted · % low-confidence rows
aisle prediction accuracy · suggestion acceptance/dismissal rate
crossed-out detection accuracy
```

Repeat correction rate is the canary: if users fix the same item twice, the correction memory is broken.

---

## 20. Final Target Experience

```text
User scans a messy handwritten grocery list.

The app detects the paper, cleans the image, routes handwritten rows,
corrects shorthand, maps items to canonical entities, separates crossed-out
items, assigns store-specific aisles, suggests what's missing with reasons,
and shows only the uncertain rows.

The user fixes one or two items.

The system remembers those corrections forever — across devices and
household members.
```

Final stack:

```text
guided capture + enhancement
+ routing (print / handwriting / receipt / marks)
+ layout-aware OCR with handwriting support
+ one distilled grocery extraction model
+ canonical grocery graph + unified correction memory
+ grocery embeddings
+ store-specific aisle learning
+ explainable suggestion engine
+ confidence-gated review UI
(no LLM in the loop)
```

The center of the product is the grocery graph: a living memory of what this household buys, how they write things, where items are found, and what belongs together. A+ handwriting support means the system doesn't merely read handwriting — it learns how this household writes groceries.