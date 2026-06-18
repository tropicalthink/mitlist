#!/usr/bin/env python3
"""Transform the canonical grocery seed into the Flutter app's bundled asset.

Source: intelligence/ml/data/seed.json   (raw canonical array, 4 languages)
Target: frontend/assets/grocery/seed.json ({version, items:[...]} shape)

The app's GrocerySeedLoader expects each item to have a stable `id`, and reads
name_de/name_en/name_fr/name_es + aliases for all four languages. `category` is
used as the aisle
fallback label, so the 40 fine-grained source categories are mapped down to the
coarse aisle vocabulary the app already uses.

Enrichment pipeline (applied in order):
  1. curated_aliases.jsonl  — brand/staple aliases mapped to existing canonical ids.
  2. alias_blocklist.jsonl  — drop harmful (alias, canonical_id) pairs.
  3. No-space variant aliases — "corn flakes" → also emit "cornflakes" alias and vice-versa.
"""
import json, re, unicodedata, collections, pathlib

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "data" / "seed.json"
DST = HERE.parent.parent / "frontend" / "assets" / "grocery" / "seed.json"
CURATED_ALIASES = HERE / "data" / "curated_aliases.jsonl"
# Mined OCR/typo + fr/es name-variant aliases auto-promoted from corrections
# (plan 012 A4, typo-like subset only; cross-word mappings stay deferred).
CURATED_MINED = HERE / "data" / "curated_aliases_mined.jsonl"
ALIAS_BLOCKLIST = HERE / "data" / "alias_blocklist.jsonl"
ASSET_VERSION = 5

# Fine category -> coarse aisle label (matches existing app vocabulary).
CATEGORY_TO_AISLE = {
    "produce_fruit": "produce", "produce_vegetable": "produce", "produce_herb": "produce",
    "dairy_milk": "dairy", "dairy_cheese": "dairy", "dairy_cream": "dairy",
    "dairy_fermented": "dairy", "eggs": "dairy",
    "meat_beef": "meat", "meat_pork": "meat", "meat_poultry": "meat",
    "meat_lamb": "meat", "deli": "meat",
    "seafood": "fish",
    "bakery_bread": "bakery", "bakery_pastry": "bakery",
    "frozen": "frozen", "snacks": "snacks",
    "spreads_sweet": "spreads", "spreads_savory": "spreads",
    "beverages_soft": "beverages", "beverages_alcohol": "beverages", "beverages_hot": "beverages",
    "pasta_grain": "pantry", "pasta_noodle": "pantry", "baking": "pantry",
    "canned_vegetable": "pantry", "canned_legume": "pantry", "canned_fish": "pantry",
    "condiments_sauce": "pantry", "condiments_oil_vinegar": "pantry",
    "international_mexican": "international", "international_asian": "international",
    "international_mediterranean": "international",
    "health_supplement": "health", "personal_care": "personal care",
    "cleaning": "household", "baby": "baby", "pet": "pet", "flowers_plant": "flowers",
}

