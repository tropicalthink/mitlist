# Plan 021: Train and export the Phase 7 grocery OCR classifier (clean canonical label space)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 6c868661..HEAD -- intelligence/ml/phase7_classifier/`
> If `intelligence/ml/phase7_classifier/train.py` changed since this plan was
> written, compare the "Current state" excerpts against the live code before
> proceeding; on a mismatch, treat it as a STOP condition.
>
> **Important environment note**: the training datasets in
> `intelligence/ml/data/` are git-ignored (see `intelligence/.gitignore`:
> `ml/data/*.jsonl`, `ml/data/seed.json`). They exist only in the user's main
> working tree. **Do NOT run this plan in a fresh git clone or an isolated
> worktree** — the data will be missing and training will abort. Run in the
> user's working tree at `/home/whtvrboo/Desktop/dev/mitlist`.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug + ml-training
- **Planned at**: commit `6c868661`, 2026-06-13

## Why this matters

The Phase 7 classifier is the on-device model that maps noisy/handwritten OCR
text (e.g. `pnut butr`, `Erdbr`) to a canonical grocery item. The training
script and all datasets exist, but it has **never been successfully trained**,
and as written it would either crash or produce a badly fragmented model:

1. It reads the OCR field named `raw` from **both** input files. `corrections.jsonl`
   uses `raw_ocr`, not `raw` — so **all 39,412 correction rows are silently
   dropped today** (verified: `load_corpus` yields 0 rows from corrections).
   Corrections are the "corrections stick" learning signal that the whole
   product is built around (plan.md §3, §11) — they must reach training.
2. If you naively fix the field name, the correction labels are free-form and
   filthy: 10,448 distinct `correct_canonical_de` values, of which 9,632 are
   **not** canonical items (e.g. `"tomato"`, `"Apples"`, `"Steak 250g"`,
   `"Bildbearbeitungssoftware"`, `"s"`). Used directly as classifier targets
   they explode the class count from ~3,200 to ~13,000 and add thousands of
   garbage singleton classes.
3. `train_test_split(..., stratify=y)` **raises `ValueError`** the moment any
   class has only one member. Even the clean OCR corpus already has 41 such
   singletons; with raw corrections it would be thousands. This is a guaranteed
   crash.

The fix: constrain the label space to the shipped canonical seed
(`seed.json`, 3,187 canonical `name_de` items), resolve every training row's
label to a canonical item (exact name, else alias table — the seed ships a
54,857-entry alias map), drop rows that don't resolve, and drop residual
singleton classes before the stratified split. This brings the corrections data
in cleanly (~22,887 resolvable rows) and yields a stable ~3,187-class model.

After this plan: `grocery_classifier.tflite` + `grocery_classifier_labels.txt`
exist in `intelligence/ml/models/`, with a recorded top-5 accuracy, ready to
copy into the Flutter app.

## Current state

Files (all paths relative to repo root `/home/whtvrboo/Desktop/dev/mitlist`):

- `intelligence/ml/phase7_classifier/train.py` — trains a char-trigram +
  TF-IDF + dense-head Keras classifier. **Contains the three bugs above.**
- `intelligence/ml/phase7_classifier/export.py` — converts `model.keras` →
  `grocery_classifier.tflite` and writes `grocery_classifier_labels.txt` from
  `label_encoder.pkl`. This file is **correct as-is** and needs no changes.
- `intelligence/ml/data/seed.json` — JSON array of 3,239 canonical items
  (3,187 distinct non-empty `name_de`). Each item:
  ```json
  {"name_de":"Erdbeere","name_en":"Strawberry","name_fr":"Fraise","name_es":"Fresa",
   "category":"produce_fruit","default_unit":"g","default_quantity":500,
   "aliases_de":["erdbeere","erdbr","e.", ...],"aliases_en":[...],"aliases_fr":[...],"aliases_es":[...]}
  ```
- `intelligence/ml/data/ocr_corpus.jsonl` — 269,981 rows. Field shape:
  ```json
  {"item_de":"Erdbeere","item_en":"Strawberry","lang":"DE","raw":"Erdbr",
   "variant_type":"HANDWRITING_SHORTCUT","variant_subtype":"vowel_drop"}
  ```
  OCR text = `raw`; canonical label = `item_de`.
- `intelligence/ml/data/corrections.jsonl` — 39,412 rows. Field shape:
  ```json
  {"id":"EXCT_EN_0801","raw_ocr":"milk","correct_canonical_de":"milk",
   "scenario":"EXACT_MATCH","correction_text":"milk", ...}
  ```
  OCR text = `raw_ocr` (NOT `raw`); canonical label = `correct_canonical_de`.
  Note `correction_text` is sometimes a **list**, not a string — never read it
  as a string without a type check.

