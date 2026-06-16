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
It also mines product NAMES (generic_name + product_name, per language) into
localized generic aliases — "beurre de cacahuète" → peanut_butter, "aceite de
oliva virgen" → olive_oil — guarded by a novelty check against the seed so
mis-categorised decoys (sardines-in-olive-oil, "beurre"/butter) are dropped.

Outputs:
  data/off_aliases.json        ODbL-separable {item_id: {"und": [brand…],
                                                          "fr": [term…], …}}
  data/off_brand_review.tsv    brand | item_id | item_name | products | scans | share
  data/off_name_review.tsv     term | lang | item_id | item_name | products | share | items

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

# Bumped when the generated aliases change so the app re-ingests them (the seed
# loader gates OFF ingestion on this, separate from the seed asset version).
# v2: adds mined product-NAME aliases (localized generic vocabulary) alongside
# the brand aliases.
OFF_VERSION = 2

MIN_SCANS = 10                 # per-product popularity floor (override with --min-scans).
                               # 10 catches household brands (Cadbury, Kit Kat,
                               # Ritter Sport, Cheerios, San Pellegrino, Katjes…)
                               # the 30 cutoff missed, at negligible extra noise.
MARKETS = ("en:germany", "en:france", "en:spain",
           "en:united-kingdom", "en:united-states")

# Known-wrong brand→item mappings to drop (a few SKUs in a category that isn't
# the brand's identity slip past the thresholds). Hand-pruned from the review
# TSV; cheaper than over-tightening thresholds and losing good rows.
BRAND_EXCLUDE = {
    "cheetos",     # corn puffs, not cookies
    "curly",       # peanut puffs (Vico), not cookies
    "paulaner",    # beer (a radler SKU landed it in cola)
    "selection",   # generic word, not a brand identity
    "decathlon",   # sports retailer, not a food brand
}

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

# ── Product-NAME mining (localized generic vocabulary) ───────────────────────
# Brands tell us "Pringles is a crisp"; NAMES tell us the GENERIC word people
# type in their own language — "beurre de cacahuète", "aceite de oliva virgen",
# "flocons d'avoine", "natives olivenöl". We mine OFF generic_name + product_name
# per language, clean off brand/quantity/filler tokens, and keep a term as an
# alias of a canonical item only when it (a) concentrates on that one item and
# (b) is NOVEL — the seed does not already own it for a different item. The
# novelty guard is the safety net: it drops decoys where the category resolver
# mapped a product for a secondary reason (sardines IN olive oil → olive_oil,
# "beurre"/butter from "galettes pur beurre" → cookies) because those words are
# already seed names for their real item.
NAME_LANGS = ("de", "fr", "es", "en")
NAME_MIN_PRODUCTS = 4          # term must back >=N distinct products for the item
NAME_MIN_SHARE = 0.85          # and dominate among the items it maps to
NAME_MAX_ITEMS = 2             # term may map to at most this many distinct items
NAME_MAX_WORDS = 4             # drop legalese descriptions nobody would type

# Junk phrases / fragments seen in the review TSV that pass the stats but aren't
# a real generic term (hand-pruned, same spirit as BRAND_EXCLUDE).
NAME_BLOCK = {
    "taste", "hot spicy", "spaghetti n", "mayonnaise ingredients",
    "mayonnaise ingrédients", "bebida refrescante aromatizada",
    "koffeinhaltiges erfrischungsgetränk mit pflanzenextrakten",
    "bran flakes",  # too generic, collides with several cereals
    # bare modifier words that aren't a product identity
    "diet", "max", "zero", "zéro", "minis", "barres", "moelleux",
    "salted caramel", "punto de sal",
}

# Tokens that betray a different food sneaking into a category via "X in olive
# oil" / "X à l'huile" style products. Any candidate containing one is rejected
# — generalises the sardines→olive_oil contamination beyond exact phrases.
NAME_TOKEN_BLOCK = {
    "sardines", "sardine", "thon", "tonno", "tuna", "atun", "atún", "atunes",
    "maquereau", "anchois", "anchovy", "anchoa", "anchoas", "saumon", "salmon",
    "salmón", "lachs", "hareng", "herring", "filets", "filet", "fillets",
}