def slugify(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower()
    return s or "item"


def load_curated_aliases(path: pathlib.Path) -> dict[str, list[dict]]:
    """Returns {canonical_id: [{alias, lang, source}, ...]}"""
    result: dict[str, list[dict]] = collections.defaultdict(list)
    if not path.exists():
        return result
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        row = json.loads(line)
        cid = row["canonical_id"]
        result[cid].append({"alias": row["alias"], "lang": row["lang"], "source": row.get("source", "curated")})
    return result


def load_blocklist(path: pathlib.Path) -> set[tuple[str, str]]:
    """Returns set of (alias, wrong_canonical_id) pairs to drop."""
    result: set[tuple[str, str]] = set()
    if not path.exists():
        return result
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        row = json.loads(line)
        result.add((row["alias"], row["wrong_canonical_id"]))
    return result


def no_space_variant(alias: str) -> str | None:
    """Emit a joined variant ONLY for genuine 2-word alphabetic compounds a user
    might type as one word (e.g. 'corn flakes' -> 'cornflakes', 'olive oil' ->
    'oliveoil'). FTS5 word-prefix already covers typing a word *inside* a
    multi-word alias; the no-space variant only earns its place for the joined
    spelling of a true compound. Skip phrases (>2 words), quantity-prefixed
    aliases ('500g erdbeere'), short/edge tokens, and long results — generating
    a variant for every spaced alias roughly doubled the on-device alias table."""
    parts = alias.split()
    if len(parts) != 2:
        return None
    a, b = parts
    if len(a) < 3 or len(b) < 3:
        return None
    if not (a.isalpha() and b.isalpha()):
        return None
    variant = a + b
    if len(variant) > 24 or variant == alias:
        return None
    return variant


def merge_aliases_for_item(item: dict, curated: list[dict], blocklist: set[tuple[str, str]]) -> dict:
    """Apply curated additions and blocklist drops to a single item dict."""
    iid = item["id"]

    # Build per-lang alias sets (deduplication via set, preserve order via list + seen)
    lang_aliases: dict[str, list[str]] = {
        "de": list(item.get("aliases_de", [])),
        "en": list(item.get("aliases_en", [])),
        "fr": list(item.get("aliases_fr", [])),
        "es": list(item.get("aliases_es", [])),
    }

    # 1. Apply blocklist — remove (alias, canonical_id) pairs for this item.
    for lang_key in lang_aliases:
        lang_aliases[lang_key] = [
            a for a in lang_aliases[lang_key]
            if (a, iid) not in blocklist
        ]

    # 2. Add curated aliases for this item.
    for entry in curated:
        a = entry["alias"].lower().strip()
        lang = entry["lang"]
        if lang not in lang_aliases:
            lang_aliases[lang] = []
        if a not in lang_aliases[lang]:
            lang_aliases[lang].append(a)

    # 3. Add no-space variants for any multi-word aliases (both original and curated).
    # This lets "cornflakes" find "corn flakes" and vice-versa.
    for lang_key in list(lang_aliases.keys()):
        extra = []
        existing_set = set(lang_aliases[lang_key])
        for a in lang_aliases[lang_key]:
            v = no_space_variant(a)
            if v and v not in existing_set:
                extra.append(v)
                existing_set.add(v)
        lang_aliases[lang_key].extend(extra)

    item["aliases_de"] = lang_aliases["de"]
    item["aliases_en"] = lang_aliases["en"]
    item["aliases_fr"] = lang_aliases["fr"]
    item["aliases_es"] = lang_aliases["es"]
    return item


def main():
    items = json.loads(SRC.read_text())

    # Load enrichment data
    curated_by_id = load_curated_aliases(CURATED_ALIASES)
    if CURATED_MINED.exists():
        for cid, entries in load_curated_aliases(CURATED_MINED).items():
            curated_by_id.setdefault(cid, []).extend(entries)
    blocklist = load_blocklist(ALIAS_BLOCKLIST)

    # Validate all curated canonical_ids exist in the seed
    seed_ids = {it.get("id") or slugify(it.get("name_en") or it.get("name_de", "")) for it in items}
    # The seed.json loaded here is the RAW seed (before slugify-id assignment),
    # so IDs are assigned below. We'll validate after id assignment.
    # For now just log; hard error below after building.

    out = []
    seen_ids = set()
    unmapped = set()
    for it in items:
        cat = it.get("category", "")
        aisle = CATEGORY_TO_AISLE.get(cat)
        if aisle is None:
            unmapped.add(cat)
            aisle = "pantry"
        base = slugify(it.get("name_en") or it.get("name_de"))
        iid = base
        n = 2
        while iid in seen_ids:
            iid = f"{base}_{n}"; n += 1
        seen_ids.add(iid)

        row = {
            "id": iid,
            "name_de": it.get("name_de", ""),
            "name_en": it.get("name_en", ""),
            "name_fr": it.get("name_fr", ""),
            "name_es": it.get("name_es", ""),
            "category": aisle,
            "default_unit": it.get("default_unit", ""),
            "aliases_de": it.get("aliases_de", []),
            "aliases_en": it.get("aliases_en", []),
            "aliases_fr": it.get("aliases_fr", []),
            "aliases_es": it.get("aliases_es", []),
        }

        curated_for_item = curated_by_id.get(iid, [])
        row = merge_aliases_for_item(row, curated_for_item, blocklist)
        out.append(row)

    # Validate curated canonical_ids (gate check)
    assigned_ids = {row["id"] for row in out}
    bad_ids = set(curated_by_id.keys()) - assigned_ids
    if bad_ids:
        print("ERROR: curated_aliases.jsonl references canonical_ids not found in seed:")
        for bid in sorted(bad_ids):
            print(f"  {bid}")
        raise SystemExit("Fix curated_aliases.jsonl before building the seed.")

    if unmapped:
        print("WARNING unmapped categories ->", sorted(unmapped))

    DST.write_text(json.dumps({"version": ASSET_VERSION, "items": out},
                              ensure_ascii=False, indent=0))

    # Copy the ODbL-separable OFF brand aliases into the asset bundle as a
    # DISTINCT, attributed file (not merged into seed.json) so the share-alike
    # boundary stays clean. Generated by off_ground.py; skipped if absent.
    off_src = HERE / "data" / "off_aliases.json"
    if off_src.exists():
        off_dst = DST.parent / "off_aliases.json"
        off_dst.write_text(off_src.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"copied OFF aliases -> {off_dst}")

    sizes = collections.Counter(i["category"] for i in out)

    total_aliases = sum(
        len(i["aliases_de"]) + len(i["aliases_en"]) + len(i["aliases_fr"]) + len(i["aliases_es"])
        for i in out
    )
    print(f"wrote {len(out)} items -> {DST}")
    print(f"asset size: {DST.stat().st_size/1_000_000:.2f} MB")
    print(f"total aliases: {total_aliases}")
    print(f"asset version: {ASSET_VERSION}")
    print("aisle distribution:", dict(sizes))

    # Coverage probe for the specific items from plan 012
    probe_terms = [
        ("cornflakes", "corn_flakes"),
        ("müsli", "muesli"),
        ("cereal", "breakfast_cereal"),
        ("pads", "sanitary_pad"),
        ("pringles", "potato_chips"),
        ("oreo", "cookies"),
        ("haribo", "gummy_bears"),
        ("coca cola", "cola"),
        ("red bull", "energy_drink"),
        ("milka", "chocolate"),
        ("barilla", "pasta"),
        ("heinz", "ketchup"),
        ("nutella", "chocolate_hazelnut_spread"),
    ]
    item_map = {row["id"]: row for row in out}
    print("\n--- Coverage probe ---")
    all_ok = True
    for alias, expected_id in probe_terms:
        it = item_map.get(expected_id)
        if it is None:
            print(f"  MISSING item id={expected_id}")
            all_ok = False
            continue
        all_item_aliases = (
            it["aliases_de"] + it["aliases_en"] + it["aliases_fr"] + it["aliases_es"]
        )
        found = alias.lower() in [a.lower() for a in all_item_aliases]
        status = "OK" if found else "MISSING"
        if not found:
            all_ok = False
        print(f"  [{status}] '{alias}' -> {expected_id}")

    # Blocklist verification
    print("\n--- Blocklist verification ---")
    blocklist_ok = True
    for blocked_alias, wrong_id in blocklist:
        it = item_map.get(wrong_id)
        if it is None:
            continue
        all_item_aliases = (
            it["aliases_de"] + it["aliases_en"] + it["aliases_fr"] + it["aliases_es"]
        )
        still_present = blocked_alias.lower() in [a.lower() for a in all_item_aliases]
        if still_present:
            print(f"  [BLOCKLIST FAILED] '{blocked_alias}' still present in {wrong_id}")
            blocklist_ok = False
        else:
            print(f"  [BLOCKED OK] '{blocked_alias}' not in {wrong_id}")

    if all_ok and blocklist_ok:
        print("\nAll coverage probes passed.")
    else:
        print("\nWARNING: Some coverage probes failed — review above.")


if __name__ == "__main__":
    main()
