#!/usr/bin/env python3
"""Ground the canonical grocery seed in real Open Food Facts (OFF) brand data.

Why: the synthetic seed has no brands, so typing "pringles" / "haribo" / "milka"
returns nothing. OFF knows that Pringles is a potato crisp, Haribo a gummy, etc.
This script reads OFF, maps each product to one of OUR canonical items via an
ordered category-keyword rule map (the maintainer-owned judgment), then attaches
the product's BRAND as an alias of that canonical item — but only for brands that
concentrate in a single canonical item (so multi-category brands like "Heinz"
are skipped rather than mis-mapped).

ODbL: OFF is ODbL-1.0. The derived index is written to data/off_aliases.json
(separable, attributed) — it is NOT merged into seed.json here. Keeping it in its
own file preserves the share-alike boundary; the app loads it as a distinct,
attributed asset.

Input  (needs OFF dump + duckdb):  --off-parquet  (food.parquet, ~7.5GB, or a
        pre-filtered subset). Filter: countries in {de,fr,es,uk,us} & scans>=MIN.
Outputs:
  data/off_aliases.json        ODbL-separable {item_id: {"und": [brand, ...]}}
  data/off_brand_review.tsv    brand | item_id | item_name | products | scans | share

Usage:
  python3 -m venv .venv && .venv/bin/pip install duckdb
  .venv/bin/python intelligence/ml/off_ground.py \
      --off-parquet /path/to/food.parquet
"""
import argparse
import json
import pathlib
import re
import sys
import unicodedata
from collections import Counter, defaultdict

HERE = pathlib.Path(__file__).resolve().parent
DATA = HERE / "data"
SEED = DATA / "seed.json"

MIN_SCANS = 30                 # per-product popularity floor (maintainer choice)
MARKETS = ("en:germany", "en:france", "en:spain",
           "en:united-kingdom", "en:united-states")

# Brand → single canonical item only when the brand is this concentrated:
BRAND_MIN_PRODUCTS = 2         # winning item must back >=N products
BRAND_MIN_COVERAGE = 0.30      # >=30% of the brand's TOTAL in-scope products map to
                               # items we recognise (else it's a brand whose identity
                               # is mostly something we don't model — e.g. Andros=jam)
BRAND_MIN_SHARE = 0.60         # among mapped products, one item must dominate
BRAND_MIN_SCANS = 150          # summed popularity, so we only add brands people scan

OFF_ATTRIBUTION = (
    "Data source: Open Food Facts (https://world.openfoodfacts.org), licensed "
    "under the Open Database License (ODbL) v1.0 "
    "(https://opendatacommons.org/licenses/odbl/). This derived brand index is "
    "kept separable from the canonical seed per ODbL share-alike."
)

# Retailer / generic / private-label brands that aren't a product identity.
BRAND_STOPLIST = {
    "carrefour", "auchan", "leclerc", "casino", "monoprix", "lidl", "aldi",
    "tesco", "sainsbury's", "sainsburys", "asda", "morrisons", "waitrose",
    "marks & spencer", "m&s", "great value", "kirkland", "kirkland signature",
    "bio", "biologique", "organic", "u", "cora", "intermarché", "intermarche",
    "netto", "edeka", "rewe", "dm", "dmbio", "rossmann", "marque repère",
    "marque repere", "eroski", "hacendado", "mercadona", "dia", "carrefour bio",
    "spar", "coop", "migros", "delhaize", "franprix", "simpl", "système u",
    "systeme u", "leader price", "picard", "lidl stiftung", "kaufland",
}


def slug(item: dict) -> str:
    name = item.get("name_en") or item.get("name_de") or ""
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower() or "item"