The exact bug in `train.py` (lines 18–42, current state):
```python
def load_corpus(paths: list[Path]) -> list[tuple[str, str]]:
    rows = []
    for p in paths:
        ...
        for line in p.read_text(encoding="utf-8").splitlines():
            ...
            obj = json.loads(line)
            raw = obj.get("raw", "").strip().lower()            # <- corrections have no "raw"
            canonical = (obj.get("item_de") or obj.get("correct_canonical_de", "")).strip()
            if raw and canonical:
                rows.append((raw, canonical))
    return rows

def main() -> None:
    rows = load_corpus([DATA_DIR / "ocr_corpus.jsonl", DATA_DIR / "corrections.jsonl"])
    ...
    X_train, X_val, y_train, y_val = train_test_split(
        texts, y, test_size=0.1, random_state=42, stratify=y      # <- crashes on singleton classes
    )
```

Repo convention: this subproject uses `python3` (Debian, no `python`), a venv at
`intelligence/.venv`, and writes model-version metadata to `progress.db` via
`generator.progress.ProgressStore` at the end of training (the existing
`train.py` already does this in a try/except — **keep that block unchanged**).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Activate venv | `source intelligence/.venv/bin/activate` | prompt shows `(.venv)` |
| Install ML deps | `pip install -r intelligence/requirements.txt` | exit 0 (installs tensorflow 2.16.1, scikit-learn, etc. — several minutes) |
| Verify deps | `python3 -c "import tensorflow, sklearn; print('ok')"` | prints `ok` |
| Train | `cd intelligence/ml/phase7_classifier && python3 train.py` | finishes, prints `Top-5 accuracy: 0.xxx`, writes `model.keras` |
| Export | `cd intelligence/ml/phase7_classifier && python3 export.py` | prints `Saved … KB` and `Labels: … classes` |

> The venv currently has **no ML dependencies installed** (verified:
> `import tensorflow` fails). The install step is mandatory, not optional.

## Scope

**In scope** (the only files you may modify):
- `intelligence/ml/phase7_classifier/train.py`
- `intelligence/ml/models/grocery_classifier.tflite` (generated by export.py)
- `intelligence/ml/models/grocery_classifier_labels.txt` (generated by export.py)
- `intelligence/ml/phase7_classifier/best.keras`, `model.keras`,
  `label_encoder.pkl` (generated training artifacts — all git-ignored)
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch):
- `intelligence/ml/phase7_classifier/export.py` — already correct.
- `intelligence/ml/phase8_embeddings/**` — that is plan 022.
- Any file under `intelligence/ml/data/` — the datasets are inputs; never
  edit, regenerate, or "clean" them in place.
- `intelligence/generator/**`, `intelligence/config/**` — the generation
  pipeline is done.
- `intelligence/progress.db` — only written via the existing `ProgressStore`
  call already in `train.py`; do not modify that DB by hand.

## Git workflow

- Branch: `advisor/021-phase7-classifier-training`
- Commit the `train.py` change with a conventional-commit message, e.g.
  `fix(intelligence): canonicalize phase7 labels and include corrections data`.
  Match the repo's existing style (see `git log --oneline -5`: `feat: …`,
  `fix: …`). End the commit body with the Co-Authored-By trailer the repo uses.
- The generated `.tflite`/`.txt`/`.keras`/`.pkl` artifacts: `.keras`/`.pkl` are
  git-ignored. The `models/*.tflite` and `*_labels.txt` are **not** ignored —
  do NOT commit them in this plan; copying models into the app is a separate
  step the user will run (README §4). Leave them in `intelligence/ml/models/`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Install ML dependencies into the existing venv

```bash
source intelligence/.venv/bin/activate
pip install -r intelligence/requirements.txt
python3 -c "import tensorflow, sklearn, numpy; print('ok')"
```

**Verify**: the last command prints `ok`. If `pip install` fails on
`tensorflow==2.16.1` (e.g. unsupported Python version), STOP and report the
Python version (`python3 --version`) and the pip error — do not substitute a
different TF version silently.

### Step 2: Add a canonical label resolver built from `seed.json`

In `train.py`, add a function that loads the seed and returns a resolver that
maps any label string to a canonical `name_de`, or `None` if unresolvable.
Place it above `load_corpus`. Target shape:

