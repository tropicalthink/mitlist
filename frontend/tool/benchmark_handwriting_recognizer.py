#!/usr/bin/env python3
"""Bake off a handwriting recognizer behind mitlist's PP-OCR detector.

This is host-only evaluation tooling. PyTorch, Transformers, OpenCV, and the
candidate checkpoint are never linked into the Flutter application. The
production constraint remains a bundled model executed by the shared ONNX
Runtime path on Android and iOS.

The script deliberately keeps detection fixed. It reproduces the portable Dart
detector preprocessing and connected-component post-processing, joins regions
on the same visual row into complete line crops, and sends only those crops to
the candidate handwriting recognizer. Results use the same JSON schema as the
existing OCR scorer.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import time
from typing import Any


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--det-model", type=Path, required=True)
    parser.add_argument(
        "--recognizer",
        default="microsoft/trocr-small-handwritten",
        help="Hugging Face checkpoint or local checkpoint directory",
    )
    parser.add_argument(
        "--recognizer-backend",
        choices=("transformers", "onnx_trocr"),
        default="transformers",
        help="Candidate runtime; onnx_trocr expects encoder_model.onnx and decoder_model.onnx",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--crops-dir",
        type=Path,
        help="Optional private diagnostics directory for detected line crops",
    )
    parser.add_argument("--detector-max-side", type=int, default=1600)
    parser.add_argument("--det-thresh", type=float, default=0.2)
    parser.add_argument("--det-box-thresh", type=float, default=0.45)
    parser.add_argument("--det-unclip-ratio", type=float, default=1.4)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--num-beams", type=int, default=4)
    parser.add_argument("--max-new-tokens", type=int, default=64)
    return parser.parse_args()


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_dependencies() -> dict[str, Any]:
    try:
        import cv2
        import numpy as np
        import onnxruntime as ort
        import torch
        from PIL import Image
        from transformers import (
            TrOCRProcessor,
            VisionEncoderDecoderConfig,
            VisionEncoderDecoderModel,
        )
    except ImportError as error:
        print(
            "Missing host benchmark dependencies. Use an isolated environment "
            "with torch, transformers, onnxruntime, opencv-python-headless, "
            "and pillow.",
            file=sys.stderr,
        )
        print(error, file=sys.stderr)
        raise SystemExit(69) from error
    return {
        "cv2": cv2,
        "np": np,
        "ort": ort,
        "torch": torch,
        "Image": Image,
        "TrOCRProcessor": TrOCRProcessor,
        "VisionEncoderDecoderConfig": VisionEncoderDecoderConfig,
        "VisionEncoderDecoderModel": VisionEncoderDecoderModel,
    }


def _detector_tensor(image: Any, *, max_side: int, cv2: Any, np: Any) -> Any:
    original_height, original_width = image.shape[:2]
    scale = min(1.0, max_side / max(original_width, original_height))
    width = max(32, round(original_width * scale / 32) * 32)
    height = max(32, round(original_height * scale / 32) * 32)
    resized = cv2.resize(image, (width, height), interpolation=cv2.INTER_LINEAR)
    normalized = resized.astype(np.float32) / 255.0
    # cv2 and the production Dart path both supply channels in BGR order.
    normalized -= np.asarray([0.485, 0.456, 0.406], dtype=np.float32)
    normalized /= np.asarray([0.229, 0.224, 0.225], dtype=np.float32)
    return normalized.transpose(2, 0, 1)[None, ...]


def _detector_regions(
    probability: Any,
    *,
    original_width: int,
    original_height: int,
    threshold: float,
    box_threshold: float,
    unclip_ratio: float,
    cv2: Any,
    np: Any,
) -> list[dict[str, Any]]:
    binary = (probability > threshold).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, 8)
    height, width = probability.shape
    scale_x = original_width / width
    scale_y = original_height / height
    regions: list[dict[str, Any]] = []
    for label in range(1, count):
        x, y, component_width, component_height, pixels = [
            int(value) for value in stats[label]
        ]
        if pixels < 10 or component_width < 3 or component_height < 3:
            continue
        score = float(probability[labels == label].mean())
        if score < box_threshold:
            continue
        area = float(component_width * component_height)
        perimeter = 2.0 * (component_width + component_height)
        expand = max(2.0, area * unclip_ratio / perimeter)
        left = max(0, min(original_width - 1, math.floor((x - expand) * scale_x)))
        top = max(0, min(original_height - 1, math.floor((y - expand) * scale_y)))
        right = max(
            left + 1,
            min(
                original_width,
                math.ceil((x + component_width + expand) * scale_x),
            ),
        )
        bottom = max(
            top + 1,
            min(
                original_height,
                math.ceil((y + component_height + expand) * scale_y),
            ),
        )
        if right - left >= 8 and bottom - top >= 8:
            regions.append(
                {
                    "left": left,
                    "top": top,
                    "right": right,
                    "bottom": bottom,
                    "score": score,
                }
            )
    return regions


def _center_y(region: dict[str, Any]) -> float:
    return (region["top"] + region["bottom"]) / 2.0


def _width(region: dict[str, Any]) -> int:
    return int(region["right"] - region["left"])


def _height(region: dict[str, Any]) -> int:
    return int(region["bottom"] - region["top"])


def _merge_line_regions(regions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    pending = sorted(regions, key=lambda region: (_center_y(region), region["left"]))
    groups: list[list[dict[str, Any]]] = []
    for region in pending:
        target = None
        for group in reversed(groups):
            total_width = sum(_width(item) for item in group)
            center = sum(_center_y(item) * _width(item) for item in group) / total_width
            min_height = min([_height(region), *[_height(item) for item in group]])
            if abs(_center_y(region) - center) <= min_height * 0.65:
                target = group
                break
        if target is None:
            target = []
            groups.append(target)
        target.append(region)

    merged = []
    for group in groups:
        merged.append(
            {
                "left": min(item["left"] for item in group),
                "top": min(item["top"] for item in group),
                "right": max(item["right"] for item in group),
                "bottom": max(item["bottom"] for item in group),
                "score": min(item["score"] for item in group),
            }
        )
    return sorted(merged, key=_center_y)


def _crop(image: Any, region: dict[str, Any]) -> Any:
    image_height, image_width = image.shape[:2]
    region_height = _height(region)
    vertical_pad = max(2, round(region_height * 0.08))
    horizontal_pad = max(2, round(region_height * 0.04))
    left = max(0, region["left"] - horizontal_pad)
    top = max(0, region["top"] - vertical_pad)
    right = min(image_width, region["right"] + horizontal_pad)
    bottom = min(image_height, region["bottom"] + vertical_pad)
    return image[top:bottom, left:right]


def _bbox(region: dict[str, Any]) -> dict[str, float]:
    return {
        "left": float(region["left"]),
        "top": float(region["top"]),
        "width": float(_width(region)),
        "height": float(_height(region)),
    }


def main() -> int:
    args = _arguments()
    dependencies = _load_dependencies()
    cv2 = dependencies["cv2"]
    np = dependencies["np"]
    ort = dependencies["ort"]
    torch = dependencies["torch"]
    Image = dependencies["Image"]
    TrOCRProcessor = dependencies["TrOCRProcessor"]
    VisionEncoderDecoderConfig = dependencies["VisionEncoderDecoderConfig"]
    VisionEncoderDecoderModel = dependencies["VisionEncoderDecoderModel"]

    if not args.det_model.is_file():
        print(f"Missing detector model: {args.det_model}", file=sys.stderr)
        return 66
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if args.crops_dir is not None:
        args.crops_dir.mkdir(parents=True, exist_ok=True)

    torch.set_num_threads(max(1, min(4, torch.get_num_threads())))
    detector = ort.InferenceSession(
        str(args.det_model.resolve()), providers=["CPUExecutionProvider"]
    )
    recognizer_path = Path(args.recognizer)
    if args.recognizer_backend == "transformers":
        processor = TrOCRProcessor.from_pretrained(args.recognizer, use_fast=False)
        recognizer = VisionEncoderDecoderModel.from_pretrained(args.recognizer)
        recognizer.eval()
        parameter_count = sum(
            parameter.numel() for parameter in recognizer.parameters()
        )
        recognizer_metadata = {
            "name": args.recognizer,
            "runtime": "transformers_pytorch_host_only",
            "parameters": parameter_count,
            "estimated_fp32_bytes": parameter_count * 4,
        }

        def recognize_batch(images: list[Any]) -> list[str]:
            pixel_values = processor(images=images, return_tensors="pt").pixel_values
            generated = recognizer.generate(
                pixel_values,
                num_beams=args.num_beams,
                max_new_tokens=args.max_new_tokens,
            )
            return processor.batch_decode(generated, skip_special_tokens=True)

    else:
        encoder_path = recognizer_path / "encoder_model.onnx"
        decoder_path = recognizer_path / "decoder_model.onnx"
        required = [encoder_path, decoder_path, recognizer_path / "config.json"]
        missing = [path for path in required if not path.is_file()]
        if missing:
            print(
                "Missing ONNX TrOCR files: " + ", ".join(map(str, missing)),
                file=sys.stderr,
            )
            return 66
        processor = TrOCRProcessor.from_pretrained(
            recognizer_path,
            use_fast=True,
            do_resize=True,
            size={"height": 192, "width": 1024},
        )
        config = VisionEncoderDecoderConfig.from_pretrained(recognizer_path)
        encoder = ort.InferenceSession(
            str(encoder_path), providers=["CPUExecutionProvider"]
        )
        decoder = ort.InferenceSession(
            str(decoder_path), providers=["CPUExecutionProvider"]
        )
        weight_paths = [
            encoder_path,
            decoder_path,
            recognizer_path / "encoder_model.onnx.data",
            recognizer_path / "decoder_model.onnx.data",
        ]
        recognizer_metadata = {
            "name": args.recognizer,
            "runtime": "onnxruntime_host",
            "model_bytes": sum(
                path.stat().st_size for path in weight_paths if path.is_file()
            ),
        }

        def recognize_batch(images: list[Any]) -> list[str]:
            pixel_values = processor(images=images, return_tensors="pt").pixel_values
            encoder_outputs = encoder.run(
                None, {encoder.get_inputs()[0].name: pixel_values.numpy()}
            )[0]
            generated = np.full(
                (len(images), 1),
                config.decoder_start_token_id,
                dtype=np.int64,
            )
            finished = np.zeros(len(images), dtype=bool)
            for _ in range(args.max_new_tokens):
                logits = decoder.run(
                    None,
                    {
                        "input_ids": generated,
                        "encoder_hidden_states": encoder_outputs,
                    },
                )[0]
                next_tokens = np.argmax(logits[:, -1, :], axis=-1)
                next_tokens = np.where(finished, config.pad_token_id, next_tokens)
                generated = np.concatenate(
                    [generated, next_tokens.reshape(-1, 1)], axis=1
                )
                finished |= next_tokens == config.eos_token_id
                if bool(np.all(finished)):
                    break
            return processor.batch_decode(
                generated,
                skip_special_tokens=True,
                clean_up_tokenization_spaces=False,
            )

    prepared: list[dict[str, Any]] = []
    for sample in manifest["samples"]:
        source = args.samples_dir / sample["filename"]
        image = cv2.imread(str(source.resolve()), cv2.IMREAD_COLOR)
        if image is None:
            print(f"Could not decode {source}", file=sys.stderr)
            return 65
        tensor = _detector_tensor(
            image,
            max_side=args.detector_max_side,
            cv2=cv2,
            np=np,
        )
        probability = detector.run(None, {detector.get_inputs()[0].name: tensor})[0][0, 0]
        regions = _detector_regions(
            probability,
            original_width=image.shape[1],
            original_height=image.shape[0],
            threshold=args.det_thresh,
            box_threshold=args.det_box_thresh,
            unclip_ratio=args.det_unclip_ratio,
            cv2=cv2,
            np=np,
        )
        lines = _merge_line_regions(regions)[:80]
        crops = [_crop(image, region) for region in lines]
        if args.crops_dir is not None:
            for index, crop in enumerate(crops):
                cv2.imwrite(str(args.crops_dir / f"{sample['id']}_{index:02d}.png"), crop)
        prepared.append(
            {
                "sample": sample,
                "source": source,
                "regions": lines,
                "crops": crops,
            }
        )

    flat: list[tuple[int, int, Any]] = []
    for sample_index, item in enumerate(prepared):
        for line_index, crop in enumerate(item["crops"]):
            rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)
            flat.append((sample_index, line_index, Image.fromarray(rgb)))

    recognized: dict[tuple[int, int], str] = {}
    recognition_ms: dict[int, float] = {index: 0.0 for index in range(len(prepared))}
    with torch.inference_mode():
        for offset in range(0, len(flat), args.batch_size):
            batch = flat[offset : offset + args.batch_size]
            started = time.perf_counter()
            texts = recognize_batch([entry[2] for entry in batch])
            elapsed_ms = (time.perf_counter() - started) * 1000.0
            per_line_ms = elapsed_ms / len(batch)
            for entry, text in zip(batch, texts, strict=True):
                sample_index, line_index, _ = entry
                recognized[(sample_index, line_index)] = text.strip()
                recognition_ms[sample_index] += per_line_ms

    samples = []
    for sample_index, item in enumerate(prepared):
        sample = item["sample"]
        lines = []
        for line_index, region in enumerate(item["regions"]):
            text = recognized.get((sample_index, line_index), "")
            if not text:
                continue
            lines.append(
                {
                    "text": text,
                    "confidence": None,
                    "mark_status": "normal",
                    "bbox": _bbox(region),
                }
            )
        print(
            f"{sample['id']}: {recognition_ms[sample_index]:.1f} ms, "
            f"{len(lines)} lines: " + " | ".join(line["text"] for line in lines)
        )
        samples.append(
            {
                "id": sample["id"],
                "filename": sample["filename"],
                "input_type": sample["input_type"],
                "latency_ms": round(recognition_ms[sample_index], 3),
                "preprocessing": "portable_ppocr_detector_then_trocr_processor",
                "source_bytes": item["source"].stat().st_size,
                "lines": lines,
            }
        )

    document = {
        "schema_version": 1,
        "backend": f"ppocrv6_detector_{args.recognizer.replace('/', '_')}",
        "models": {
            "detector": {
                "name": "PaddlePaddle/PP-OCRv6_small_det_onnx",
                "sha256": _sha256(args.det_model),
            },
            "recognizer": recognizer_metadata,
        },
        "settings": {
            "detector_max_side": args.detector_max_side,
            "det_thresh": args.det_thresh,
            "det_box_thresh": args.det_box_thresh,
            "det_unclip_ratio": args.det_unclip_ratio,
            "batch_size": args.batch_size,
            "recognizer_backend": args.recognizer_backend,
            "num_beams": args.num_beams,
            "max_new_tokens": args.max_new_tokens,
            "crossout_classification": False,
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
