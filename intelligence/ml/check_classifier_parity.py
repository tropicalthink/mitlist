#!/usr/bin/env python3
"""Check that classifier labels still resolve against the shipped grocery seed.

The current classifier predicts display names. The app maps those names back to
canonical items via the alias table, so renamed seed entries can silently orphan
classifier votes. The next retrain should emit canonical ids as labels instead,
which removes this class of drift entirely.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LABELS = REPO_ROOT / "frontend/assets/models/grocery_classifier_labels.txt"
DEFAULT_SEED = REPO_ROOT / "frontend/assets/grocery/seed.json"
DEFAULT_THRESHOLD = 0.02
LANGS = ("de", "en", "fr", "es")


def normalise_text(value: str) -> str:
    # Keep this aligned with frontend/lib/services/scan/resolution/string_sim.dart:7-8.
    return " ".join(value.lower().strip().split())


def load_labels(path: Path) -> list[str]:
    if not path.exists():
        raise FileNotFoundError(f"labels file not found: {path}")
    return [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def load_seed(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(f"seed file not found: {path}")

    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)

    items = payload.get("items") if isinstance(payload, dict) else None
    if not isinstance(items, list):
        raise ValueError(f"seed must be an object with an items list: {path}")

    for index, item in enumerate(items):
        if not isinstance(item, dict):
            raise ValueError(f"seed item #{index} is not an object")
        for lang in LANGS:
            name_key = f"name_{lang}"
            aliases_key = f"aliases_{lang}"
            if not isinstance(item.get(name_key), str):
                raise ValueError(f"seed item #{index} missing string {name_key}")
            if not isinstance(item.get(aliases_key), list):
                raise ValueError(f"seed item #{index} missing list {aliases_key}")

    return items


def build_resolvable_aliases(items: list[dict[str, Any]]) -> set[str]:
    aliases: set[str] = set()
    for item in items:
        for lang in LANGS:
            aliases.add(normalise_text(item[f"name_{lang}"]))
            for alias in item[f"aliases_{lang}"]:
                if isinstance(alias, str):
                    aliases.add(normalise_text(alias))
    aliases.discard("")
    return aliases


def check(labels_path: Path, seed_path: Path, threshold: float) -> int:
    labels = load_labels(labels_path)
    items = load_seed(seed_path)
    resolvable_aliases = build_resolvable_aliases(items)
    normalised_labels = [normalise_text(label) for label in labels]
    label_set = set(normalised_labels)

    orphaned = [
        label
        for label, normalised in zip(labels, normalised_labels)
        if normalised not in resolvable_aliases
    ]
    uncovered = [
        item
        for item in items
        if normalise_text(item["name_de"]) not in label_set
    ]

    total = len(labels)
    orphan_rate = len(orphaned) / total if total else 1.0

    print("Classifier/seed parity")
    print(f"  labels: {total}")
    print(f"  seed items: {len(items)}")
    print(f"  resolvable aliases: {len(resolvable_aliases)}")
    print(f"  orphaned labels: {len(orphaned)} ({orphan_rate:.2%})")
    if orphaned:
        print("  orphan examples:")
        for label in orphaned[:20]:
            print(f"    - {label}")
    print(f"  uncovered seed items: {len(uncovered)}")
    print(f"  threshold: {threshold:.2%}")

    if orphan_rate > threshold:
        print(
            f"FAIL: orphan rate {orphan_rate:.2%} exceeds threshold {threshold:.2%}",
            file=sys.stderr,
        )
        return 1

    print(f"PASS: orphan rate {orphan_rate:.2%} is within threshold {threshold:.2%}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--labels",
        type=Path,
        default=DEFAULT_LABELS,
        help=f"classifier labels file (default: {DEFAULT_LABELS.relative_to(REPO_ROOT)})",
    )
    parser.add_argument(
        "--seed",
        type=Path,
        default=DEFAULT_SEED,
        help=f"grocery seed file (default: {DEFAULT_SEED.relative_to(REPO_ROOT)})",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_THRESHOLD,
        help="maximum allowed orphan label rate before failing",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return check(args.labels.resolve(), args.seed.resolve(), args.threshold)


if __name__ == "__main__":
    raise SystemExit(main())