```python
def build_label_resolver(seed_path: Path):
    """Map any label/alias string -> canonical name_de, else None.

    Label space = the shipped canonical seed. Resolution order:
      1. exact match against a canonical name_de
      2. case-insensitive match against the alias/name table (all languages)
    """
    seed = json.loads(seed_path.read_text(encoding="utf-8"))
    canon = set()
    alias2canon: dict[str, str] = {}
    for it in seed:
        nd = (it.get("name_de") or "").strip()
        if not nd:
            continue
        canon.add(nd)
        for key in ("name_de", "name_en", "name_fr", "name_es"):
            v = (it.get(key) or "").strip()
            if v:
                alias2canon.setdefault(v.lower(), nd)
        for alist in ("aliases_de", "aliases_en", "aliases_fr", "aliases_es"):
            for a in (it.get(alist) or []):
                a = (a or "").strip().lower()
                if a:
                    alias2canon.setdefault(a, nd)

    def resolve(label: str):
        if not label:
            return None
        label = label.strip()
        if label in canon:
            return label
        return alias2canon.get(label.lower())

    return resolve
```

**Verify** (scratch check, run from `intelligence/ml/phase7_classifier`):
```bash
python3 -c "
from pathlib import Path; import importlib.util, sys
sys.argv=['x']
spec=importlib.util.spec_from_file_location('t','train.py'); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
r=m.build_label_resolver(Path('../data/seed.json'))
print(r('Erdbeere'), r('erdbr'), r('strawberry'), r('Bildbearbeitungssoftware'))
"
```
Expected: first three print a canonical German item (e.g. `Erdbeere Erdbeere Erdbeere`),
the last prints `None`.

### Step 3: Rewrite `load_corpus` to use correct fields + the resolver

Replace `load_corpus` so it (a) reads the correct OCR field per file, (b)
resolves every label to canonical, (c) drops unresolvable rows and counts them.
Target shape:

```python
def load_corpus(specs: list[tuple[Path, str, str]], resolve) -> list[tuple[str, str]]:
    """specs: (path, ocr_field, label_field). Returns (text, canonical) rows."""
    rows = []
    for p, ocr_field, label_field in specs:
        if not p.exists():
            print(f"Skipping missing {p}")
            continue
        kept = dropped = 0
        for line in p.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            obj = json.loads(line)
            raw = obj.get(ocr_field)
            raw = raw.strip().lower() if isinstance(raw, str) else ""
            label = obj.get(label_field)
            label = label.strip() if isinstance(label, str) else ""
            canon = resolve(label) if (raw and label) else None
            if raw and canon:
                rows.append((raw, canon)); kept += 1
            else:
                dropped += 1
        print(f"{p.name}: kept {kept}, dropped {dropped}")
    return rows
```

And update `main()` to call it with explicit field names:
```python
    resolve = build_label_resolver(DATA_DIR / "seed.json")
    rows = load_corpus(
        [
            (DATA_DIR / "ocr_corpus.jsonl", "raw", "item_de"),
            (DATA_DIR / "corrections.jsonl", "raw_ocr", "correct_canonical_de"),
        ],
        resolve,
    )
```

**Verify**: not yet — combined with Step 4.

### Step 4: Drop singleton classes before the stratified split

After `texts`/`labels` are built and **before** `LabelEncoder`, remove any class
with fewer than 2 examples so `stratify` cannot crash. Target shape (insert
right after `rows = load_corpus(...)`):

```python
    from collections import Counter
    counts = Counter(lbl for _, lbl in rows)
    rows = [(t, lbl) for (t, lbl) in rows if counts[lbl] >= 2]
    dropped_singletons = sum(1 for c in counts.values() if c < 2)
    print(f"Dropped {dropped_singletons} singleton classes; {len(rows)} rows remain")

    texts = [r[0] for r in rows]
    labels = [r[1] for r in rows]
```

Leave the existing `stratify=y` split, `LabelEncoder`, model definition,
training loop, accuracy print, `model.save`, and the `ProgressStore` metadata
block **unchanged**.

**Verify**: run training (Step 5). It must reach the split without a
`ValueError`.

### Step 5: Train

```bash
cd intelligence/ml/phase7_classifier
python3 train.py
```

**Verify**, ALL must hold in the output:
- A line like `ocr_corpus.jsonl: kept 26xxxx, dropped <small>` — kept should be
  ≳ 268,000 (nearly all OCR rows resolve).
