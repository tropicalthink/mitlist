"""Parse and validate LLM output."""

from __future__ import annotations

import json
import re
from typing import Any


def strip_markdown_fences(text: str) -> str:
    """Remove ```json ... ``` wrappers if the model ignored instructions."""
    text = text.strip()
    m = re.match(r"^```(?:json|jsonl)?\s*\n?(.*?)\n?```\s*$", text, re.DOTALL | re.IGNORECASE)
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


def extract_complete_objects(text: str) -> list[dict[str, Any]]:
    """Salvage complete top-level objects from a truncated JSON array."""
    cleaned = strip_markdown_fences(text)
    start = cleaned.find("[")
    if start == -1:
        return []

    objects: list[dict[str, Any]] = []
    i = start + 1
    n = len(cleaned)

    while i < n:
        while i < n and cleaned[i] in " \t\n\r,":
            i += 1
        if i >= n or cleaned[i] == "]":
            break
        if cleaned[i] != "{":
            i += 1
            continue

        depth = 0
        in_string = False
        escape = False
        j = i

        while j < n:
            c = cleaned[j]
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
                        chunk = cleaned[i : j + 1]
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
            break  # truncated mid-object

    return objects


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


def parse_jsonl(text: str, *, min_lines: int = 1) -> list[dict[str, Any]]:
    cleaned = strip_markdown_fences(text)
    rows: list[dict[str, Any]] = []
    for i, line in enumerate(cleaned.splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as e:
            raise ValueError(f"JSONL line {i} invalid: {e}") from e
    if len(rows) < min_lines:
        raise ValueError(f"Expected ≥{min_lines} JSONL rows, got {len(rows)}")
    return rows


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
