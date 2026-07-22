#!/usr/bin/env python3
"""Evaluate a CTC recognition ONNX model on cropped-line PaddleOCR data."""

from __future__ import annotations

import argparse
import json
import time
import unicodedata
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True, type=Path)
    parser.add_argument("--labels", type=Path, default=Path("val.txt"))
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--characters-json", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def normalize(text: str) -> str:
    return " ".join(unicodedata.normalize("NFC", text).casefold().split())


def edit_distance(left: str, right: str) -> int:
    previous = list(range(len(right) + 1))
    for left_index, left_char in enumerate(left, start=1):
        current = [left_index]
        for right_index, right_char in enumerate(right, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[right_index] + 1,
                    previous[right_index - 1] + (left_char != right_char),
                )
            )
        previous = current
    return previous[-1]


def image_tensor(path: Path) -> np.ndarray:
    with Image.open(path) as opened:
        image = opened.convert("RGB")
    content_width = max(1, min(3200, int(np.ceil(48 * image.width / image.height))))
    width = max(320, content_width)
    resized = image.resize((content_width, 48), Image.Resampling.BILINEAR)
    rgb = np.asarray(resized, dtype=np.float32)
    bgr = rgb[:, :, ::-1] / 127.5 - 1.0
    tensor = np.zeros((1, 3, 48, width), dtype=np.float32)
    tensor[0, :, :, :content_width] = np.transpose(bgr, (2, 0, 1))
    return tensor


def decode(logits: np.ndarray, characters: list[str]) -> str:
    indices = logits[0].argmax(axis=-1)
    output: list[str] = []
    previous = -1
    for index_value in indices:
        index = int(index_value)
        if index != 0 and index != previous:
            if index <= len(characters):
                output.append(characters[index - 1])
            elif index == len(characters) + 1:
                output.append(" ")
        previous = index
    return "".join(output).strip()


def read_labels(dataset: Path, labels: Path) -> list[tuple[Path, str]]:
    label_path = labels if labels.is_absolute() else dataset / labels
    rows: list[tuple[Path, str]] = []
    for line_number, line in enumerate(label_path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            relative, label = line.split("\t", 1)
        except ValueError as error:
            raise ValueError(f"Invalid label at {label_path}:{line_number}") from error
        rows.append((dataset / relative, label))
    return rows


def main() -> None:
    args = parse_args()
    characters = json.loads(args.characters_json.read_text(encoding="utf-8"))
    rows = read_labels(args.dataset, args.labels)
    if not rows:
        raise ValueError("Evaluation label file is empty")
    session = ort.InferenceSession(str(args.model), providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name
    total_edits = 0
    total_characters = 0
    exact = 0
    elapsed_ms = 0.0
    predictions: list[dict[str, object]] = []
    for image_path, expected in rows:
        started = time.perf_counter()
        logits = session.run(None, {input_name: image_tensor(image_path)})[0]
        elapsed_ms += (time.perf_counter() - started) * 1000
        predicted = decode(logits, characters)
        normalized_expected = normalize(expected)
        normalized_predicted = normalize(predicted)
        edits = edit_distance(normalized_expected, normalized_predicted)
        total_edits += edits
        total_characters += len(normalized_expected)
        exact += normalized_expected == normalized_predicted
        predictions.append(
            {
                "image": str(image_path.relative_to(args.dataset)),
                "expected": expected,
                "predicted": predicted,
                "edits": edits,
            }
        )
    result = {
        "model": str(args.model),
        "lines": len(rows),
        "character_error_rate": total_edits / max(1, total_characters),
        "exact_line_rate": exact / len(rows),
        "mean_latency_ms": elapsed_ms / len(rows),
        "predictions": predictions,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "predictions"}, indent=2))


if __name__ == "__main__":
    main()
