#!/usr/bin/env python3
"""Build a writer-disjoint PaddleOCR recognition dataset from app exports."""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import shutil
import sys
import tempfile
import unicodedata
import zipfile
from collections import Counter
from contextlib import ExitStack
from pathlib import Path
from typing import Any, Iterable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input",
        action="append",
        required=True,
        type=Path,
        help="An exported ZIP or extracted export directory; repeat per writer.",
    )
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--characters-json",
        type=Path,
        default=Path("assets/models/ocr/ppocrv6_medium_rec/characters.json"),
    )
    parser.add_argument("--validation-fraction", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=20260721)
    parser.add_argument("--minimum-lines", type=int, default=1000)
    parser.add_argument("--minimum-writers", type=int, default=5)
    parser.add_argument(
        "--allow-small",
        action="store_true",
        help="Build a development dataset below the production quality gate.",
    )
    return parser.parse_args()


def safe_extract(source: Path, destination: Path) -> Path:
    if source.is_dir():
        return source
    if not zipfile.is_zipfile(source):
        raise ValueError(f"Not an export directory or ZIP: {source}")
    destination.mkdir(parents=True)
    root = destination.resolve()
    with zipfile.ZipFile(source) as archive:
        for member in archive.infolist():
            target = (destination / member.filename).resolve()
            if root != target and root not in target.parents:
                raise ValueError(f"Unsafe archive member: {member.filename}")
        archive.extractall(destination)
    return destination


def find_manifest(root: Path) -> Path:
    direct = root / "samples.jsonl"
    if direct.is_file():
        return direct
    matches = list(root.rglob("samples.jsonl"))
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one samples.jsonl under {root}")
    return matches[0]


def clean_label(value: Any) -> str:
    label = unicodedata.normalize("NFC", str(value))
    label = " ".join(label.replace("\t", " ").splitlines()).strip()
    return " ".join(label.split())


def read_samples(roots: Iterable[Path]) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    seen_content: set[str] = set()
    for root in roots:
        manifest = find_manifest(root)
        export_root = manifest.parent
        with manifest.open(encoding="utf-8") as handle:
            for line_number, line in enumerate(handle, start=1):
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                    writer_id = str(record["writer_id"]).strip()
                    image_path = (export_root / str(record["image"])).resolve()
                    label = clean_label(record["label"])
                except (KeyError, TypeError, json.JSONDecodeError) as error:
                    raise ValueError(f"Invalid {manifest}:{line_number}: {error}") from error
                if not writer_id or not label or len(label) > 96:
                    raise ValueError(f"Invalid writer or label at {manifest}:{line_number}")
                resolved_root = export_root.resolve()
                if (
                    resolved_root != image_path
                    and resolved_root not in image_path.parents
                ):
                    raise ValueError(
                        f"Crop escapes export directory at {manifest}:{line_number}"
                    )
                if not image_path.is_file() or image_path.stat().st_size == 0:
                    raise ValueError(f"Missing crop at {manifest}:{line_number}: {image_path}")
                image_bytes = image_path.read_bytes()
                digest = hashlib.sha256(image_bytes + b"\0" + label.encode()).hexdigest()
                if digest in seen_content:
                    continue
                seen_content.add(digest)
                samples.append(
                    {
                        "id": str(record.get("id") or digest[:24]),
                        "writer_id": writer_id,
                        "label": label,
                        "raw_ocr": clean_label(record.get("raw_ocr", "")),
                        "source": image_path,
                        "digest": digest,
                    }
                )
    return samples


def choose_validation_writers(
    samples: list[dict[str, Any]], fraction: float, seed: int
) -> set[str]:
    writers = sorted({sample["writer_id"] for sample in samples})
    if len(writers) < 2:
        raise ValueError(
            "At least two writer IDs are required for writer-disjoint validation."
        )
    random.Random(seed).shuffle(writers)
    counts = Counter(sample["writer_id"] for sample in samples)
    target = max(1, round(len(samples) * fraction))
    validation: set[str] = set()
    validation_lines = 0
    for writer in writers:
        if len(validation) >= len(writers) - 1:
            break
        validation.add(writer)
        validation_lines += counts[writer]
        if validation_lines >= target:
            break
    return validation


