#!/usr/bin/env python3
"""Enrich the canonical grocery seed with Open Food Facts (OFF) aliases.

Attribution: This script uses data from Open Food Facts (https://world.openfoodfacts.org),
licensed under the Open Database License (ODbL) v1.0.
See: https://openfoodfacts.github.io/openfoodfacts-server/api/
ODbL requires: (1) Attribute OFF when distributing derived data.
               (2) Keep derived index separable from the canonical seed.

The OFF-derived aliases live ONLY in data/off_aliases.json (separable),
NOT embedded in the seed_enriched.json output (which extends aliases_* inline
for convenience but keeps the raw OFF data side-by-side).

Inputs (maintainer-provided):
  data/seed.json                         — canonical items (4-language array)
  data/off_products.jsonl                — OFF dump, one product JSON per line
                                           (fields: product_name, product_name_de,
                                            product_name_en, product_name_fr,
                                            product_name_es, categories_tags, lang)

Outputs (written by this script):
  data/seed_enriched.json               — same shape as seed.json, extended aliases_*
  data/embedder_vocab.txt               — one token/phrase per line (custom vocab)
  data/off_aliases.json                 — ODbL-separable: {item_id: {de:[..], en:[..], ..}}

Usage (maintainer, needs OFF dump):
  python3 intelligence/ml/off_enrich_seed.py \
      [--off data/off_products.jsonl] \
      [--out-seed data/seed_enriched.json] \
      [--out-vocab data/embedder_vocab.txt] \
      [--out-off-aliases data/off_aliases.json]
"""
import argparse
import json
import re
import pathlib
import unicodedata
from collections import defaultdict

HERE = pathlib.Path(__file__).resolve().parent
DATA = HERE / "data"

# ── Attribution / ODbL header written into off_aliases.json ──────────────────
OFF_ATTRIBUTION = (
    "Data source: Open Food Facts (https://world.openfoodfacts.org), "
    "licensed under the Open Database License (ODbL) v1.0 "
    "(https://opendatacommons.org/licenses/odbl/). "
    "This derived index is kept separable from the canonical seed "
    "per ODbL share-alike requirements."
)

LANGUAGES = ["de", "en", "fr", "es"]

# ── Category mapping: canonical seed categories → plausible OFF category tags ─
# OFF uses hierarchical tags like "en:plant-based-foods", "en:milks", etc.
# Broad prefix matches are used so the list doesn't need to be exhaustive.
CATEGORY_TO_OFF_PREFIXES: dict[str, list[str]] = {
    "produce_fruit":           ["en:fruits", "en:fresh-fruits", "en:tropical-fruits"],
    "produce_vegetable":       ["en:vegetables", "en:fresh-vegetables", "en:root-vegetables"],
    "produce_herb":            ["en:herbs", "en:aromatic-herbs", "en:fresh-herbs"],
    "dairy_milk":              ["en:milks", "en:plant-based-milks", "en:cow-milk"],
    "dairy_cheese":            ["en:cheeses", "en:soft-cheeses", "en:hard-cheeses"],
    "dairy_cream":             ["en:creams", "en:sour-creams"],
    "dairy_fermented":         ["en:fermented-foods", "en:yogurts", "en:kefir"],
    "eggs":                    ["en:eggs", "en:hen-eggs"],
    "meat_beef":               ["en:beef", "en:red-meats"],
    "meat_pork":               ["en:pork", "en:charcuterie"],
    "meat_poultry":            ["en:poultry", "en:chicken", "en:turkey"],
    "meat_lamb":               ["en:lamb-and-mutton", "en:lamb"],
    "deli":                    ["en:deli-meats", "en:cold-cuts"],
    "seafood":                 ["en:seafood", "en:fish", "en:shellfish"],
    "bakery_bread":            ["en:breads", "en:whole-wheat-breads", "en:sourdough-breads"],
    "bakery_pastry":           ["en:pastries", "en:cookies", "en:cakes"],
    "frozen":                  ["en:frozen-foods", "en:frozen-vegetables"],
    "snacks":                  ["en:snacks", "en:chips-and-fries", "en:crackers"],
    "spreads_sweet":           ["en:spreads", "en:jams-and-marmalades", "en:honey"],
    "spreads_savory":          ["en:spreads", "en:nut-butters"],
    "beverages_soft":          ["en:soft-drinks", "en:juices", "en:waters"],
    "beverages_alcohol":       ["en:alcoholic-beverages", "en:beers", "en:wines"],
    "beverages_hot":           ["en:hot-beverages", "en:teas", "en:coffees"],
    "pasta_grain":             ["en:pastas", "en:rices", "en:grains"],
    "pasta_noodle":            ["en:noodles", "en:asian-noodles"],
    "baking":                  ["en:flours", "en:baking-preparations", "en:sugars"],
    "canned_vegetable":        ["en:canned-vegetables", "en:canned-tomatoes"],
    "canned_legume":           ["en:canned-legumes", "en:canned-beans"],
    "canned_fish":             ["en:canned-fish", "en:canned-tuna"],
    "condiments_sauce":        ["en:sauces", "en:ketchup", "en:mustards"],
    "condiments_oil_vinegar":  ["en:oils", "en:vinegars", "en:olive-oils"],
    "international_mexican":   ["en:mexican-cuisine"],
    "international_asian":     ["en:asian-cuisine", "en:japanese-foods"],
    "international_mediterranean": ["en:mediterranean-cuisine"],
    "health_supplement":       ["en:dietary-supplements", "en:protein-supplements"],
    "personal_care":           [],
    "cleaning":                [],
    "baby":                    ["en:baby-foods"],
    "pet":                     [],
    "flowers_plant":           [],
}


