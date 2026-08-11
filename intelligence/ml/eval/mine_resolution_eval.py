#!/usr/bin/env python3
"""corrections → resolution-eval candidate miner.

`intelligence/ml/data/resolution_eval.jsonl` is the ground truth the resolution
engine is scored against and the labels the calibrated scorer is fitted on. It
has 65 hand-curated rows — far too few for a fit that beats the hand-set
`CalibratedScorer` defaults (see `plans/006-ship-calibrated-weights.md`: the
fitted bundle currently loses on held-out coverage, 0.368 vs 0.526, so the ship
gate correctly keeps it out of the app).

Meanwhile `corrections.jsonl` holds 39,412 OCR-correction rows whose
`correct_canonical_{en,de,fr,es}` fields are DISPLAY NAMES ("Mozzarella"), not
seed ids ("mozzarella"). This script does that mapping and emits reviewable
eval-row candidates.

**Output is a candidate file, never the eval set.** Labels that are merely
plausible poison the metric they are supposed to protect, so the maintainer
reviews `data/resolution_eval_candidates.jsonl` and moves rows into
`data/resolution_eval.jsonl` by hand. Nothing here writes the eval set.

Ground-truth bar — a row is emitted only when all of these hold:

  1. The display name maps to EXACTLY ONE seed id. The alias miner
     (`ml/mine_corrections_aliases.py`) breaks collisions with
     `sorted(candidates)[0]`; that is fine for alias suggestions under review
     and wrong for labels, so ambiguity is skipped here instead.
  2. At least `--min-language-agreement` (default 2) of the row's four display
     names independently resolve to that SAME id, and none resolves to another.
     One match is not evidence: the corpus row `{en: "Bread", fr: "Pain"}` means
     bread, but no seed item is named "Bread" while `bread_roll.name_fr` is
     exactly "Pain" — a lone French match would label bread as bread_roll.
  3. `correct_canonical_*` is a string. List-valued rows (COMPOUND_SPLIT_MERGE)
     describe several items; the harness scores one id per row.
  4. The normalised `raw_ocr` maps to ONE id across the whole corpus. A word
     labelled two ways is context-dependent, and corrections rows carry no
     list/household context, so it cannot be an eval row.

Known limits, by construction:

  * **`input_type` is always `print`.** These are OCR corrections; the corpus
    carries no handwriting signal. The handwriting half of the eval set cannot
    be grown from this source.
  * **Mined rows carry no prior.** `list_context` and `household_purchases` are
    empty, so `householdFreq` / `listCooccurrence` export as 0. That is why the
    output is capped (`--limit`, default 300) — thousands of zero-prior rows
    would swamp the hand-curated rows that give those features any signal.
  * **The corpus is generated, not observed.** Rows come from the
    `intelligence/generator` pipeline. They are a volume starter; real scanned
    lists remain the destination (`eval/resolution_eval.schema.md`).

Leakage guard: the alias miners read the same corrections rows. An alias mined
from row X and merged into the seed turns row X into a trivial exact-alias hit
and inflates precision. These rows are **kept and flagged**, not dropped — an
alias candidate is by definition text that is *not yet* an alias, so they are
precisely the non-trivial rows (excluding them costs ~95% of the useful yield).
Every emitted row carries its `correction_id`, and overlapping rows say so in
their `note`: merge the eval row or its alias twin, never both.
`--exclude-alias-overlap` drops them if you want the conservative set.

Usage:
    python3 intelligence/ml/eval/mine_resolution_eval.py [--limit 300]
"""
from __future__ import annotations

import argparse
import collections
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ML = HERE.parent
REPO = ML.parent.parent

DEFAULT_CORRECTIONS = ML / "data" / "corrections.jsonl"
DEFAULT_SEED = REPO / "frontend" / "assets" / "grocery" / "seed.json"
DEFAULT_EXISTING = ML / "data" / "resolution_eval.jsonl"
DEFAULT_OUT = ML / "data" / "resolution_eval_candidates.jsonl"

