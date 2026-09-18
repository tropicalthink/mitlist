#!/usr/bin/env python3
"""Download the on-device OCR models that are deliberately not in git.

The two PP-OCRv6 ONNX graphs (~82 MB together) are published as release
assets rather than committed, so clones stay small. This script fetches them
into frontend/assets/models/ocr/ and verifies their SHA-256 before the build
bundles them. Run it once after cloning and again whenever MODELS change.

    cd frontend && python tool/fetch_ocr_models.py

Override the download location with MITLIST_OCR_MODELS_URL (a base URL that
serves the file names listed below) or --base-url. Nothing else is needed:
no auth, no extra dependencies.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
import urllib.request
from pathlib import Path

DEFAULT_BASE_URL = (
    os.environ.get("MITLIST_OCR_MODELS_URL")
    or "https://github.com/atropicalthink/mitlist/releases/download/ocr-models-v1"
)

# (published file name, destination relative to frontend/, size, sha256)
MODELS = [
    (
        "ppocrv6_small_det.inference.onnx",
        Path("assets/models/ocr/ppocrv6_small_det/inference.onnx"),
        9880512,
        "d73e0058b7a8086bbd57f3d10b8bcd4ff95363f67e06e2762b5e814fe9c9410e",
    ),
    (
        "ppocrv6_medium_rec.inference.onnx",
        Path("assets/models/ocr/ppocrv6_medium_rec/inference.onnx"),
        76554979,
        "9c09abf0957f7968c7586464b7397b84ad2387a0497a351af40e9acc71b673ba",
    ),
]


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, dest: Path) -> None:
    tmp = dest.with_suffix(dest.suffix + ".part")
    dest.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "mitlist-fetch-ocr-models"})
    with urllib.request.urlopen(request) as response, tmp.open("wb") as out:
        total = response.length or 0
        done = 0
        for chunk in iter(lambda: response.read(1 << 20), b""):
            out.write(chunk)
            done += len(chunk)
            if total:
                print(f"\r  {dest.name}: {done * 100 // total:3d}%", end="", flush=True)
    print()
    tmp.replace(dest)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--force", action="store_true", help="re-download even if the file verifies")
    args = parser.parse_args()

    frontend_dir = Path(__file__).resolve().parent.parent
    failures = 0
    for name, rel, size, digest in MODELS:
        dest = frontend_dir / rel
        if dest.exists() and not args.force and dest.stat().st_size == size and sha256_of(dest) == digest:
            print(f"ok       {rel}")
            continue
        url = f"{args.base_url.rstrip('/')}/{name}"
        print(f"fetching {rel}\n  from {url}")
        try:
            download(url, dest)
        except Exception as exc:  # noqa: BLE001 - report and keep going
            print(f"  FAILED: {exc}", file=sys.stderr)
            failures += 1
            continue
        actual = sha256_of(dest)
        if actual != digest:
            print(f"  FAILED: sha256 mismatch\n    want {digest}\n    got  {actual}", file=sys.stderr)
            dest.unlink(missing_ok=True)
            failures += 1
            continue
        print(f"verified {rel}")

    if failures:
        print(f"{failures} model(s) missing; the scanner will not work in this build.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
