#!/usr/bin/env python3
"""Benchmark official PP-OCRv6 ONNX models against the private OCR corpus.

This is a host-side candidate evaluator, not production inference code. It uses
PaddleOCR's reference pre/post-processing so that we can decide whether an ONNX
model pair is worth integrating into Flutter before adding a mobile runtime.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--det-model-dir", type=Path, required=True)
    parser.add_argument("--rec-model-dir", type=Path, required=True)
    parser.add_argument(
        "--det-model-name",
        default="PP-OCRv6_small_det",
        choices=("PP-OCRv6_small_det", "PP-OCRv6_medium_det"),
    )
    parser.add_argument(
        "--rec-model-name",
        default="PP-OCRv6_medium_rec",
        choices=("PP-OCRv6_small_rec", "PP-OCRv6_medium_rec"),
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=Path("/tmp/mitlist-paddlex-cache"),
    )
    parser.add_argument("--det-thresh", type=float, default=0.2)
    parser.add_argument("--det-box-thresh", type=float, default=0.45)
    parser.add_argument("--det-unclip-ratio", type=float, default=1.4)
    return parser.parse_args()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _polygon_bbox(points: list[list[int]]) -> dict[str, float]:
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    left = min(xs)
    top = min(ys)
    return {
        "left": float(left),
        "top": float(top),
        "width": float(max(xs) - left),
        "height": float(max(ys) - top),
    }


def main() -> int:
    args = _arguments()
    args.cache_dir.mkdir(parents=True, exist_ok=True)
    # PaddleX reads this while importing, so set it before importing PaddleOCR.
    os.environ["PADDLE_PDX_CACHE_HOME"] = str(args.cache_dir.resolve())

    try:
        from paddleocr import PaddleOCR
    except ImportError as error:
        print(
            "Missing benchmark dependency. Install paddleocr and onnxruntime "
            "in an isolated Python environment.",
            file=sys.stderr,
        )
        print(error, file=sys.stderr)
        return 69

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    det_model = args.det_model_dir / "inference.onnx"
    rec_model = args.rec_model_dir / "inference.onnx"
    for required in (det_model, rec_model):
        if not required.is_file():
            print(f"Missing model: {required}", file=sys.stderr)
            return 66

    ocr = PaddleOCR(
        text_detection_model_name=args.det_model_name,
        text_detection_model_dir=str(args.det_model_dir.resolve()),
        text_recognition_model_name=args.rec_model_name,
        text_recognition_model_dir=str(args.rec_model_dir.resolve()),
        use_doc_orientation_classify=False,
        use_doc_unwarping=False,
        use_textline_orientation=False,
        text_det_thresh=args.det_thresh,
        text_det_box_thresh=args.det_box_thresh,
        text_det_unclip_ratio=args.det_unclip_ratio,
        text_rec_score_thresh=0.0,
        engine="onnxruntime",
        device="cpu",
    )

    samples: list[dict[str, object]] = []
    for sample in manifest["samples"]:
        source = args.samples_dir / sample["filename"]
        started = time.perf_counter()
        try:
            predictions = list(ocr.predict(str(source.resolve())))
            elapsed_ms = (time.perf_counter() - started) * 1000
            if len(predictions) != 1:
                raise RuntimeError(
                    f"Expected one OCR result for {source}, got {len(predictions)}"
                )
            result = predictions[0].json["res"]
            texts = result.get("rec_texts", [])
            scores = result.get("rec_scores", [])
            polygons = result.get("rec_polys", [])
            lines = []
            for text, score, polygon in zip(texts, scores, polygons, strict=True):
                points = [[int(x), int(y)] for x, y in polygon]
                lines.append(
                    {
                        "text": text,
                        "confidence": float(score),
                        # PP-OCR does not classify checks or strikethroughs.
                        "mark_status": "normal",
                        "bbox": _polygon_bbox(points),
                        "polygon": points,
                    }
                )
            samples.append(
                {
                    "id": sample["id"],
                    "filename": sample["filename"],
                    "input_type": sample["input_type"],
                    "latency_ms": round(elapsed_ms, 3),
                    "preprocessing": "paddleocr_reference_onnx",
                    "source_bytes": source.stat().st_size,
                    "lines": lines,
                }
            )
            print(
                f"{sample['id']}: {elapsed_ms:.1f} ms, {len(lines)} lines: "
                + " | ".join(line["text"] for line in lines)
            )
        except Exception as error:  # Preserve partial results for diagnosis.
            elapsed_ms = (time.perf_counter() - started) * 1000
            samples.append(
                {
                    "id": sample["id"],
                    "filename": sample["filename"],
                    "input_type": sample["input_type"],
                    "latency_ms": round(elapsed_ms, 3),
                    "preprocessing": "paddleocr_reference_onnx",
                    "lines": [],
                    "error": f"{type(error).__name__}: {error}",
                }
            )
            print(f"{sample['id']}: {error}", file=sys.stderr)

    document = {
        "schema_version": 1,
        "backend": (
            f"ppocrv6_{args.det_model_name.removeprefix('PP-OCRv6_')}_"
            f"{args.rec_model_name.removeprefix('PP-OCRv6_')}_onnx_reference"
        ),
        "models": {
            "detector": {
                "name": f"PaddlePaddle/{args.det_model_name}_onnx",
                "sha256": _sha256(det_model),
            },
            "recognizer": {
                "name": f"PaddlePaddle/{args.rec_model_name}_onnx",
                "sha256": _sha256(rec_model),
            },
        },
        "settings": {
            "det_thresh": args.det_thresh,
            "det_box_thresh": args.det_box_thresh,
            "det_unclip_ratio": args.det_unclip_ratio,
            "orientation_classification": False,
            "document_unwarping": False,
            "textline_orientation": False,
        },
        "samples": samples,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(document, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Raw results: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
