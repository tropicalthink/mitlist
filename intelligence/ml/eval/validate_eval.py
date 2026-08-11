#!/usr/bin/env python3
"""Integrity check for `resolution_eval.jsonl` (and miner candidate files).

The eval set is both the scoreboard and the training labels for the calibrated
scorer, so a malformed row does not fail loudly — it quietly moves the number
the ship gate reads. This is the check that makes that impossible.

Exits non-zero on any violation, so it can gate CI or a pre-merge review:

    python3 intelligence/ml/eval/validate_eval.py
    python3 intelligence/ml/eval/validate_eval.py intelligence/ml/data/resolution_eval_candidates.jsonl

Checks:
  * every line is one JSON object
  * required fields present and correctly typed (`raw_text`,
    `expected_canonical_id`, `input_type`)
  * `input_type` is `print` or `handwriting` — the two are scored separately
  * `expected_canonical_id`, and every id in `list_context` /
    `household_purchases`, exists in `seed.json`
  * no `raw_text` appears twice with different `expected_canonical_id`
    (a contradictory label), and exact duplicates are reported
  * unrecognised keys are reported (they are ignored by the Dart harness, so
    this is a warning, not a failure — `source` / `correction_id` are expected
    on mined rows)

Warnings never change the exit code.
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

DEFAULT_PATH = ML / "data" / "resolution_eval.jsonl"
DEFAULT_SEED = REPO / "frontend" / "assets" / "grocery" / "seed.json"

REQUIRED = ("raw_text", "expected_canonical_id")
INPUT_TYPES = ("print", "handwriting")
ID_LISTS = ("list_context", "household_purchases")
# `source` / `correction_id` are the miner's provenance extras; the Dart
# `ResolutionEvalCase.fromJson` reads named fields only and ignores the rest.
KNOWN_KEYS = {
    "raw_text",
    "expected_canonical_id",
    "input_type",
    "note",
    "list_context",
    "household_purchases",
    "source",
    "correction_id",
}


def normalise(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().lower()) if s else ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("path", nargs="?", type=Path, default=DEFAULT_PATH)
    ap.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    args = ap.parse_args()

    if not args.path.exists():
        print(f"FAIL: {args.path} does not exist")
        return 1

    seed_ids = {it["id"] for it in
                json.loads(args.seed.read_text(encoding="utf-8"))["items"]}

    errors: list[str] = []
    warnings: list[str] = []
    by_type: collections.Counter = collections.Counter()
    by_source: collections.Counter = collections.Counter()
    text_to_ids: dict[str, set[str]] = collections.defaultdict(set)
    text_counts: collections.Counter = collections.Counter()
    unknown_keys: collections.Counter = collections.Counter()
    rows = 0

    for lineno, line in enumerate(
            args.path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.strip()
        if not line:
            continue
        rows += 1
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"line {lineno}: not valid JSON ({exc.msg})")
            continue
        if not isinstance(row, dict):
            errors.append(f"line {lineno}: expected a JSON object")
            continue

        for field in REQUIRED:
            value = row.get(field)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"line {lineno}: {field} missing or not a non-empty string")

        input_type = row.get("input_type", "print")
        if input_type not in INPUT_TYPES:
            errors.append(
                f"line {lineno}: input_type {input_type!r} not in {INPUT_TYPES}")
        else:
            by_type[input_type] += 1

        expected = row.get("expected_canonical_id")
        if isinstance(expected, str) and expected not in seed_ids:
            errors.append(
                f"line {lineno}: expected_canonical_id {expected!r} is not in seed.json")

        for field in ID_LISTS:
            value = row.get(field, [])
            if not isinstance(value, list):
                errors.append(f"line {lineno}: {field} must be a list")
                continue
            for cid in value:
                if not isinstance(cid, str):
                    errors.append(f"line {lineno}: {field} contains a non-string")
                elif cid not in seed_ids:
                    errors.append(
                        f"line {lineno}: {field} id {cid!r} is not in seed.json")

        note = row.get("note")
        if note is not None and not isinstance(note, str):
            errors.append(f"line {lineno}: note must be a string")

        for key in row:
            if key not in KNOWN_KEYS:
                unknown_keys[key] += 1

        if isinstance(row.get("raw_text"), str) and isinstance(expected, str):
            key = normalise(row["raw_text"])
            text_to_ids[key].add(expected)
            text_counts[key] += 1

        by_source[row.get("source", "curated")] += 1

    for text, ids in sorted(text_to_ids.items()):
        if len(ids) > 1:
            errors.append(
                f"raw_text {text!r} is labelled with conflicting ids: "
                f"{sorted(ids)}")
        elif text_counts[text] > 1:
            warnings.append(f"raw_text {text!r} appears {text_counts[text]} times")

    for key, count in sorted(unknown_keys.items()):
        warnings.append(f"unrecognised key {key!r} on {count} row(s) (ignored by the harness)")

    print(f"{args.path}: {rows} rows")
    if by_type:
        print("  by input_type: " +
              ", ".join(f"{k}={v}" for k, v in sorted(by_type.items())))
    if by_source:
        print("  by source    : " +
              ", ".join(f"{k}={v}" for k, v in sorted(by_source.items())))

    for warning in warnings:
        print(f"  WARN: {warning}")
    for error in errors:
        print(f"  FAIL: {error}")

    if errors:
        print(f"\n{len(errors)} violation(s)")
        return 1
    print("\nok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