# Filler words stripped from candidate names (multilingual). A candidate that
# reduces to only these is rejected.
NAME_STOP = set("""
bio biologique organic eco ecologico ecológico natur natural naturel sans avec
gout goût saveur flavour flavor aroma sabor original originale classique classic
extra fine finest premium qualite qualité select selection sélection maison
pur pure puro reduit réduit light leger léger zero sucre sucres sucree sucrée
sale salé salée sel azucar azúcar sin con boite boîte pack lot sachet
sachets stuck stück packung beutel bolsa paquet paquete
the le la les un une des du de del al a y et and of for con e i o
au aux para mit und oder fur für el los las en in im zum zur da
grand petit gross groß klein mini maxi familial family format new nouveau nouvelle
g kg mg ml cl l x stk st pcs pieces pp coop produit product produkt producto
""".split())

_NAME_QTY = re.compile(r"\b\d+[.,]?\d*\s?(g|kg|mg|ml|cl|l|x|%|stk|st|pcs|pc|p)?\b",
                       re.IGNORECASE)
_NAME_PUNCT = re.compile(r"[^\w\s'’à-ÿ-]", re.UNICODE)


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


def _seed_norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", s.lower().strip())


def build_seed_index(seed: list[dict]) -> dict[str, set]:
    """Map every existing seed name/alias (de-accented, lowered) → the set of
    canonical slugs that already own it. Used by the novelty guard so we never
    mine a name that the seed already routes to a (different) item."""
    idx: dict[str, set] = defaultdict(set)
    for it in seed:
        sl = slug(it)
        for k in ("name_de", "name_en", "name_fr", "name_es",
                  "aliases_de", "aliases_en", "aliases_fr", "aliases_es"):
            v = it.get(k)
            vals = [v] if isinstance(v, str) else (v or [])
            for n in vals:
                if n:
                    idx[_seed_norm(n)].add(sl)
    return idx


