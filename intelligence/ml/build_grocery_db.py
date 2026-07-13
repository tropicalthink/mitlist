#!/usr/bin/env python3
"""Build the prebuilt read-only grocery reference database shipped to the app.

The app used to reconstruct the ~280k-row grocery "brain" (canonical items,
seed/OFF aliases, FTS index, store aisles) at runtime by inserting rows from the
JSON assets into its main writable DB — on the single connection that also
serves interactive list writes, so a cold start could stall the UI for tens of
seconds. This script instead bakes that static global data into a standalone
SQLite file the app copies into place once and queries read-only.

Source assets (already produced by build_app_seed.py / build_store_aisles.py):
  frontend/assets/grocery/seed.json          canonical items + per-language aliases
  frontend/assets/grocery/off_aliases.json   ODbL brand aliases (source='off')
  frontend/assets/grocery/store_aisles.json  shipped store layouts
Output:
  frontend/assets/grocery/grocery_ref.sqlite.gz   gzipped prebuilt DB (bundled)
  frontend/assets/grocery/grocery_ref.version.json version sidecar the installer reads

The schema MUST mirror the Drift tables in
frontend/lib/storage/app_database.dart (canonical_items_table,
item_aliases_table, store_aisles_table) and drift's conventions: DateTime as
INTEGER unix seconds, booleans as INTEGER 0/1, and PRAGMA user_version set to
GroceryReferenceDatabase.schemaVersion so drift opens it without migrating.
Alias text is normalised identically to Flutter's normaliseText and the FTS5
index uses the same tokenizer, or lookups (which normalise the query the same
way) would miss.

Bump REF_VERSION whenever any input asset changes; the installer re-copies when
the bundled version is newer than the one recorded on-device.
"""
import gzip
import json
import pathlib
import re
import shutil
import sqlite3
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ASSETS = HERE.parent.parent / "frontend" / "assets" / "grocery"
SEED = ASSETS / "seed.json"
OFF_ALIASES = ASSETS / "off_aliases.json"
STORE_AISLES = ASSETS / "store_aisles.json"
OUT_GZ = ASSETS / "grocery_ref.sqlite.gz"
VERSION_SIDECAR = ASSETS / "grocery_ref.version.json"

# Must equal GroceryReferenceDatabase.schemaVersion in the Flutter app.
DRIFT_SCHEMA_VERSION = 1
# Bump when any input asset changes so the installer re-copies on-device.
REF_VERSION = 1
GLOBAL_GROUP_ID = "__global__"

# Fixed epoch for created_at/updated_at — never displayed, only filtered on
# deleted_at IS NULL, so a constant keeps builds reproducible.
FIXED_TS = 0

SCHEMA = """
CREATE TABLE "canonical_items_table" (
  "id" TEXT NOT NULL,
  "group_id" TEXT NOT NULL,
  "name_de" TEXT NOT NULL DEFAULT '',
  "name_en" TEXT NOT NULL DEFAULT '',
  "name_fr" TEXT NOT NULL DEFAULT '',
  "name_es" TEXT NOT NULL DEFAULT '',
  "category" TEXT NOT NULL DEFAULT '',
  "default_unit" TEXT NOT NULL DEFAULT '',
  "product_id" TEXT,
  "is_global" INTEGER NOT NULL DEFAULT 0 CHECK ("is_global" IN (0, 1)),
  "version" INTEGER NOT NULL DEFAULT 0,
  "created_at" INTEGER NOT NULL,
  "updated_at" INTEGER NOT NULL,
  "deleted_at" INTEGER,
  PRIMARY KEY ("id")
);
CREATE TABLE "item_aliases_table" (
  "id" TEXT NOT NULL,
  "group_id" TEXT NOT NULL,
  "canonical_item_id" TEXT NOT NULL,
  "alias_text" TEXT NOT NULL,
  "lang" TEXT NOT NULL DEFAULT 'und',
  "source" TEXT NOT NULL DEFAULT 'correction',
  "weight" INTEGER NOT NULL DEFAULT 1,
  "version" INTEGER NOT NULL DEFAULT 0,
  "created_at" INTEGER NOT NULL,
  "updated_at" INTEGER NOT NULL,
  "deleted_at" INTEGER,
  PRIMARY KEY ("id")
);
CREATE TABLE "store_aisles_table" (
  "id" TEXT NOT NULL,
  "group_id" TEXT NOT NULL,
  "store_id" TEXT,
  "canonical_item_id" TEXT NOT NULL,
  "aisle" TEXT NOT NULL DEFAULT '',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "confidence" REAL NOT NULL DEFAULT 0.5,
  "version" INTEGER NOT NULL DEFAULT 0,
  "created_at" INTEGER NOT NULL,
  "updated_at" INTEGER NOT NULL,
  "deleted_at" INTEGER,
  PRIMARY KEY ("id")
);
CREATE TABLE "ref_meta" (
  "key" TEXT NOT NULL PRIMARY KEY,
  "value" TEXT NOT NULL
);
"""

