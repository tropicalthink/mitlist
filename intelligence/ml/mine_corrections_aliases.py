#!/usr/bin/env python3
"""A4 — corrections → alias miner.

Reads corrections.jsonl (39,412 real OCR-correction rows) and maps
`correct_canonical_{en,de}` display names to existing seed canonical IDs.

The corrections file contains rows like:
  {"raw_ocr": "Mozz", "correct_canonical_en": "Mozzarella", ...}

`correct_canonical_en` is a DISPLAY NAME ("Mozzarella"), NOT a seed id ("mozzarella").
This miner builds a display-name → id index from seed.json and then:
  1. For each correction row, finds the seed id for the canonical display name.
  2. Normalises the raw_ocr text (lowercase, trim, collapse-space).
  3. Emits a candidate alias row if:
       - The display name maps to a seed id.
       - The raw_ocr is not already in the item's current alias list.
       - The raw_ocr is at least 2 chars and does not look like noise
         (all digits, single char, or contains null bytes).

Output: intelligence/ml/data/corrections_alias_candidates.jsonl
Format: same as curated_aliases.jsonl (one JSON per line):
  {"canonical_id":"mozzarella","alias":"mozz","lang":"en","source":"corrections_miner"}

Do NOT auto-merge — output is for human review before merging into curated_aliases.jsonl.

Usage:
    cd intelligence && python3 ml/mine_corrections_aliases.py
"""
import json, re, unicodedata, collections, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
CORRECTIONS = HERE / "data" / "corrections.jsonl"
SEED = HERE.parent.parent / "frontend" / "assets" / "grocery" / "seed.json"
OUT = HERE / "data" / "corrections_alias_candidates.jsonl"

# ── helpers ──────────────────────────────────────────────────────────────────

def normalise(s: str) -> str:
    """Lowercase, strip, collapse internal whitespace."""
    if not s:
        return ""
    return re.sub(r"\s+", " ", s.strip().lower())


def _looks_noisy(s: str) -> bool:
    """True for tokens that should NOT be promoted as aliases."""
    if len(s) < 2:
        return True
    if s.isdigit():
        return True
    # All punctuation / special chars (but allow letters, digits, spaces, hyphens,
    # apostrophes, umlauts, accents — anything a human might actually type)
    if re.match(r"^[\W\d]+$", s, re.UNICODE):
        return True
    # Quantity-only strings like "2 kg", "500g" — these are measurements not item names
    if re.match(r"^\d+\s*(g|kg|ml|l|st|pcs?|stück|stk|x)\b", s, re.IGNORECASE):
        return True
    return False


