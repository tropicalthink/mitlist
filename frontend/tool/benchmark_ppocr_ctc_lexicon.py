#!/usr/bin/env python3
"""Prototype lexicon-constrained decoding for the bundled PP-OCR recognizer.

The production recognizer is CTC, which exposes character evidence that is
lost after greedy decoding. This host-only experiment keeps the current models
and scores plausible grocery names with the full CTC forward algorithm. A
lexicon candidate may replace the raw reading only when its visual probability
stays close to the raw path; otherwise unknown items remain untouched.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys
import time
from typing import Any

from benchmark_handwriting_recognizer import (
    _crop,
    _detector_regions,
    _detector_tensor,
    _merge_line_regions,
)


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--det-model", type=Path, required=True)
    parser.add_argument("--rec-model", type=Path, required=True)
    parser.add_argument("--characters", type=Path, required=True)
    parser.add_argument("--lexicon", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--candidate-count", type=int, default=128)
    parser.add_argument("--minimum-similarity", type=float, default=0.55)
    parser.add_argument("--lexicon-weight", type=float, default=0.22)
    parser.add_argument(
        "--max-visual-gap",
        type=float,
        default=0.16,
        help="Largest allowed per-timestep log-probability gap from the raw path",
    )
    return parser.parse_args()


def _normalise(value: str) -> str:
    return re.sub(r"[^\w]+", " ", value.lower(), flags=re.UNICODE).strip()


def _edit_distance(left: str, right: str) -> int:
    if not left:
        return len(right)
    if not right:
        return len(left)
    previous = list(range(len(right) + 1))
    for row, left_char in enumerate(left, start=1):
        current = [row]
        for column, right_char in enumerate(right, start=1):
            current.append(
                min(
                    previous[column] + 1,
                    current[column - 1] + 1,
                    previous[column - 1] + (left_char != right_char),
                )
            )
        previous = current
    return previous[-1]


def _similarity(left: str, right: str) -> float:
    denominator = max(len(left), len(right))
    return 1.0 if denominator == 0 else 1.0 - _edit_distance(left, right) / denominator


def _recognition_tensor(image: Any, cv2: Any, np: Any) -> Any:
    source_height, source_width = image.shape[:2]
    height = 48
    content_width = max(1, min(3200, math.ceil(height * source_width / source_height)))
    width = max(320, content_width)
    resized = cv2.resize(image, (content_width, height), interpolation=cv2.INTER_LINEAR)
    tensor = np.zeros((1, 3, height, width), dtype=np.float32)
    chw = (resized.astype(np.float32) / 127.5 - 1.0).transpose(2, 0, 1)
    tensor[0, :, :, :content_width] = chw
    return tensor


def _log_softmax(values: Any, np: Any) -> Any:
    maximum = values.max(axis=-1, keepdims=True)
    shifted = values - maximum
    return shifted - np.log(np.exp(shifted).sum(axis=-1, keepdims=True))


def _greedy(logits: Any, characters: list[str], np: Any) -> str:
    indices = np.argmax(logits, axis=-1)
    output = []
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


def _log_add(left: float, right: float) -> float:
    if left == -math.inf:
        return right
    if right == -math.inf:
        return left
    larger = max(left, right)
    return larger + math.log(math.exp(left - larger) + math.exp(right - larger))


def _ctc_log_probability(log_probs: Any, labels: list[int]) -> float:
    if not labels:
        return float(log_probs[:, 0].sum())
    states = [0]
    for label in labels:
        states.extend((label, 0))
    previous = [-math.inf] * len(states)
    previous[0] = float(log_probs[0, 0])
    if len(states) > 1:
        previous[1] = float(log_probs[0, states[1]])
    for timestep in range(1, len(log_probs)):
        current = [-math.inf] * len(states)
        for state, label in enumerate(states):
            total = previous[state]
            if state > 0:
                total = _log_add(total, previous[state - 1])
            if (
                state > 1
                and label != 0
                and label != states[state - 2]
            ):
                total = _log_add(total, previous[state - 2])
            current[state] = total + float(log_probs[timestep, label])
        previous = current
    return _log_add(previous[-1], previous[-2])


def _labels(text: str, indices: dict[str, int]) -> list[int] | None:
    labels = []
    for character in text:
        index = indices.get(character)
        if index is None:
            return None
        labels.append(index)
    return labels


def _candidate_pool(
    raw: str,
    lexicon: list[tuple[str, str]],
    *,
    count: int,
    minimum_similarity: float,
) -> list[tuple[str, str, float]]:
    query = _normalise(raw)
    maximum_delta = max(3, min(10, math.ceil(len(query) * 0.45)))
    candidates = []
    for normalized, display in lexicon:
        if abs(len(normalized) - len(query)) > maximum_delta:
            continue
        similarity = _similarity(query, normalized)
        if similarity >= minimum_similarity:
            candidates.append((normalized, display, similarity))
    candidates.sort(key=lambda item: item[2], reverse=True)
    return candidates[:count]


def main() -> int:
    args = _arguments()
    try:
        import cv2
        import numpy as np
        import onnxruntime as ort
    except ImportError as error:
        print(error, file=sys.stderr)
        return 69

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    characters = json.loads(args.characters.read_text(encoding="utf-8"))
    character_indices = {character: index + 1 for index, character in enumerate(characters)}
    character_indices[" "] = len(characters) + 1
    lexicon_json = json.loads(args.lexicon.read_text(encoding="utf-8"))
    lexicon = [
        (entry[0], entry[2])
        for entry in lexicon_json["entries"]
        if entry[0] and entry[2]
    ]
    detector = ort.InferenceSession(str(args.det_model), providers=["CPUExecutionProvider"])
    recognizer = ort.InferenceSession(str(args.rec_model), providers=["CPUExecutionProvider"])

    samples = []
    for sample in manifest["samples"]:
        source = args.samples_dir / sample["filename"]
        image = cv2.imread(str(source), cv2.IMREAD_COLOR)
        started = time.perf_counter()
        det_input = _detector_tensor(image, max_side=1600, cv2=cv2, np=np)
        probability = detector.run(None, {detector.get_inputs()[0].name: det_input})[0][0, 0]
        regions = _merge_line_regions(
            _detector_regions(
                probability,
                original_width=image.shape[1],
                original_height=image.shape[0],
                threshold=0.2,
                box_threshold=0.45,
                unclip_ratio=1.4,
                cv2=cv2,
                np=np,
            )
        )[:80]
        lines = []
        for region in regions:
            crop = _crop(image, region)
            rec_input = _recognition_tensor(crop, cv2, np)
            logits = recognizer.run(
                None, {recognizer.get_inputs()[0].name: rec_input}
            )[0][0]
            raw = _greedy(logits, characters, np)
            log_probs = _log_softmax(logits, np)
            raw_labels = _labels(raw, character_indices)
            raw_visual = (
                _ctc_log_probability(log_probs, raw_labels) / len(log_probs)
                if raw_labels
                else -math.inf
            )
            best_text = raw
            best_score = raw_visual
            best_similarity = 0.0
            for normalized, display, similarity in _candidate_pool(
                raw,
                lexicon,
                count=args.candidate_count,
                minimum_similarity=args.minimum_similarity,
            ):
                labels = _labels(display, character_indices)
                if not labels:
                    continue
                visual = _ctc_log_probability(log_probs, labels) / len(log_probs)
                if raw_visual - visual > args.max_visual_gap:
                    continue
                score = visual + args.lexicon_weight * similarity
                if score > best_score:
                    best_text = display
                    best_score = score
                    best_similarity = similarity
            lines.append(
                {
                    "text": best_text,
                    "raw_text": raw,
                    "lexicon_similarity": best_similarity,
                    "confidence": None,
                    "mark_status": "normal",
                    "bbox": {
                        "left": float(region["left"]),
                        "top": float(region["top"]),
                        "width": float(region["right"] - region["left"]),
                        "height": float(region["bottom"] - region["top"]),
                    },
                }
            )
        elapsed_ms = (time.perf_counter() - started) * 1000
        print(
            f"{sample['id']}: {elapsed_ms:.1f} ms: "
            + " | ".join(
                f"{line['raw_text']} -> {line['text']}" if line["raw_text"] != line["text"] else line["text"]
                for line in lines
            )
        )
        samples.append(
            {
                "id": sample["id"],
                "filename": sample["filename"],
                "input_type": sample["input_type"],
                "latency_ms": round(elapsed_ms, 3),
                "preprocessing": "portable_ppocr_with_ctc_lexicon_rescore",
                "lines": lines,
            }
        )

    result = {
        "schema_version": 1,
        "backend": "ppocrv6_ctc_lexicon_prototype",
        "settings": {
            "candidate_count": args.candidate_count,
            "minimum_similarity": args.minimum_similarity,
            "lexicon_weight": args.lexicon_weight,
            "max_visual_gap": args.max_visual_gap,
            "crossout_classification": False,
        },
        "samples": samples,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Raw results: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