- A line `corrections.jsonl: kept 2xxxx, dropped 1xxxx` — kept should be in the
  ~20,000–23,000 range (the corrections data is now reaching training; if kept
  is `0`, the field-name fix did not take — STOP).
- A line `N canonical classes` where **N is between ~3,000 and ~3,300** (NOT
  ~10,000+ — if it is, the resolver is not being applied — STOP).
- Training completes and prints `Top-1 accuracy:` and `Top-5 accuracy:`.
- Files `best.keras`, `model.keras`, `label_encoder.pkl` now exist in the
  directory (`ls -la *.keras label_encoder.pkl`).

Record the printed Top-5 accuracy — you will report it. Target from README is
**top-5 ≥ 0.85**. If top-5 < 0.70, do NOT keep tuning; STOP and report the
number and the class count (the data or label space may need revisiting — out
of scope for this plan).

### Step 6: Export to TFLite

```bash
cd intelligence/ml/phase7_classifier
python3 export.py
```

**Verify**:
- Prints `Saved <N> KB → .../grocery_classifier.tflite`.
- Prints `Labels: <N> classes → .../grocery_classifier_labels.txt`, where the
  class count matches Step 5's `N canonical classes`.
- `ls -la ../models/grocery_classifier.tflite ../models/grocery_classifier_labels.txt`
  shows both files exist and the `.tflite` is non-empty.

## Test plan

This subproject has no unit-test harness; verification is the training run
itself plus these post-hoc checks. After Step 6, run this sanity check that the
exported label file is clean canonical items (no garbage, no quantities):

```bash
cd intelligence/ml/phase7_classifier
wc -l ../models/grocery_classifier_labels.txt          # ~3,000–3,300 lines
grep -nE '^(s|[0-9])|[0-9]{2,}g|software' ../models/grocery_classifier_labels.txt || echo "clean"
```
Expected: the line count matches the class count from Step 5, and the grep
prints `clean` (no single-letter, numeric-leading, "…500g", or "software"
labels leaked through). If the grep finds matches, the resolver let garbage
through — STOP and report the matches.

## Done criteria

ALL must hold:

- [ ] `python3 -c "import tensorflow, sklearn; print('ok')"` prints `ok`
- [ ] `python3 train.py` runs to completion with no `ValueError`, reports a
      Top-5 accuracy, and shows `corrections.jsonl: kept` > 0
- [ ] Reported `N canonical classes` is between ~3,000 and ~3,300
- [ ] `intelligence/ml/models/grocery_classifier.tflite` exists and is non-empty
- [ ] `intelligence/ml/models/grocery_classifier_labels.txt` exists with a line
      count equal to the class count, and the cleanliness grep prints `clean`
- [ ] Only files in the In-scope list were modified (`git status` —
      `train.py` is the only tracked source change)
- [ ] `plans/README.md` status row for 021 updated with the achieved top-5 accuracy

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows `train.py` already differs from the "Current state"
  excerpts.
- `corrections.jsonl: kept` is `0` after Step 5 (field-name fix didn't apply).
- `N canonical classes` is > ~3,500 (resolver not applied) or < ~2,500
  (resolver dropping too much — likely `seed.json` not found at
  `DATA_DIR / "seed.json"`).
- `pip install` cannot install `tensorflow==2.16.1` on this machine.
- Top-5 accuracy < 0.70 after a clean run (report number + class count; do not
  start tuning hyperparameters — that's a separate effort).
- Any step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

For whoever owns this next:

- The label space is pinned to `seed.json`. If the seed is regenerated with new
  items, retrain — the classifier cannot predict a canonical it never saw, and
  `grocery_classifier_labels.txt` must stay in lockstep with the seed used at
  train time.
- Corrections data now flows into training. As real user corrections accumulate
  (plan.md §11 unified correction memory), this is the file that grows; the
  resolver will silently drop any correction whose target isn't yet a canonical
  item — that drop count in the training log is a useful signal that the seed
  taxonomy is missing items users actually buy.
- The `raw`/`raw_ocr` field divergence is a data-contract smell. If the
  generator is ever revisited, unifying the OCR field name across both files
  would remove the per-file `ocr_field` argument added here.
- Reviewer should scrutinize: the resolver's alias precedence (`setdefault`
  means first-writer-wins; a string that is an alias of two items maps to
  whichever seed item appears first) and the singleton-drop count (a large
  count means the label space is noisier than expected).
- Export path note: `export.py` uses `tf.lite.Optimize.DEFAULT` (dynamic-range
  quantization). If on-device accuracy regresses vs. the Keras model, the
  quantization is the first suspect.