# Alias-candidate files mined from the SAME corrections corpus; see the
# leakage note in the module docstring.
ALIAS_FILES = [
    ML / "data" / "corrections_alias_candidates.jsonl",
    ML / "data" / "corrections_alias_candidates.filtered.jsonl",
    ML / "data" / "curated_aliases_mined.jsonl",
    ML / "data" / "curated_aliases.jsonl",
]

NAME_FIELDS = ("name_en", "name_de", "name_fr", "name_es")
ALIAS_FIELDS = ("aliases_en", "aliases_de", "aliases_fr", "aliases_es")
CANONICAL_FIELDS = (
    "correct_canonical_en",
    "correct_canonical_de",
    "correct_canonical_fr",
    "correct_canonical_es",
)
LANGS = ("en", "de", "fr", "es")


def normalise(s: str) -> str:
    """Lowercase, strip, collapse internal whitespace.

    Matches `mine_corrections_aliases.normalise` so the two miners agree on what
    counts as the same text when the leakage guard compares them.
    """
    if not s:
        return ""
    return re.sub(r"\s+", " ", s.strip().lower())


def looks_noisy(s: str) -> bool:
    """True for text that should not become an eval row."""
    if len(s) < 2:
        return True
    if s.isdigit():
        return True
    if re.match(r"^[\W\d]+$", s, re.UNICODE):
        return True
    # Quantity-only strings ("2 kg", "500g") are measurements, not item names.
    if re.match(r"^\d+\s*(g|kg|ml|l|st|pcs?|stück|stk|x)\b", s, re.IGNORECASE):
        return True
    return False


class SeedIndex:
    """Display-name and alias lookups over `seed.json`."""

    def __init__(self, seed_path: Path):
        data = json.loads(seed_path.read_text(encoding="utf-8"))
        self.items = data["items"]
        self.ids = {it["id"] for it in self.items}
        # Normalised display name → the set of ids using it. A name shared by
        # two items is ambiguous and disqualifies the row.
        self.name_to_ids: dict[str, set[str]] = collections.defaultdict(set)
        # (id, normalised alias) pairs already in the shipped seed.
        self.alias_pairs: set[tuple[str, str]] = set()
        for item in self.items:
            iid = item["id"]
            for field in NAME_FIELDS:
                n = normalise(item.get(field, "") or "")
                if n:
                    self.name_to_ids[n].add(iid)
            for field in ALIAS_FIELDS:
                for alias in item.get(field, []) or []:
                    a = normalise(alias)
                    if a:
                        self.alias_pairs.add((iid, a))

    def resolve_unique(self, display_names: dict[str, str],
                       min_agreement: int) -> tuple[str | None, str, int]:
        """Maps a row's display names to one seed id.

        Returns `(id, "ok", n_languages_agreeing)`, or `(None, reason, 0)` when
        the row fails the ground-truth bar. `display_names` is lang → display
        string.

        A single language matching is not enough evidence. Seed display names
        collide across languages in ways that silently produce a *confident
        wrong* label: the corpus row `{en: "Bread", fr: "Pain"}` means bread, but
        no seed item is named "Bread" while `bread_roll.name_fr` is exactly
        "Pain" — so a lone French match labels bread as bread_roll. Requiring
        [min_agreement] languages to land on the same id turns that from a
        plausible label into a skip.
        """
        resolved: set[str] = set()
        agreeing = 0
        saw_name = False
        for lang in LANGS:
            name = normalise(display_names.get(lang, ""))
            if not name:
                continue
            saw_name = True
            ids = self.name_to_ids.get(name)
            if not ids:
                continue
            if len(ids) > 1:
                # One name, several seed items — no safe label.
                return None, "ambiguous_name", 0
            resolved |= ids
            agreeing += 1
        if not saw_name:
            return None, "no_canonical_field", 0
        if not resolved:
            return None, "unmappable", 0
        if len(resolved) > 1:
            # The languages disagree about which item this row is.
            return None, "cross_language_disagreement", 0
        if agreeing < min_agreement:
            return None, "weak_agreement", 0
        return next(iter(resolved)), "ok", agreeing