def clean_name(text: str, brand_toks: set[str]) -> str | None:
    """Reduce an OFF name to a candidate generic term: lowercase, strip
    quantities / units / punctuation / the product's own brand tokens / filler
    words. Returns None when nothing usable remains."""
    s = text.lower().strip()
    s = _NAME_QTY.sub(" ", s)
    s = s.replace("®", " ").replace("™", " ")
    s = _NAME_PUNCT.sub(" ", s)
    s = re.sub(r"\s+", " ", s).strip()
    toks = [t for t in s.split() if t and t not in brand_toks and not t.isdigit()]
    while toks and toks[0] in NAME_STOP:
        toks.pop(0)
    # trailing filler / "n°5"-style fragments left as a bare "n" / "no"
    while toks and (toks[-1] in NAME_STOP or len(toks[-1]) <= 1
                    or toks[-1] in {"no", "nr", "nº", "n°"}):
        toks.pop()
    if not toks or all(t in NAME_STOP for t in toks):
        return None
    if any(t in NAME_TOKEN_BLOCK for t in toks):
        return None
    phrase = " ".join(toks)
    if len(phrase) < 3 or len(toks) > NAME_MAX_WORDS:
        return None
    if not re.search(r"[a-zà-ÿ]{3}", phrase):
        return None
    if phrase in NAME_BLOCK:
        return None
    return phrase


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--off-parquet", required=True,
                    help="OFF food.parquet (or a pre-filtered subset parquet)")
    ap.add_argument("--min-scans", type=int, default=MIN_SCANS,
                    help=f"per-product popularity floor (default {MIN_SCANS})")
    ap.add_argument("--out-aliases", default=str(DATA / "off_aliases.json"))
    ap.add_argument("--out-review", default=str(DATA / "off_brand_review.tsv"))
    ap.add_argument("--out-name-review",
                    default=str(DATA / "off_name_review.tsv"))
    args = ap.parse_args()
    min_scans = args.min_scans

    import duckdb  # local import so the module loads without the dep

    seed = json.loads(SEED.read_text(encoding="utf-8"))
    id_to_name = {slug(it): (it.get("name_en") or it.get("name_de") or slug(it))
                  for it in seed}
    resolve = build_resolver(seed)
    seed_idx = build_seed_index(seed)

    con = duckdb.connect()
    markets = "(" + ",".join(f"'{m}'" for m in MARKETS) + ")"
    # One scan feeds both brand and name mining. We no longer require a brand
    # (name mining wants brandless generics too); brand accounting guards on it.
    rows = con.execute(f"""
        SELECT brands, categories_tags, product_name, generic_name,
               unique_scans_n AS n
        FROM read_parquet('{args.off_parquet}')
        WHERE unique_scans_n >= {min_scans}
          AND len(list_filter(countries_tags, c -> c IN {markets})) > 0
    """).fetchall()
    print(f"[off_ground] {len(rows):,} OFF products in-scope.")

    # brand → mapped item counts, summed scans per item, and TOTAL in-scope
    # products (mapped or not) so we can measure how concentrated the brand is.
    brand_items: dict[str, Counter] = defaultdict(Counter)
    brand_scans: dict[str, Counter] = defaultdict(Counter)
    brand_total: Counter = Counter()
    # (lang, term) → Counter(item_id): distinct-product counts for name mining.
    name_items: dict[tuple[str, str], Counter] = defaultdict(Counter)

    for brands, tags, pname, gname, n in rows:
        item_id = resolve(tags)

        if brands and len(brands) > 1:
            b = norm_brand(brands.split(",")[0])  # primary brand
            if not (len(b) < 3 or b in BRAND_STOPLIST or b in BRAND_EXCLUDE):
                brand_total[b] += 1
                if item_id:
                    brand_items[b][item_id] += 1
                    brand_scans[b][item_id] += n or 0

        if item_id:
            brand_toks: set[str] = set()
            if brands:
                for bb in brands.split(","):
                    brand_toks.update(norm_brand(bb).split())
            # Dedupe per product so generic_name + product_name yielding the
            # same term counts the product once.
            seen: set[tuple[str, str]] = set()
            for struct in (gname, pname):
                for entry in (struct or []):
                    if not isinstance(entry, dict):
                        continue
                    lang, txt = entry.get("lang"), entry.get("text")
                    if lang not in NAME_LANGS or not txt:
                        continue
                    term = clean_name(txt, brand_toks)
                    if term:
                        seen.add((lang, term))
            for key in seen:
                name_items[key][item_id] += 1

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

    # name terms → per-language aliases (novelty-guarded).
    name_review: list[tuple] = []
    for (lang, term), items in name_items.items():
        total = sum(items.values())
        item_id, top = items.most_common(1)[0]
        share = top / total
        if not (top >= NAME_MIN_PRODUCTS and share >= NAME_MIN_SHARE
                and len(items) <= NAME_MAX_ITEMS):
            continue
        # Novelty guard: skip any term the seed already owns (same item =
        # redundant; different item = decoy). Only genuinely new vocabulary.
        if seed_idx.get(_seed_norm(term)):
            continue
        aliases[item_id].setdefault(lang, []).append(term)
        name_review.append((term, lang, item_id, id_to_name[item_id], top,
                            round(share, 2), len(items)))

    # de-dup + sort aliases (brand "und" + per-language name terms) for stable output
    out_items = {}
    for item_id, langs in aliases.items():
        cleaned: dict[str, list[str]] = {}
        for lang, terms in langs.items():
            uniq = sorted(set(terms))
            if uniq:
                cleaned[lang] = uniq
        if cleaned:
            out_items[item_id] = cleaned

    payload = {"_attribution": OFF_ATTRIBUTION, "_license": "ODbL-1.0",
               "_generator": "off_ground.py", "version": OFF_VERSION,
               "items": out_items}
    pathlib.Path(args.out_aliases).write_text(
        json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")

    review.sort(key=lambda r: -r[5])  # by scans desc
    with open(args.out_review, "w", encoding="utf-8") as fh:
        fh.write("brand\titem_id\titem_name\tproducts\tbrand_total\tscans"
                 "\tcoverage\tshare\n")
        for r in review:
            fh.write("\t".join(str(x) for x in r) + "\n")

    name_review.sort(key=lambda r: (r[2], r[1], -r[4]))  # item, lang, count
    with open(args.out_name_review, "w", encoding="utf-8") as fh:
        fh.write("term\tlang\titem_id\titem_name\tproducts\tshare\titems\n")
        for r in name_review:
            fh.write("\t".join(str(x) for x in r) + "\n")

    n_brand = sum(len(v.get("und", [])) for v in out_items.values())
    n_name = sum(len(t) for v in out_items.values()
                 for k, t in v.items() if k != "und")
    print(f"[off_ground] {n_brand} brand + {n_name} name aliases "
          f"across {len(out_items)} items.")
    print(f"[off_ground] wrote {args.out_aliases}")
    print(f"[off_ground] wrote {args.out_review}, {args.out_name_review}")


if __name__ == "__main__":
    main()
