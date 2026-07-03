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
ASSET_VERSION = 2

def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", s).strip().lower()

def norm_candidates(s: str) -> list[str]:
    base = norm(s)
    if not base:
        return []
    stripped = norm(re.sub(r"\([^)]*\)", " ", s))
    candidates = [base]
    if stripped and stripped != base:
        candidates.append(stripped)
    return candidates

def store_id(country: str, store: str) -> str:
    raw = f"{country}_{store}"
    s = unicodedata.normalize("NFKD", raw).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower()

def main():
    seed = json.loads(SEED.read_text())["items"]
    # Canonical-name maps take priority; alias maps are a fallback so plural /
    # variant store names ("Äpfel"/"Apples") still resolve to the seed item.
    by_name, by_alias = {}, {}
    for it in seed:
        for lang in ("en", "de", "fr", "es"):
            for key in norm_candidates(it.get(f"name_{lang}", "")):
                by_name.setdefault(key, it["id"])
            for alias in it.get(f"aliases_{lang}", []):
                for key in norm_candidates(alias):
                    by_alias.setdefault(key, it["id"])

    def resolve(r):
        names = [
            r.get("canonical_name_en", ""),
            r.get("canonical_name_de", ""),
            r.get("canonical_name_fr", ""),
            r.get("canonical_name_es", ""),
        ]
        for name in names:
            for key in norm_candidates(name):
                if key in by_name:
                    return by_name[key]
        for name in names:
            for key in norm_candidates(name):
                if key in by_alias:
                    return by_alias[key]
        return None

    stores = {}
    aisles = []
    unresolved = []
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
            unresolved.append(r)
            continue
        aisles.append({
            "store_id": sid,
            "canonical_item_id": cid,
            "aisle": r.get("aisle", ""),
            "sort_order": r.get("sort_order", 0),
            "confidence": 0.9 if r.get("typically_stocked") else 0.5,
        })

    unresolved_count = len(unresolved)
    out = {
        "version": ASSET_VERSION,
        "stores": sorted(stores.values(), key=lambda s: (s["country"], s["name"])),
        "aisles": aisles,
    }
    DST.write_text(json.dumps(out, ensure_ascii=False, indent=0))
    total = len(aisles) + unresolved_count
    resolved_items = {a["canonical_item_id"] for a in aisles}
    resolved_pairs = {(a["store_id"], a["canonical_item_id"]) for a in aisles}
    source_pairs = {
        (store_id(r["country"], r["store"]), norm(r.get("canonical_name_en", "")))
        for r in (json.loads(line) for line in SRC.read_text().splitlines() if line.strip())
    }
    print(f"stores: {len(stores)} | aisle rows: {len(aisles)} resolved, "
          f"{unresolved_count} unresolved ({len(aisles)/total*100:.0f}% resolved)")
    print(f"distinct resolved items: {len(resolved_items)} | "
          f"distinct resolved store/item pairs: {len(resolved_pairs)} | "
          f"source store/name pairs: {len(source_pairs)}")
    if unresolved:
        print("unresolved examples:")
        for r in unresolved[:20]:
            print("  "
                  f"{r.get('country')}/{r.get('store')}: "
                  f"en={r.get('canonical_name_en', '')!r}, "
                  f"de={r.get('canonical_name_de', '')!r}, "
                  f"fr={r.get('canonical_name_fr', '')!r}, "
                  f"es={r.get('canonical_name_es', '')!r}")
    print(f"wrote {DST} ({DST.stat().st_size/1000:.0f} KB)")
    print("per-store rows:", dict(collections.Counter(a["store_id"] for a in aisles)))

if __name__ == "__main__":
    main()