def _normalise(s: str) -> str:
    """Lowercase, strip accents, collapse whitespace."""
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"\s+", " ", s).strip()


def _tokens(text: str) -> list[str]:
    """Tokenise into lowercase words (2+ chars), stripping punctuation."""
    text = text.lower()
    return [t for t in re.findall(r"[a-zäöüß]{2,}", text)]


def _load_seed(path: pathlib.Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))


def _build_category_index(seed: list[dict]) -> dict[str, list[dict]]:
    """Map category → list of canonical items."""
    idx: dict[str, list[dict]] = defaultdict(list)
    for item in seed:
        idx[item.get("category", "")].append(item)
    return idx


def _item_key(item: dict) -> str:
    """Derive a stable key (same logic as build_app_seed.py slugify on name_en/de)."""
    name = item.get("name_en") or item.get("name_de") or ""
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower()
    return s or "item"


def _name_similarity(name_a: str, name_b: str) -> float:
    """Jaccard similarity on word tokens — cheap approximate match."""
    ta = set(_tokens(name_a))
    tb = set(_tokens(name_b))
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def _mine_off_names(
    off_path: pathlib.Path,
    category_to_prefixes: dict[str, list[str]],
    seed: list[dict],
    max_aliases_per_item: int = 10,
    min_similarity: float = 0.25,
) -> dict[str, dict[str, list[str]]]:
    """Scan the OFF dump and collect product names for each canonical item.

    Returns: {item_key: {lang: [alias, ...]}}
    """
    if not off_path.exists():
        print(f"[off_enrich] OFF dump not found at {off_path} — skipping mining.")
        return {}

    # Build per-category list of (item_key, item) pairs with their OFF prefixes
    cat_items: dict[str, list[tuple[str, dict]]] = defaultdict(list)
    for item in seed:
        cat = item.get("category", "")
        cat_items[cat].append((_item_key(item), item))

    # Build reverse map: off_prefix → list of (item_key, item)
    prefix_items: dict[str, list[tuple[str, dict]]] = defaultdict(list)
    for cat, items in cat_items.items():
        for pfx in category_to_prefixes.get(cat, []):
            prefix_items[pfx].extend(items)

    result: dict[str, dict[str, list[str]]] = defaultdict(lambda: defaultdict(list))
    line_count = 0

    with off_path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            line_count += 1
            try:
                prod = json.loads(line)
            except json.JSONDecodeError:
                continue

            cat_tags: list[str] = prod.get("categories_tags", [])

            # Find which canonical categories this product belongs to
            matched_prefixes: set[str] = set()
            for tag in cat_tags:
                for pfx in prefix_items:
                    if tag.startswith(pfx):
                        matched_prefixes.add(pfx)

            if not matched_prefixes:
                continue

            # Collect product names per language
            prod_names: dict[str, str] = {}
            for lang in LANGUAGES:
                name_field = f"product_name_{lang}" if lang != "en" else "product_name"
                val = prod.get(name_field) or prod.get(f"product_name_{lang}", "")
                if val and len(val) > 1:
                    prod_names[lang] = val.strip()
            # Also try generic product_name with prod lang
            generic = prod.get("product_name", "")
            prod_lang = prod.get("lang", "")
            if generic and prod_lang in LANGUAGES and prod_lang not in prod_names:
                prod_names[prod_lang] = generic.strip()

            if not prod_names:
                continue

            # Match against candidate canonical items
            for pfx in matched_prefixes:
                for item_key, item in prefix_items[pfx]:
                    for lang, pname in prod_names.items():
                        # Check similarity against canonical name in this lang
                        canon_name = item.get(f"name_{lang}", "")
                        if not canon_name:
                            continue
                        if _name_similarity(pname, canon_name) < min_similarity:
                            continue
                        existing = result[item_key][lang]
                        norm = _normalise(pname)
                        if norm and norm not in existing:
                            if len(existing) < max_aliases_per_item:
                                existing.append(norm)

    print(f"[off_enrich] Scanned {line_count} OFF products.")
    return {k: dict(v) for k, v in result.items()}


