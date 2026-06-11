"""Parse and validate LLM output."""

from __future__ import annotations

import json
import re
from typing import Any


def strip_markdown_fences(text: str) -> str:
    """Remove markdown fences and thinking blocks from model output."""
    text = text.strip()
    # Strip ... blocks (reasoner models)
    text = re.sub(r"<think\b[^>]*>.*?", "", text, flags=re.DOTALL | re.IGNORECASE)
    m = re.match(r"^```(?:json|jsonl)?\s*\n?(.*?)\n?```\s*$", text, re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1).strip()
    # Inline code fence
    m = re.search(r"```(?:json|jsonl)?\s*\n(.*?)```", text, re.DOTALL | re.IGNORECASE)
    if m:
        return m.group(1).strip()
    return text


def _min_aliases() -> int:
    import os
    return int(os.getenv("MIN_ALIASES", "12"))


def _validate_canonical_item(item: dict, index: int, *, min_aliases: int | None = None) -> None:
    if not isinstance(item, dict):
        raise ValueError(f"Item {index} is not an object")
    for field in ("name_de", "name_en", "name_fr", "name_es", "category"):
        if field not in item:
            raise ValueError(f"Item {index} missing field {field}")
    floor = min_aliases if min_aliases is not None else _min_aliases()
    for alias_field in ("aliases_de", "aliases_en", "aliases_fr", "aliases_es"):
        aliases = item.get(alias_field, [])
        if not isinstance(aliases, list) or len(aliases) < floor:
            raise ValueError(f"Item {index} {alias_field} needs ≥{floor} entries, got {len(aliases)}")


def _scan_json_objects(text: str, start_pos: int = 0) -> list[dict[str, Any]]:
    """Extract complete {...} objects via brace matching."""
    objects: list[dict[str, Any]] = []
    n = len(text)
    i = start_pos

    while i < n:
        if text[i] != "{":
            i += 1
            continue

        depth = 0
        in_string = False
        escape = False
        j = i

        while j < n:
            c = text[j]
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == '"':
                in_string = not in_string
            elif not in_string:
                if c == "{":
                    depth += 1
                elif c == "}":
                    depth -= 1
                    if depth == 0:
                        chunk = text[i : j + 1]
                        try:
                            obj = json.loads(chunk)
                            if isinstance(obj, dict):
                                objects.append(obj)
                        except json.JSONDecodeError:
                            pass
                        i = j + 1
                        break
            j += 1
        else:
            break

    return objects


def extract_complete_objects(text: str) -> list[dict[str, Any]]:
    """Salvage complete objects from truncated JSON array or JSONL."""
    cleaned = strip_markdown_fences(text)
    start = cleaned.find("[")
    if start != -1:
        return _scan_json_objects(cleaned, start + 1)
    return _scan_json_objects(cleaned, 0)


def parse_json_array(
    text: str,
    *,
    min_items: int = 1,
    min_aliases: int | None = None,
    allow_partial: bool = True,
) -> list[dict[str, Any]]:
    """Parse a JSON array; salvage complete objects if the response was truncated."""
    cleaned = strip_markdown_fences(text)
    data: list[dict[str, Any]] | None = None
    truncated = False

    try:
        parsed = json.loads(cleaned)
        if isinstance(parsed, list):
            data = parsed
    except json.JSONDecodeError:
        truncated = True

    if data is None:
        data = extract_complete_objects(text)
        truncated = True

    if not data:
        raise ValueError("No valid JSON objects found in response")

    valid: list[dict[str, Any]] = []
    errors: list[str] = []
    for i, item in enumerate(data):
        try:
            _validate_canonical_item(item, i, min_aliases=min_aliases)
            valid.append(item)
        except ValueError as e:
            errors.append(str(e))

    if len(valid) < min_items:
        detail = f"got {len(valid)} valid items, need ≥{min_items}"
        if errors:
            detail += f"; first error: {errors[0]}"
        if truncated:
            detail += " (response likely truncated — retry or lower items_per_batch)"
        raise ValueError(detail)

    if truncated and allow_partial and len(valid) < len(data):
        pass  # caller may log partial salvage

    return valid


_OCR_RAW_KEYS = ("raw", "noisy", "text", "dirty", "ocr", "wrong", "input")
_OCR_ITEM_KEYS = ("item_de", "clean", "correct", "completion", "canonical", "name", "item")