FTS_CREATE = (
    'CREATE VIRTUAL TABLE item_aliases_fts USING fts5('
    "alias_text, content=item_aliases_table, content_rowid=rowid, "
    'tokenize="unicode61 remove_diacritics 2");'
)

INDEXES = [
    "CREATE INDEX idx_canonical_items_table_group_id ON canonical_items_table(group_id);",
    "CREATE INDEX idx_item_aliases_table_group_id ON item_aliases_table(group_id);",
    "CREATE INDEX idx_item_aliases_table_alias_text ON item_aliases_table(alias_text);",
    "CREATE INDEX idx_item_aliases_group_alias ON item_aliases_table(group_id, alias_text);",
    "CREATE INDEX idx_store_aisles_table_group_id ON store_aisles_table(group_id);",
]


def normalise_text(value: str) -> str:
    """Match Flutter's normaliseText: lowercase, trim, collapse whitespace."""
    return re.sub(r"\s+", " ", value.lower().strip())


def load_json(path: pathlib.Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def build(db: sqlite3.Connection) -> dict:
    stats = {"canonical": 0, "aliases_seed": 0, "aliases_off": 0, "aisles": 0}
    alias_seq = 0

    def next_alias_id() -> str:
        nonlocal alias_seq
        alias_seq += 1
        # Opaque, unique, deterministic. The alias id is never used for joins
        # (the FTS join is on rowid; callers key off canonical_item_id).
        return f"ref-alias-{alias_seq:08d}"

    # --- Canonical seed + seed aliases -------------------------------------
    seed = load_json(SEED)
    seed_version = int(seed.get("version", 0))
    canonical_rows = []
    alias_rows = []
    for item in seed["items"]:
        cid = item["id"]
        canonical_rows.append((
            cid, GLOBAL_GROUP_ID,
            item.get("name_de", "") or "",
            item.get("name_en", "") or "",
            item.get("name_fr", "") or "",
            item.get("name_es", "") or "",
            item.get("category", "") or "",
            item.get("default_unit", "") or "",
            None,        # product_id
            1,           # is_global
            0,           # version
            FIXED_TS, FIXED_TS, None,
        ))

        def add_alias(text, lang):
            if text is None:
                return
            normalized = normalise_text(text)
            if not normalized:
                return
            alias_rows.append((
                next_alias_id(), GLOBAL_GROUP_ID, cid, normalized,
                lang, "seed", 1, 0, FIXED_TS, FIXED_TS, None,
            ))

        for lang in ("de", "en", "fr", "es"):
            for a in item.get(f"aliases_{lang}", []) or []:
                add_alias(a, lang)
            add_alias(item.get(f"name_{lang}"), lang)

    stats["canonical"] = len(canonical_rows)
    stats["aliases_seed"] = len(alias_rows)

    # --- OFF brand aliases (ODbL, source='off') ----------------------------
    off_version = 0
    if OFF_ALIASES.exists():
        off = load_json(OFF_ALIASES)
        off_version = int(off.get("version", 0))
        for cid, by_lang in (off.get("items", {}) or {}).items():
            for lang, aliases in (by_lang or {}).items():
                for a in aliases or []:
                    normalized = normalise_text(a)
                    if not normalized:
                        continue
                    alias_rows.append((
                        next_alias_id(), GLOBAL_GROUP_ID, cid, normalized,
                        lang, "off", 1, 0, FIXED_TS, FIXED_TS, None,
                    ))
                    stats["aliases_off"] += 1

    # --- Store aisles ------------------------------------------------------
    aisles_version = 0
    aisle_rows = []
    if STORE_AISLES.exists():
        sa = load_json(STORE_AISLES)
        aisles_version = int(sa.get("version", 0))
        for i, a in enumerate(sa.get("aisles", []) or []):
            aisle_rows.append((
                f"ref-aisle-{i:07d}", GLOBAL_GROUP_ID,
                a.get("store_id"),
                a["canonical_item_id"],
                a.get("aisle", "") or "",
                int(a.get("sort_order", 0) or 0),
                float(a.get("confidence", 0.5) or 0.5),
                0, FIXED_TS, FIXED_TS, None,
            ))
    stats["aisles"] = len(aisle_rows)

    # --- Write --------------------------------------------------------------
    db.executescript(SCHEMA)
    db.executemany(
        'INSERT INTO "canonical_items_table" VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        canonical_rows,
    )
    db.executemany(
        'INSERT INTO "item_aliases_table" VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        alias_rows,
    )
    db.executemany(
        'INSERT INTO "store_aisles_table" VALUES (?,?,?,?,?,?,?,?,?,?,?)',
        aisle_rows,
    )
    # FTS index over the alias table, built in one bulk pass after the insert.
    db.execute(FTS_CREATE)
    db.execute("INSERT INTO item_aliases_fts(item_aliases_fts) VALUES ('rebuild');")
    for idx in INDEXES:
        db.execute(idx)

    meta = {
        "ref_version": str(REF_VERSION),
        "seed_version": str(seed_version),
        "off_version": str(off_version),
        "store_aisles_version": str(aisles_version),
        "attribution": "Brand aliases (source='off') derived from Open Food Facts, ODbL-1.0.",
    }
    db.executemany(
        'INSERT INTO "ref_meta" VALUES (?,?)', list(meta.items())
    )
    db.execute(f"PRAGMA user_version = {DRIFT_SCHEMA_VERSION};")
    db.commit()
    db.execute("VACUUM;")
    db.commit()
    return stats


def main() -> None:
    for required in (SEED,):
        if not required.exists():
            raise SystemExit(f"missing input asset: {required} (run build_app_seed.py first)")

    with tempfile.TemporaryDirectory() as tmp:
        raw_path = pathlib.Path(tmp) / "grocery_ref.sqlite"
        db = sqlite3.connect(str(raw_path))
        try:
            stats = build(db)
        finally:
            db.close()
        raw_size = raw_path.stat().st_size

        with raw_path.open("rb") as src, gzip.open(OUT_GZ, "wb", compresslevel=9) as dst:
            shutil.copyfileobj(src, dst)
        gz_size = OUT_GZ.stat().st_size

    VERSION_SIDECAR.write_text(json.dumps({"version": REF_VERSION}) + "\n", encoding="utf-8")

    total_aliases = stats["aliases_seed"] + stats["aliases_off"]
    print("grocery_ref.sqlite built:")
    print(f"  canonical items : {stats['canonical']:>8,}")
    print(f"  aliases (seed)  : {stats['aliases_seed']:>8,}")
    print(f"  aliases (off)   : {stats['aliases_off']:>8,}")
    print(f"  aliases (total) : {total_aliases:>8,}")
    print(f"  store aisles    : {stats['aisles']:>8,}")
    print(f"  raw size        : {raw_size/1_048_576:>8.1f} MB")
    print(f"  gzipped asset   : {gz_size/1_048_576:>8.1f} MB  -> {OUT_GZ}")
    print(f"  ref version     : {REF_VERSION}  -> {VERSION_SIDECAR}")


if __name__ == "__main__":
    main()