# ── The judgment: ordered OFF category-keyword → canonical item id ────────────
# A product is mapped to the FIRST rule whose keyword appears in ANY of its
# categories_tags. Order = specific → generic. Ambiguous targets (generic
# "yogurt", "soft drink", "bread", "honey", "skyr") are intentionally omitted —
# a gap is safer than a wrong alias. Every target id is validated to exist.
OFF_RULES: list[tuple[list[str], str]] = [
    # snacks / salty
    (["potato-crisps", "potato-chips"], "potato_chips"),
    (["corn-chips", "tortilla-chips", "nacho"], "tortilla_chips"),
    (["popcorn"], "popcorn"),
    (["pretzel"], "pretzel"),
    # sweets
    (["cocoa-and-hazelnuts-spreads", "hazelnut-spreads", "chocolate-spreads"],
     "chocolate_hazelnut_spread"),
    (["dark-chocolate"], "dark_chocolate"),
    (["milk-chocolate", "white-chocolate", "chocolate-bar", "chocolate-tablet",
      "pralines", "filled-chocolates", "chocolate-candies"], "chocolate_bar"),
    (["gummy", "gummies", "gummi", "wine-gums", "marshmallow", "jelly-sweets",
      "fruit-jellies"], "gummy_bears"),
    (["chocolate-biscuit", "filled-biscuit", "shortbread", "cookies",
      "biscuits"], "cookies"),
    # breakfast
    (["muesli", "mueslis", "granola"], "muesli"),
    (["corn-flakes", "cornflakes"], "corn_flakes"),
    (["rolled-oats", "oat-flakes", "porridge-oats", "oatmeal"], "rolled_oats"),
    (["cereal-bars", "muesli-bars", "protein-bars", "energy-bars"], "granola_bar"),
    (["breakfast-cereals"], "breakfast_cereal"),
    # spreads
    (["peanut-butter", "peanut-butters"], "peanut_butter"),
    # dairy
    (["cream-cheese", "cream-cheeses"], "cream_cheese"),
    (["cheese-spread"], "cheese_spread"),
    (["greek-style-yogurt", "greek-yogurt", "greek-yogurts"], "greek_yogurt"),
    (["drinking-yogurt", "yogurt-drinks", "yogurt-drink"], "drinking_yogurt"),
    (["kefir", "kefirs"], "fruit_kefir"),
    # plant drinks
    (["oat-based-drink", "oat-drink", "oat-milk", "oat-beverage"], "oat_milk"),
    (["almond-based-drink", "almond-milk", "almond-beverage"], "almond_milk"),
    (["soy-drink", "soy-milk", "soy-based-beverage", "soya-drink"], "soy_milk"),
    # condiments / oils
    (["virgin-olive-oil", "olive-oils", "olive-oil"], "olive_oil"),
    (["ketchup"], "ketchup"),
    (["mayonnaise", "mayonnaises"], "mayonnaise"),
    (["mustard", "mustards"], "mustard"),
    # beverages
    (["cola", "colas"], "cola"),
    (["natural-mineral-water", "mineral-waters", "spring-water"], "mineral_water"),
    # staples
    (["spaghetti", "macaroni", "penne", "fusilli", "pastas"], "pasta"),
]


def build_resolver(seed: list[dict]):
    valid = {slug(it) for it in seed}
    # Validate every rule target exists — fail loud, don't silently drop.
    missing = sorted({iid for _, iid in OFF_RULES if iid not in valid})
    if missing:
        sys.exit(f"[off_ground] FATAL: rule targets not in seed: {missing}")

    # Token-boundary match against the hyphen-delimited tag body (after "en:").
    # Substring matching is wrong for short keywords — "cola" is inside
    # "cho-cola-te" ("en:chocolate-drinks"). Anchoring on start/end/hyphen makes
    # "cola" match "en:cola"/"en:colas" but never "en:chocolate-...".
    patterns = [
        ([re.compile(r"(^|-)" + re.escape(kw) + r"($|-)") for kw in kws], iid)
        for kws, iid in OFF_RULES
    ]

    def resolve(tags: list[str]) -> str | None:
        bodies = [t.split(":", 1)[-1] for t in (tags or [])]
        for regexes, item_id in patterns:
            for body in bodies:
                for rx in regexes:
                    if rx.search(body):
                        return item_id
        return None

    return resolve


def norm_brand(b: str) -> str:
    return re.sub(r"\s+", " ", b).strip().lower()


