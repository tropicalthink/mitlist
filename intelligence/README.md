# mitlist intelligence

DeepSeek-powered training data generation + on-device ML models for grocery OCR resolution.

## Quick start

```bash
cd intelligence
python3 -m venv .venv && source .venv/bin/activate
pip install openai pyyaml python-dotenv tqdm   # generation only
cp .env.example .env                            # add your DEEPSEEK_API_KEY
```

> **Debian/Ubuntu:** there's no `python` command — use `python3`, or the `./run.sh` wrapper.
> If venv creation fails, run `sudo apt install python3-venv python3-pip` first.

Get an API key at [platform.deepseek.com](https://platform.deepseek.com/api_keys).

## Calibration eval

Run the grocery resolution calibration loop with one command:

```bash
./eval.sh
```

The script re-exports Dart parity features through
`frontend/test/services/resolution_feature_export_test.dart`, then fits and
reports the calibrated scorer from `ml/eval/resolution_eval.py`.

To attempt shipping a fitted bundle:

```bash
./eval.sh --ship
```

Shipping writes `frontend/assets/grocery/resolution_weights.json` only when the
fitted holdout `precision@auto` and `coverage@auto` both meet or beat the
hand-set defaults. If no bundle ships, the app still falls back to the
hand-set `CalibratedScorer` defaults.

## 1. Generate training data

### Estimate cost first

```bash
python3 -m generator.runner estimate   # or: ./run.sh estimate
```

Rough total: **~$15–40** for all 170k rows (depends on output length and model).

### Run batches (recommended order)

```bash
# Terminal 1 — dashboard
python3 -m generator.runner dashboard
# → http://127.0.0.1:8765

# Terminal 2 — generation (start small, scale up)
python3 -m generator.runner run --prompt 1 --category produce_fruit --temp 0.9
python3 -m generator.runner run --prompt 1 --all          # all 40 categories × 3 temps
python3 -m generator.runner run --prompt 2 --all          # needs seed.json first
python3 -m generator.runner run --prompt 5 --all          # corrections (for Phase 7)
python3 -m generator.runner run --prompt 3 --all          # triplets (for Phase 8)
python3 -m generator.runner run --prompt 4 --all          # store aisles (optional)
```

### CLI reference

| Command | Description |
|---------|-------------|
| `run --prompt N --all` | Run every batch for prompt N |
| `run --prompt 1 --category dairy_milk` | Single category (Prompt 1) |
| `run --prompt 2 --batch DE_group_0` | Single batch by key |
| `run --prompt 1 --all --force` | Re-run completed batches |
| `status` | Terminal summary |
| `dashboard` | Web UI at :8765 |
| `estimate` | Cost estimate |

### Output files

| Prompt | File | ~Rows |
|--------|------|-------|
| 1 Canonical seed | `ml/data/seed.json` | ~3,200 items (v5, DE/EN/FR/ES) |
| 2 OCR noise | `ml/data/ocr_corpus.jsonl` | ~144,000 (5 items × 20 variants × langs) |
| 3 Triplets | `ml/data/triplets.jsonl` | ~8,000 |
| 4 Store aisles | `ml/data/aisles.jsonl` | ~9,600 |
| 5 Corrections | `ml/data/corrections.jsonl` | ~32,000 |

Progress, token usage, and cost are tracked in `progress.db` (SQLite).

## 2. Dashboard (with run controls)

```bash
python3 -m generator.runner dashboard
# → http://127.0.0.1:8765
```

Everything is controllable from the browser — no need for a second terminal.

**Run controls:**
- **Start** — pick prompt, mode (pending / all / single category / single batch), temperature, force
- **Stop** — cancels after the current batch finishes
- **Run pipeline** — queues P1 → P2 → P5 → P3 → P4 (pending batches only)
- **Per-prompt buttons** — "Run pending" / "Run all" on each progress bar

**Live status:**
- Job indicator in header (idle / running / done / cancelled)
- Progress bar + log tail for the active job
- Auto-refreshes every 2s while a job is running

**API endpoints** (if you want to script it):
```bash
curl -X POST http://127.0.0.1:8765/api/job/start \
  -H 'Content-Type: application/json' \
  -d '{"prompt": 1, "mode": "pending"}'

curl -X POST http://127.0.0.1:8765/api/job/pipeline
curl -X POST http://127.0.0.1:8765/api/job/stop
curl http://127.0.0.1:8765/api/job
curl http://127.0.0.1:8765/api/stats
```

## 3. Train models

Install full ML deps:

```bash
pip install -r requirements.txt
```

### Phase 7 — OCR classifier (train first)

Needs Prompt 2 + 5 data. Fast (~minutes).

```bash
cd ml/phase7_classifier
python train.py          # → best.keras, label_encoder.pkl
python export.py         # → ../models/grocery_classifier.tflite
```

Target: **top-5 accuracy ≥ 85%**.

CI runs `python3 intelligence/ml/check_classifier_parity.py` to verify that
classifier labels still resolve against the shipped grocery seed. If that gate
fails after a seed rebuild, retrain and export the classifier, copy the updated
classifier assets from §4 into `frontend/assets/models/`, then re-run the
checker. A future retrain should emit canonical ids as labels instead of display
names so seed renames cannot orphan classifier predictions.

### Phase 8 — embedding teacher (train second)

Needs Prompt 3 triplets. Slower (~hours).

```bash
cd ml/phase8_embeddings
python train.py          # → finetuned/ teacher model
```

Phase 8 is a build-time teacher only. The Flutter app does not load a TFLite
embedder. `ml/build_embedder_bundle.py` distills the local `finetuned/` teacher
or the public e5 fallback through Model2Vec into static JSON assets consumed by
`StaticEmbeddingService`.

## 4. App assets

| Script | Inputs | Outputs | Version to bump |
|--------|--------|---------|-----------------|
| `ml/build_app_seed.py` | `ml/data/seed.json`, `curated_aliases.jsonl`, `curated_aliases_mined.jsonl`, `alias_blocklist.jsonl` | `frontend/assets/grocery/seed.json`, `seed.version.json`, `autocomplete.json` | `ASSET_VERSION` in `build_app_seed.py` |
| `ml/build_embedder_bundle.py` | `ml/data/embedder_vocab.txt`, `frontend/assets/grocery/seed.json`, optional `ml/phase8_embeddings/finetuned/` | `frontend/assets/grocery/embedder_vocab.json`, `catalog_vectors.json`, `embedder_golden.json` | `ASSET_VERSION` in `build_embedder_bundle.py` |
| `ml/build_store_aisles.py` | `ml/data/aisles.jsonl`, `frontend/assets/grocery/seed.json` | `frontend/assets/grocery/store_aisles.json` | `ASSET_VERSION` in `build_store_aisles.py` |
| `ml/off_ground.py` | Open Food Facts source data | grounded OFF intermediate data under `ml/data/` | n/a |
| `ml/off_enrich_seed.py` | grounded OFF data + app seed | `frontend/assets/grocery/off_aliases.json` | script-local asset version if changed |
| `ml/mine_corrections_aliases.py` | `ml/data/corrections.jsonl`, seed aliases | `ml/data/corrections_alias_candidates.jsonl` for human review | n/a |

Copy only the classifier export artifacts into the Flutter model bundle:

```bash
cp ml/models/grocery_classifier.tflite ../frontend/assets/models/
cp ml/models/grocery_classifier_labels.txt ../frontend/assets/models/
cp ml/models/grocery_classifier_metadata.json ../frontend/assets/models/
```

`CanonicalResolverService` combines aliases, classifier predictions, the static
embedding JSON bundle, correction memory, and calibrated weights. See AGENTS.md
scanner section.

### Curation files

- `curated_aliases.jsonl` adds reviewed brand/staple aliases to canonical ids.
- `curated_aliases_mined.jsonl` contains reviewed typo-like corrections promoted from mined data.
- `alias_blocklist.jsonl` prevents known-bad alias→canonical mappings.
- `corrections_alias_candidates.jsonl` and related `mine_corrections_aliases.py` outputs are review queues, not auto-merged assets.

## Architecture

```
intelligence/
├── config/
│   ├── batches.yaml      # all batch definitions + model version metadata
│   └── pricing.yaml      # DeepSeek token pricing for cost calc
├── prompts/              # 5 prompt templates with {VARIABLE} placeholders
├── generator/
│   ├── deepseek_client.py  # OpenAI-compatible API client
│   ├── runner.py           # CLI batch orchestrator
│   ├── progress.py         # SQLite progress + cost tracking
│   ├── parsers.py          # JSON/JSONL validation
│   └── dashboard_server.py # serves dashboard + /api/stats
├── dashboard/            # HTML progress UI
└── ml/
    ├── data/             # generated datasets
    ├── phase7_classifier/
    ├── phase8_embeddings/ # build-time embedding teacher
    └── models/           # classifier export artifacts
```

## DeepSeek API notes

- Uses OpenAI SDK with `base_url=https://api.deepseek.com`
- Default model: `deepseek-chat` (fast, cheap — good for structured JSON)
- For harder batches (Prompt 4 aisles), try `deepseek-reasoner` in `.env`
- Temperature 0.9–1.0 for variation; Prompt 1 runs 3 temps by default
- Failed batches save to `debug/` and are resumable — re-run without `--force` skips completed

## Recommended workflow

1. **Prompt 1** — one category to validate JSON parsing
2. **Prompt 1 --all** — full seed (~$2–5)
3. **Prompt 2 + 5** — OCR + corrections for Phase 7 (~$8–15)
4. **Train Phase 7** — check top-5 accuracy
5. **Prompt 3** — triplets for Phase 8 (~$3–5)
6. **Train Phase 8** — export embeddings
7. **Prompt 4** — store aisles (optional, for aisle intelligence)