def normalize_ocr_row(
    row: dict,
    item_lookup: dict[str, dict[str, Any]],
    lang: str,
) -> dict[str, Any] | None:
    """Map alternate model schemas (clean/noisy, text/completion) to canonical OCR format."""
    raw = next((str(row[k]).strip() for k in _OCR_RAW_KEYS if row.get(k)), "")
    if not raw:
        return None

    item_name = next((str(row[k]).strip() for k in _OCR_ITEM_KEYS if row.get(k)), "")
    seed = item_lookup.get(item_name.lower()) if item_name else None
    if not seed:
        # Try matching raw against canonical names
        for candidate in item_lookup.values():
            if item_name and item_name.lower() in (
                candidate.get("name_de", "").lower(),
                candidate.get("name_en", "").lower(),
            ):
                seed = candidate
                break
    if not seed:
        return None

    vtype = row.get("variant_type") or row.get("type") or "TYPO"
    vtype = str(vtype).upper()
    if vtype == "OCR":
        vtype = "OCR_CHAR_CONFUSION"

    return {
        "item_de": seed["name_de"],
        "item_en": seed.get("name_en", ""),
        "item_fr": seed.get("name_fr", ""),
        "item_es": seed.get("name_es", ""),
        "lang": lang,
        "raw": raw,
        "variant_type": vtype,
        "variant_subtype": row.get("variant_subtype") or row.get("subtype") or "model_variant",
    }


def _validate_jsonl_row(row: dict, index: int) -> None:
    if not isinstance(row, dict):
        raise ValueError(f"Row {index} is not an object")
    if not row.get("raw"):
        raise ValueError(f"Row {index} missing raw")
    if not row.get("variant_type"):
        raise ValueError(f"Row {index} missing variant_type")
    if not row.get("item_de"):
        raise ValueError(f"Row {index} missing item_de")


def parse_jsonl(
    text: str,
    *,
    min_lines: int = 1,
    salvage: bool = True,
    item_lookup: dict[str, dict[str, Any]] | None = None,
    lang: str = "",
) -> list[dict[str, Any]]:
    """Parse JSONL; salvage complete objects if lines are truncated or merged."""
    cleaned = strip_markdown_fences(text)
    rows: list[dict[str, Any]] = []
    line_errors: list[str] = []

    # Full-text scan handles concatenated objects on one line
    if salvage:
        rows = _scan_json_objects(cleaned, 0)

    if not rows:
        for i, line in enumerate(cleaned.splitlines(), 1):
            line = line.strip()
            if not line or line in ("[", "]", "{}", "[]"):
                continue
            try:
                obj = json.loads(line)
                if isinstance(obj, dict):
                    rows.append(obj)
            except json.JSONDecodeError as e:
                line_errors.append(f"line {i}: {e}")
                if salvage:
                    rows.extend(extract_complete_objects(line))

    # Deduplicate by (item_de, raw) after normalization
    seen: set[tuple[str, str]] = set()
    valid: list[dict[str, Any]] = []
    errors: list[str] = []
    for i, row in enumerate(rows):
        try:
            if item_lookup and lang:
                normalized = normalize_ocr_row(row, item_lookup, lang)
                if normalized is None:
                    if row.get("raw") and row.get("item_de"):
                        normalized = row
                    else:
                        errors.append(f"Row {i} could not normalize: {list(row.keys())}")
                        continue
                row = normalized
            _validate_jsonl_row(row, i)
            key = (row.get("item_de", ""), row.get("raw", ""))
            if key in seen:
                continue
            seen.add(key)
            valid.append(row)
        except ValueError as e:
            errors.append(str(e))

    if len(valid) < min_lines:
        detail = f"Expected ≥{min_lines} JSONL rows, got {len(valid)}"
        if line_errors:
            detail += f"; first line error: {line_errors[0]}"
        if errors:
            detail += f"; first row error: {errors[0]}"
        raise ValueError(detail)

    return valid


def validate_ocr_corpus(rows: list[dict], *, items: list[str], variants_per_item: int = 30) -> None:
    """Ensure each item has exactly N variants."""
    from collections import Counter

    counts: Counter[str] = Counter()
    for row in rows:
        key = row.get("item_de") or row.get("raw", "")
        counts[key] += 1
    for item in items:
        matched = sum(1 for r in rows if _item_matches(r, item))
        if matched != variants_per_item:
            raise ValueError(f"Item '{item}': expected {variants_per_item} variants, got {matched}")


def _item_matches(row: dict, item: str) -> bool:
    item_lower = item.lower()
    for field in ("item_de", "item_en", "item_fr", "item_es"):
        val = row.get(field, "")
        if val and val.lower() == item_lower:
            return True
    return False