def _build_vocab(seed: list[dict], off_aliases: dict[str, dict[str, list[str]]]) -> list[str]:
    """Collect word- and phrase-level tokens from canonical item NAMES only.

    Scope = item names across all languages (Strategy A). Aliases and OFF
    strings are intentionally EXCLUDED from the shipped embedder vocab: adding
    them balloons the on-device ``embedder_vocab.json`` to ~45-90 MB, while the
    catalog vectors are built from item names and real queries are name-like,
    so name-derived vocab covers the actual lookups. OOV query words fall back
    to char-trigrams in the Dart runtime (StaticEmbeddingService.tokenize).

    Aliases still drive ``seed_enriched.json`` / ``off_aliases.json`` — this
    narrowing affects only the embedder vocab. ``off_aliases`` is accepted for
    signature stability but no longer contributes vocab tokens.
    """
    phrase_set: set[str] = set()
    word_set: set[str] = set()

    def _add(text: str) -> None:
        norm = text.lower().strip()
        if norm:
            phrase_set.add(norm)
            for w in _tokens(norm):
                word_set.add(w)

    for item in seed:
        for lang in LANGUAGES:
            _add(item.get(f"name_{lang}", ""))

    # Phrases first (longer/more specific), then single words
    phrases = sorted(p for p in phrase_set if " " in p)
    words = sorted(word_set)
    # Combine, de-duplicating (words may already appear in phrase set)
    seen: set[str] = set()
    vocab: list[str] = []
    for tok in phrases + words:
        if tok not in seen:
            seen.add(tok)
            vocab.append(tok)
    return vocab


def _enrich_seed(seed: list[dict], off_aliases: dict[str, dict[str, list[str]]]) -> list[dict]:
    """Return a copy of seed with OFF aliases merged into aliases_*."""
    out = []
    seen_keys: dict[str, int] = {}  # handle duplicate keys

    for item in seed:
        key = _item_key(item)
        # Handle collisions (same logic as build_app_seed.py)
        if key in seen_keys:
            seen_keys[key] += 1
            key = f"{key}_{seen_keys[key]}"
        else:
            seen_keys[key] = 1

        enriched = dict(item)
        lang_aliases = off_aliases.get(key, {})
        for lang in LANGUAGES:
            existing = set(enriched.get(f"aliases_{lang}", []))
            extra = [a for a in lang_aliases.get(lang, []) if a not in existing]
            enriched[f"aliases_{lang}"] = list(enriched.get(f"aliases_{lang}", [])) + extra
        out.append(enriched)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--off", default=str(DATA / "off_products.jsonl"),
                    help="Path to OFF JSONL dump (one product per line)")
    ap.add_argument("--out-seed", default=str(DATA / "seed_enriched.json"),
                    help="Output: enriched seed (same shape as seed.json)")
    ap.add_argument("--out-vocab", default=str(DATA / "embedder_vocab.txt"),
                    help="Output: custom vocab for Model2Vec distillation")
    ap.add_argument("--out-off-aliases", default=str(DATA / "off_aliases.json"),
                    help="Output: ODbL-separable raw OFF alias mapping")
    args = ap.parse_args()

    seed_path = DATA / "seed.json"
    off_path = pathlib.Path(args.off)
    out_seed = pathlib.Path(args.out_seed)
    out_vocab = pathlib.Path(args.out_vocab)
    out_off = pathlib.Path(args.out_off_aliases)

    print(f"[off_enrich] Loading seed from {seed_path}")
    seed = _load_seed(seed_path)
    print(f"[off_enrich] {len(seed)} canonical items loaded.")

    print(f"[off_enrich] Mining OFF aliases from {off_path}")
    off_aliases = _mine_off_names(off_path, CATEGORY_TO_OFF_PREFIXES, seed)

    total_off = sum(len(v) for d in off_aliases.values() for v in d.values())
    print(f"[off_enrich] {total_off} OFF alias strings collected across {len(off_aliases)} items.")

    enriched = _enrich_seed(seed, off_aliases)
    out_seed.write_text(json.dumps(enriched, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"[off_enrich] Enriched seed written → {out_seed}")

    # ODbL-separable OFF aliases file
    off_payload = {
        "_attribution": OFF_ATTRIBUTION,
        "_license": "ODbL-1.0",
        "items": off_aliases,
    }
    out_off.write_text(json.dumps(off_payload, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"[off_enrich] OFF alias mapping (ODbL-separable) written → {out_off}")

    vocab = _build_vocab(enriched, off_aliases)
    out_vocab.write_text("\n".join(vocab), encoding="utf-8")
    print(f"[off_enrich] Vocab written → {out_vocab} ({len(vocab)} tokens)")


if __name__ == "__main__":
    main()