def slugify(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower()
    return s or "item"


# ── build seed index ──────────────────────────────────────────────────────────

print(f"Loading seed from {SEED} …")
seed_data = json.loads(SEED.read_text(encoding="utf-8"))
seed_items = seed_data["items"]

# Index: normalised display name → set of canonical ids that use that name.
# A display name may collide (e.g. "Milk" in en and de can be the same item
# or different items); we keep all candidates and will pick the best.
name_to_ids: dict[str, list[str]] = collections.defaultdict(list)

# Per-item: existing alias set (for dedup)
item_aliases: dict[str, set[str]] = {}

for item in seed_items:
    iid = item["id"]
    # Collect all four display names
    for field in ("name_en", "name_de", "name_fr", "name_es"):
        n = normalise(item.get(field, "") or "")
        if n:
            name_to_ids[n].append(iid)
    # Collect existing aliases
    existing: set[str] = set()
    for al_field in ("aliases_en", "aliases_de", "aliases_fr", "aliases_es"):
        for a in item.get(al_field, []):
            existing.add(normalise(a))
    item_aliases[iid] = existing

print(f"  Seed: {len(seed_items)} items, {len(name_to_ids)} unique display-name keys")

# Also build a slug index as a fallback: slugify(display_name) → id
slug_to_id: dict[str, str] = {}
for item in seed_items:
    slug_to_id[item["id"]] = item["id"]  # identity
    for field in ("name_en", "name_de"):
        n = item.get(field, "") or ""
        if n:
            s = slugify(n)
            if s not in slug_to_id:
                slug_to_id[s] = item["id"]


def resolve_display_to_id(display_en: str, display_de: str) -> str | None:
    """Try to find a unique seed id for the canonical display names."""
    for display in (normalise(display_en), normalise(display_de)):
        if not display:
            continue
        candidates = name_to_ids.get(display)
        if candidates:
            # Prefer a unique match; if multiple, take the first (alphabetically stable)
            return sorted(set(candidates))[0]
    # Fallback: slug of the en display name
    for display in (display_en, display_de):
        if display:
            s = slugify(display)
            if s in slug_to_id:
                return slug_to_id[s]
    return None


# ── mine corrections ──────────────────────────────────────────────────────────

print(f"Mining {CORRECTIONS} …")

# Statistics
stats = collections.Counter()
skipped_reasons: dict[str, int] = collections.Counter()
candidates: list[dict] = []
seen_pairs: set[tuple[str, str]] = set()  # (canonical_id, alias) dedup

with open(CORRECTIONS, encoding="utf-8") as f:
    for line in f:
        row = json.loads(line)
        stats["total"] += 1

        raw_ocr = normalise(row.get("raw_ocr", "") or "")
        # correct_canonical_{en,de} can be a string or a list (for
        # COMPOUND_SPLIT_MERGE scenarios where one OCR token maps to multiple
        # canonicals). Take the first element if a list; skip multi-canonical rows
        # since we can't safely choose a single canonical_id target.
        _can_en_raw = row.get("correct_canonical_en")
        _can_de_raw = row.get("correct_canonical_de")
        if isinstance(_can_en_raw, list) or isinstance(_can_de_raw, list):
            stats["skip_multi_canonical"] += 1
            continue
        canonical_en = (_can_en_raw or "").strip()
        canonical_de = (_can_de_raw or "").strip()
        lang_hint = (row.get("list_language") or "en").lower()

        # Skip if raw_ocr is empty or noisy
        if not raw_ocr or _looks_noisy(raw_ocr):
            stats["skip_noisy"] += 1
            skipped_reasons[f"noisy:{raw_ocr[:20]}"] += 1
            continue

        # Resolve canonical display name → seed id
        seed_id = resolve_display_to_id(canonical_en, canonical_de)
        if seed_id is None:
            stats["skip_unmappable"] += 1
            continue
        stats["mappable"] += 1

        # Skip if raw_ocr is already in the item's alias set
        existing = item_aliases.get(seed_id, set())
        if raw_ocr in existing:
            stats["skip_already_alias"] += 1
            continue

        # Skip if raw_ocr is identical to the display names themselves
        if raw_ocr in (normalise(canonical_en), normalise(canonical_de)):
            stats["skip_same_as_name"] += 1
            continue

        # Deduplicate
        pair = (seed_id, raw_ocr)
        if pair in seen_pairs:
            stats["skip_dup"] += 1
            continue
        seen_pairs.add(pair)

        # Determine language for the candidate
        # Use list_language as hint; fall back to "und" (undetermined).
        lang = lang_hint if lang_hint in ("en", "de", "fr", "es") else "und"

        candidates.append({
            "canonical_id": seed_id,
            "alias": raw_ocr,
            "lang": lang,
            "source": "corrections_miner",
        })
        stats["emitted"] += 1

# ── write output ──────────────────────────────────────────────────────────────

OUT.write_text(
    "\n".join(json.dumps(c, ensure_ascii=False) for c in candidates) + "\n",
    encoding="utf-8",
)

print(f"\n=== Miner statistics ===")
print(f"  Total rows read         : {stats['total']}")
print(f"  Skipped multi-canonical : {stats['skip_multi_canonical']}")
print(f"  Noisy / short raw_ocr   : {stats['skip_noisy']}")
print(f"  Unmappable canonical    : {stats['skip_unmappable']}")
print(f"  Already an alias        : {stats['skip_already_alias']}")
print(f"  Same as display name    : {stats['skip_same_as_name']}")
print(f"  Duplicate pairs         : {stats['skip_dup']}")
print(f"  Emitted candidates      : {stats['emitted']}")
print(f"\nOutput -> {OUT}")
print(f"NOTE: Review candidates before merging into curated_aliases.jsonl")
print(f"      Do NOT auto-merge — this is a [GATE] requiring human review.")

# Print sample of emitted candidates by scenario breakdown (from the input)
print(f"\nSample of first 20 emitted candidates:")
for c in candidates[:20]:
    print(f"  canonical={c['canonical_id']}, alias={c['alias']!r}, lang={c['lang']}")