def write_dataset(
    output: Path,
    samples: list[dict[str, Any]],
    validation_writers: set[str],
    characters: list[str],
    seed: int,
) -> dict[str, Any]:
    if output.exists():
        raise ValueError(f"Output already exists; choose a new path: {output}")
    known = set(characters)
    unknown = sorted(
        {
            char
            for sample in samples
            for char in sample["label"]
            if char != " " and char not in known
        }
    )
    if unknown:
        rendered = " ".join(f"U+{ord(char):04X} {char!r}" for char in unknown)
        raise ValueError(
            f"Labels contain characters absent from the app dictionary: {rendered}"
        )
    images = output / "images"
    images.mkdir(parents=True)
    random.Random(seed).shuffle(samples)

    split_lines: dict[str, list[str]] = {"train": [], "val": []}
    split_counts: Counter[str] = Counter()
    writer_counts: Counter[str] = Counter()
    audit = (output / "samples.jsonl").open("w", encoding="utf-8")
    try:
        for index, sample in enumerate(samples):
            split = "val" if sample["writer_id"] in validation_writers else "train"
            suffix = sample["source"].suffix.lower() or ".jpg"
            filename = f"{index:06d}_{sample['digest'][:12]}{suffix}"
            relative = Path("images") / filename
            shutil.copyfile(sample["source"], output / relative)
            split_lines[split].append(f"{relative.as_posix()}\t{sample['label']}")
            split_counts[split] += 1
            writer_counts[sample["writer_id"]] += 1
            audit.write(
                json.dumps(
                    {
                        "image": relative.as_posix(),
                        "label": sample["label"],
                        "raw_ocr": sample["raw_ocr"],
                        "writer_id": sample["writer_id"],
                        "split": split,
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
    finally:
        audit.close()

    for split, lines in split_lines.items():
        (output / f"{split}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (output / "character_dict.txt").write_text(
        "\n".join(characters) + "\n", encoding="utf-8"
    )
    report = {
        "schema_version": 1,
        "total_lines": len(samples),
        "train_lines": split_counts["train"],
        "validation_lines": split_counts["val"],
        "writer_count": len(writer_counts),
        "training_writers": sorted(set(writer_counts) - validation_writers),
        "validation_writers": sorted(validation_writers),
        "writer_line_counts": dict(sorted(writer_counts.items())),
        "seed": seed,
    }
    (output / "dataset_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return report


def main() -> int:
    args = parse_args()
    if not 0 < args.validation_fraction < 1:
        raise ValueError("--validation-fraction must be between zero and one")
    characters = json.loads(args.characters_json.read_text(encoding="utf-8"))
    if not isinstance(characters, list) or not all(
        isinstance(character, str) for character in characters
    ):
        raise ValueError("Character JSON must contain a list of strings")

    with ExitStack() as stack:
        roots: list[Path] = []
        for index, source in enumerate(args.input):
            temporary = Path(stack.enter_context(tempfile.TemporaryDirectory()))
            roots.append(safe_extract(source, temporary / f"export_{index}"))
        samples = read_samples(roots)
        if len(samples) < args.minimum_lines and not args.allow_small:
            raise ValueError(
                f"Only {len(samples)} unique lines; production gate is "
                f"{args.minimum_lines}. Use --allow-small only to test the pipeline."
            )
        writer_count = len({sample["writer_id"] for sample in samples})
        if writer_count < args.minimum_writers and not args.allow_small:
            raise ValueError(
                f"Only {writer_count} writers; production gate is "
                f"{args.minimum_writers}. Use --allow-small only to test the pipeline."
            )
        validation_writers = choose_validation_writers(
            samples, args.validation_fraction, args.seed
        )
        report = write_dataset(
            args.output, samples, validation_writers, characters, args.seed
        )
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)
