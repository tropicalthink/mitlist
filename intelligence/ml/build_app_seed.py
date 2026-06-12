#!/usr/bin/env python3
"""Transform the canonical grocery seed into the Flutter app's bundled asset.

Source: intelligence/ml/data/seed.json   (raw canonical array, 4 languages)
Target: frontend/assets/grocery/seed.json ({version, items:[...]} shape)

The app's GrocerySeedLoader expects each item to have a stable `id`, and only
reads name_de/name_en + aliases_de/aliases_en. `category` is used as the aisle
fallback label, so the 40 fine-grained source categories are mapped down to the
coarse aisle vocabulary the app already uses.
"""
import json, re, unicodedata, collections, pathlib

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "data" / "seed.json"
DST = HERE.parent.parent / "frontend" / "assets" / "grocery" / "seed.json"
ASSET_VERSION = 2

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

def main():
    items = json.loads(SRC.read_text())
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
        out.append({
            "id": iid,
            "name_de": it.get("name_de", ""),
            "name_en": it.get("name_en", ""),
            "category": aisle,
            "default_unit": it.get("default_unit", ""),
            "aliases_de": it.get("aliases_de", []),
            "aliases_en": it.get("aliases_en", []),
        })

    if unmapped:
        print("WARNING unmapped categories ->", sorted(unmapped))
    DST.write_text(json.dumps({"version": ASSET_VERSION, "items": out},
                              ensure_ascii=False, indent=0))
    sizes = collections.Counter(i["category"] for i in out)
    print(f"wrote {len(out)} items -> {DST}")
    print(f"asset size: {DST.stat().st_size/1_000_000:.2f} MB")
    print("aisle distribution:", dict(sizes))

if __name__ == "__main__":
    main()
