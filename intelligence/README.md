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
| 1 Canonical seed | `ml/data/seed.json` | ~1,800 items (40 cat × 3 chunks × 15 items) |
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

### Phase 8 — Embedding model (train second)

Needs Prompt 3 triplets. Slower (~hours).

```bash
cd ml/phase8_embeddings
python train.py          # → finetuned/
python export.py         # → ../models/grocery_embeddings.tflite
```

## 4. Flutter integration

Copy exported models to the Flutter app:

```bash
cp ml/models/grocery_classifier.tflite ../frontend/assets/models/
cp ml/models/grocery_classifier_labels.txt ../frontend/assets/models/
cp ml/models/grocery_embeddings.tflite ../frontend/assets/models/
```

Wire into `CanonicalResolverService` — when alias lookup score < 0.85, fall back to the classifier. See AGENTS.md scanner section.

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
    ├── phase8_embeddings/
    └── models/           # exported .tflite files
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
