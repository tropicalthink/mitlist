#!/usr/bin/env python3
"""Transform store-layout data into the app's global store-aisle asset.

Source: intelligence/ml/data/aisles.jsonl   (per-store item→aisle + sort order)
        frontend/assets/grocery/seed.json    (for canonical item ids)
Target: frontend/assets/grocery/store_aisles.json

Store layouts ship globally (groupId '__global__'); the household just picks
which store they shop at. Each aisle row is keyed by the seed's canonical item
id, resolved from the English (then German) canonical name.
"""
import json, re, unicodedata, pathlib, collections

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE / "data" / "aisles.jsonl"
SEED = HERE.parent.parent / "frontend" / "assets" / "grocery" / "seed.json"
DST = HERE.parent.parent / "frontend" / "assets" / "grocery" / "store_aisles.json"
ASSET_VERSION = 1

def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", s).strip().lower()

def store_id(country: str, store: str) -> str:
    raw = f"{country}_{store}"
    s = unicodedata.normalize("NFKD", raw).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower()

def main():
    seed = json.loads(SEED.read_text())["items"]
    # Canonical-name maps take priority; alias maps are a fallback so plural /
    # variant store names ("Äpfel"/"Apples") still resolve to the seed item.
    by_en, by_de, by_alias = {}, {}, {}
    for it in seed:
        if it.get("name_en"):
            by_en.setdefault(norm(it["name_en"]), it["id"])
        if it.get("name_de"):
            by_de.setdefault(norm(it["name_de"]), it["id"])
        for a in (it.get("aliases_en", []) + it.get("aliases_de", [])):
            by_alias.setdefault(norm(a), it["id"])

    def resolve(r):
        return (by_en.get(norm(r.get("canonical_name_en", "")))
                or by_de.get(norm(r.get("canonical_name_de", "")))
                or by_alias.get(norm(r.get("canonical_name_en", "")))
                or by_alias.get(norm(r.get("canonical_name_de", ""))))

    stores = {}
    aisles = []
    unresolved = 0
    for line in SRC.read_text().splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        sid = store_id(r["country"], r["store"])
        stores.setdefault(sid, {
            "id": sid,
            "name": r["store"],
            "country": r["country"],
            "chain_type": r.get("chain_type", ""),
        })
        cid = resolve(r)
        if cid is None:
            unresolved += 1
            continue
        aisles.append({
            "store_id": sid,
            "canonical_item_id": cid,
            "aisle": r.get("aisle", ""),
            "sort_order": r.get("sort_order", 0),
            "confidence": 0.9 if r.get("typically_stocked") else 0.5,
        })

    out = {
        "version": ASSET_VERSION,
        "stores": sorted(stores.values(), key=lambda s: (s["country"], s["name"])),
        "aisles": aisles,
    }
    DST.write_text(json.dumps(out, ensure_ascii=False, indent=0))
    total = len(aisles) + unresolved
    print(f"stores: {len(stores)} | aisle rows: {len(aisles)} resolved, "
          f"{unresolved} unresolved ({len(aisles)/total*100:.0f}% resolved)")
    print(f"wrote {DST} ({DST.stat().st_size/1000:.0f} KB)")
    print("per-store rows:", dict(collections.Counter(a["store_id"] for a in aisles)))

if __name__ == "__main__":
    main()