def brand_variants(b: str) -> list[str]:
    """The brand plus a de-accented / apostrophe-stripped form so a user typing
    "lays" or "kelloggs" or "cote dor" still matches "lay's" / "côte d'or"."""
    plain = unicodedata.normalize("NFKD", b).encode("ascii", "ignore").decode()
    plain = plain.replace("'", "").replace("’", "")
    plain = re.sub(r"\s+", " ", plain).strip()
    out = [b]
    if plain and plain != b:
        out.append(plain)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--off-parquet", required=True,
                    help="OFF food.parquet (or a pre-filtered subset parquet)")
    ap.add_argument("--out-aliases", default=str(DATA / "off_aliases.json"))
    ap.add_argument("--out-review", default=str(DATA / "off_brand_review.tsv"))
    args = ap.parse_args()

    import duckdb  # local import so the module loads without the dep

    seed = json.loads(SEED.read_text(encoding="utf-8"))
    id_to_name = {slug(it): (it.get("name_en") or it.get("name_de") or slug(it))
                  for it in seed}
    resolve = build_resolver(seed)

    con = duckdb.connect()
    markets = "(" + ",".join(f"'{m}'" for m in MARKETS) + ")"
    rows = con.execute(f"""
        SELECT brands, categories_tags, unique_scans_n AS n
        FROM read_parquet('{args.off_parquet}')
        WHERE unique_scans_n >= {MIN_SCANS}
          AND len(list_filter(countries_tags, c -> c IN {markets})) > 0
          AND brands IS NOT NULL AND length(brands) > 1
    """).fetchall()
    print(f"[off_ground] {len(rows):,} OFF products with a brand in-scope.")

    # brand → mapped item counts, summed scans per item, and TOTAL in-scope
    # products (mapped or not) so we can measure how concentrated the brand is.
    brand_items: dict[str, Counter] = defaultdict(Counter)
    brand_scans: dict[str, Counter] = defaultdict(Counter)
    brand_total: Counter = Counter()
    for brands, tags, n in rows:
        b = norm_brand(brands.split(",")[0])  # primary brand
        if len(b) < 3 or b in BRAND_STOPLIST:
            continue
        brand_total[b] += 1
        item_id = resolve(tags)
        if not item_id:
            continue
        brand_items[b][item_id] += 1
        brand_scans[b][item_id] += n or 0

    aliases: dict[str, dict[str, list[str]]] = defaultdict(lambda: {"und": []})
    review: list[tuple] = []
    for b, items in brand_items.items():
        mapped = sum(items.values())
        coverage = mapped / brand_total[b]
        item_id, top = items.most_common(1)[0]
        share = top / mapped
        scans = brand_scans[b][item_id]
        if (top >= BRAND_MIN_PRODUCTS and coverage >= BRAND_MIN_COVERAGE
                and share >= BRAND_MIN_SHARE and scans >= BRAND_MIN_SCANS):
            aliases[item_id]["und"].extend(brand_variants(b))
            review.append((b, item_id, id_to_name[item_id], top,
                           brand_total[b], scans, round(coverage, 2), round(share, 2)))

    # de-dup + sort aliases for stable output
    out_items = {}
    for item_id, langs in aliases.items():
        uniq = sorted(set(langs["und"]))
        if uniq:
            out_items[item_id] = {"und": uniq}

    payload = {"_attribution": OFF_ATTRIBUTION, "_license": "ODbL-1.0",
               "_generator": "off_ground.py", "items": out_items}
    pathlib.Path(args.out_aliases).write_text(
        json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")

    review.sort(key=lambda r: -r[5])  # by scans desc
    with open(args.out_review, "w", encoding="utf-8") as fh:
        fh.write("brand\titem_id\titem_name\tproducts\tbrand_total\tscans"
                 "\tcoverage\tshare\n")
        for r in review:
            fh.write("\t".join(str(x) for x in r) + "\n")

    n_aliases = sum(len(v["und"]) for v in out_items.values())
    print(f"[off_ground] {n_aliases} brand aliases across {len(out_items)} items.")
    print(f"[off_ground] wrote {args.out_aliases}")
    print(f"[off_ground] wrote {args.out_review}")


if __name__ == "__main__":
    main()