def load_alias_pairs(paths: list[Path]) -> set[tuple[str, str]]:
    """(canonical_id, normalised alias) pairs already proposed by an alias miner."""
    pairs: set[tuple[str, str]] = set()
    for path in paths:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            cid = row.get("canonical_id")
            alias = normalise(row.get("alias", "") or "")
            if cid and alias:
                pairs.add((cid, alias))
    return pairs


def load_existing_texts(path: Path) -> set[str]:
    """Normalised `raw_text` values already in the eval set."""
    texts: set[str] = set()
    if not path.exists():
        return texts
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        texts.add(normalise(row.get("raw_text", "") or ""))
    return texts


def collect(args, seed: SeedIndex, stats: collections.Counter) -> list[dict]:
    """First pass: every corrections row that clears the per-row bar."""
    collected: list[dict] = []
    with open(args.corrections, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            stats["total"] += 1
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                stats["skip_unparseable"] += 1
                continue

            raw_text = (row.get("raw_ocr") or "").strip()
            norm_text = normalise(raw_text)
            if not norm_text or looks_noisy(norm_text):
                stats["skip_noisy"] += 1
                continue

            # A small tail of rows carries drifted key names ("correct_canatic",
            # "was_first_gorrect", …) from the generator — a handful each, well
            # under 1% of the corpus. Exact-key access, skip, count.
            display: dict[str, str] = {}
            multi = False
            for lang, field in zip(LANGS, CANONICAL_FIELDS):
                value = row.get(field)
                if isinstance(value, list):
                    multi = True
                    break
                if isinstance(value, str) and value.strip():
                    display[lang] = value.strip()
            if multi:
                stats["skip_multi_canonical"] += 1
                continue

            seed_id, reason, agreeing = seed.resolve_unique(
                display, args.min_language_agreement)
            if seed_id is None:
                stats[f"skip_{reason}"] += 1
                continue

            collected.append(
                {
                    "agreeing": agreeing,
                    "correction_id": row.get("id"),
                    "raw_text": raw_text,
                    "norm_text": norm_text,
                    "canonical_id": seed_id,
                    "scenario": row.get("scenario") or "UNKNOWN",
                    "lang": (row.get("list_language") or "und").lower(),
                    "hard": row.get("was_first_guess_correct") is False,
                    "display": display,
                }
            )
            stats["mappable"] += 1
    return collected


def filter_rows(args, seed: SeedIndex, collected: list[dict],
                stats: collections.Counter) -> list[dict]:
    """Second pass: corpus-wide checks that need every row in hand."""
    # A normalised text labelled with two different ids is context-dependent.
    text_to_ids: dict[str, set[str]] = collections.defaultdict(set)
    for row in collected:
        text_to_ids[row["norm_text"]].add(row["canonical_id"])
    conflicting = {t for t, ids in text_to_ids.items() if len(ids) > 1}

    existing = load_existing_texts(args.existing)
    alias_pairs = load_alias_pairs(ALIAS_FILES)

    kept: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for row in collected:
        text, cid = row["norm_text"], row["canonical_id"]
        if text in conflicting:
            stats["skip_conflicting_label"] += 1
            continue
        if text in existing:
            stats["skip_already_in_eval"] += 1
            continue
        pair = (cid, text)
        if pair in seen:
            stats["skip_duplicate"] += 1
            continue
        overlap = pair in alias_pairs
        if overlap and args.exclude_alias_overlap:
            stats["skip_alias_overlap"] += 1
            continue
        seen.add(pair)

        # Rows whose text is already an exact seed name/alias resolve trivially;
        # they are legitimate but carry little signal, so their share is capped.
        if (cid, text) in seed.alias_pairs:
            trivial = "exact_alias"
        elif text in {normalise(v) for v in row["display"].values()}:
            trivial = "exact_name"
        else:
            trivial = ""
        row["trivial"] = trivial
        row["alias_overlap"] = overlap
        kept.append(row)
    return kept


def select(args, rows: list[dict], stats: collections.Counter) -> list[dict]:
    """Stratified, deterministic pick of at most `--limit` rows.

    Buckets are (scenario, lang, hard). Round-robin across buckets keeps every
    scenario and language represented instead of letting the corpus's own
    ordering decide, and the hard/easy split is filled to `--hard-ratio` so the
    rows the resolver actually gets wrong dominate.
    """
    trivial_cap = int(args.limit * args.max_trivial)
    hard_target = int(args.limit * args.hard_ratio)

    buckets: dict[tuple, list[dict]] = collections.defaultdict(list)
    for row in rows:
        buckets[(row["scenario"], row["lang"], row["hard"])].append(row)
    # Sort inside each bucket, and the bucket order itself, so reruns on an
    # unchanged corpus produce an identical file (no sampling randomness).
    for bucket in buckets.values():
        bucket.sort(key=lambda r: (str(r["correction_id"]), r["norm_text"]))
    order = sorted(buckets, key=lambda k: (not k[2], k[0], k[1]))

    picked: list[dict] = []
    trivial_used = 0
    hard_used = 0
    # One cursor per bucket for the whole selection, not per pass — the top-up
    # pass below revisits the hard buckets and must resume where the first pass
    # stopped rather than re-picking from the start.
    cursors_all = {k: 0 for k in order}

    def take(want_hard: bool, budget: int) -> None:
        nonlocal trivial_used, hard_used
        cursors = {k: v for k, v in cursors_all.items() if k[2] == want_hard}
        while budget > 0 and cursors:
            for key in list(cursors):
                if budget <= 0:
                    break
                bucket = buckets[key]
                idx = cursors[key]
                if idx >= len(bucket):
                    del cursors[key]
                    continue
                cursors[key] = cursors_all[key] = idx + 1
                row = bucket[idx]
                if row["trivial"]:
                    # Over the trivial budget: drop this row and move on. The
                    # bucket is not retired — its non-trivial rows come later.
                    if trivial_used >= trivial_cap:
                        continue
                    trivial_used += 1
                picked.append(row)
                budget -= 1
                hard_used += 1 if want_hard else 0

    take(True, min(hard_target, args.limit))
    take(False, args.limit - len(picked))
    # If easy rows ran out first, top up from whatever hard rows remain.
    if len(picked) < args.limit:
        take(True, args.limit - len(picked))

    stats["selected_hard"] = hard_used
    stats["selected_trivial"] = trivial_used
    return picked


def to_eval_row(row: dict) -> dict:
    """Shapes one candidate as an eval row (schema + provenance extras).

    `source` / `correction_id` are extra keys: `ResolutionEvalCase.fromJson`
    reads named fields only and ignores the rest, so a reviewed row can be moved
    into the eval set verbatim.
    """
    bits = [f"mined: {row['scenario'].lower()}", row["lang"]]
    bits.append("first guess wrong" if row["hard"] else "first guess correct")
    bits.append(f"{row['agreeing']}-language agreement")
    if row["trivial"]:
        bits.append(f"trivial/{row['trivial']}")
    if row["alias_overlap"]:
        bits.append("ALSO an alias candidate — merging both inflates precision")
    return {
        "raw_text": row["raw_text"],
        "expected_canonical_id": row["canonical_id"],
        "input_type": "print",
        "note": "; ".join(bits),
        "source": "corrections_miner",
        "correction_id": row["correction_id"],
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--corrections", type=Path, default=DEFAULT_CORRECTIONS)
    ap.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    ap.add_argument("--existing", type=Path, default=DEFAULT_EXISTING,
                    help="eval set to dedupe against (never written)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--limit", type=int, default=300,
                    help="max candidates to emit; keeps the review reviewable "
                         "and stops zero-prior rows swamping the curated set")
    ap.add_argument("--hard-ratio", type=float, default=0.7,
                    help="share of output taken from rows the system first got "
                         "wrong (was_first_guess_correct=false)")
    ap.add_argument("--max-trivial", type=float, default=0.15,
                    help="max share of rows whose text is already an exact seed "
                         "name/alias")
    ap.add_argument("--min-language-agreement", type=int, default=2,
                    help="how many of the row's four display names must "
                         "independently resolve to the same seed id; 1 admits "
                         "cross-language name collisions as confident wrong "
                         "labels (see SeedIndex.resolve_unique)")
    ap.add_argument("--exclude-alias-overlap", action="store_true",
                    help="drop rows that an alias miner also proposed. Off by "
                         "default: an alias candidate is by definition text "
                         "that is NOT yet an alias, so these are exactly the "
                         "non-trivial rows. They are kept and flagged in the "
                         "note instead — merge the eval row or its alias twin, "
                         "never both")
    args = ap.parse_args()

    if args.out.resolve() == args.existing.resolve():
        print("refusing to write the eval set; --out must be a candidate file")
        return 2

    stats: collections.Counter = collections.Counter()
    seed = SeedIndex(args.seed)
    print(f"seed: {len(seed.items)} items, "
          f"{len(seed.name_to_ids)} display-name keys, "
          f"{len(seed.alias_pairs)} alias pairs")

    collected = collect(args, seed, stats)
    kept = filter_rows(args, seed, collected, stats)
    picked = select(args, kept, stats)

    for row in picked:
        assert row["canonical_id"] in seed.ids, row["canonical_id"]

    args.out.write_text(
        "".join(json.dumps(to_eval_row(r), ensure_ascii=False) + "\n"
                for r in picked),
        encoding="utf-8",
    )

    print("\n=== miner statistics ===")
    labels = [
        ("total rows read", "total"),
        ("unparseable", "skip_unparseable"),
        ("noisy / short raw_ocr", "skip_noisy"),
        ("multi-canonical row", "skip_multi_canonical"),
        ("no canonical field (key drift)", "skip_no_canonical_field"),
        ("display name unmappable", "skip_unmappable"),
        ("display name ambiguous", "skip_ambiguous_name"),
        ("languages disagree", "skip_cross_language_disagreement"),
        ("only one language matched", "skip_weak_agreement"),
        ("mapped to one seed id", "mappable"),
        ("text labelled two ways", "skip_conflicting_label"),
        ("already in eval set", "skip_already_in_eval"),
        ("duplicate (id, text)", "skip_duplicate"),
        ("also an alias candidate (excluded)", "skip_alias_overlap"),
    ]
    for label, key in labels:
        print(f"  {label:<32}: {stats[key]}")
    print(f"  {'eligible after filters':<32}: {len(kept)}")

    # The number that decides how far this source can actually carry the eval
    # set. The seed already ships ~231k alias pairs, so most corrections texts
    # resolve by exact alias and teach the scorer nothing. Only the non-trivial
    # rows are worth curating, and there are far fewer of them than the corpus
    # size suggests — mining is a one-off top-up, not a faucet.
    pool = collections.Counter((r["hard"], bool(r["trivial"])) for r in kept)
    non_trivial = pool[(True, False)] + pool[(False, False)]
    print(f"  {'  of which non-trivial':<32}: {non_trivial} "
          f"({pool[(True, False)]} hard, {pool[(False, False)]} easy)")
    print(f"  {'  of which trivial (capped)':<32}: {len(kept) - non_trivial}")
    print(f"  {'emitted':<32}: {len(picked)} "
          f"({stats['selected_hard']} hard, {stats['selected_trivial']} trivial)")

    by_scenario = collections.Counter(r["scenario"] for r in picked)
    by_lang = collections.Counter(r["lang"] for r in picked)
    print("\n  by scenario: " + ", ".join(f"{k}={v}" for k, v in sorted(by_scenario.items())))
    print("  by language: " + ", ".join(f"{k}={v}" for k, v in sorted(by_lang.items())))

    print(f"\noutput -> {args.out}")
    print("GATE: these are CANDIDATES. Review each label, then move rows into")
    print("      data/resolution_eval.jsonl by hand. Do not auto-merge — and do")
    print("      not merge a row here and its alias twin in the alias-candidate")
    print("      files. Validate after merging:")
    print("      python3 intelligence/ml/eval/validate_eval.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
