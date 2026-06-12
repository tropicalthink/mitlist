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


def _validate_triplet_row(row: dict, index: int) -> None:
    if not isinstance(row, dict):
        raise ValueError(f"Row {index} is not an object")
    for field in ("anchor_de", "anchor_en", "anchor_fr", "anchor_es"):
        if not row.get(field):
            raise ValueError(f"Row {index} missing {field}")
    for field in ("positive_text", "positive_type", "positive_lang"):
        if not row.get(field):
            raise ValueError(f"Row {index} missing {field}")
    for field in ("negative_de", "negative_en", "negative_fr", "negative_es", "negative_subtype"):
        if not row.get(field):
            raise ValueError(f"Row {index} missing {field}")


def _validate_aisle_row(row: dict, index: int) -> None:
    if not isinstance(row, dict):
        raise ValueError(f"Row {index} is not an object")
    for field in ("country", "store", "canonical_name_de", "aisle"):
        if not row.get(field):
            raise ValueError(f"Row {index} missing {field}")
    if row.get("sort_order") is None:
        raise ValueError(f"Row {index} missing sort_order")
    if row.get("typically_stocked") is None:
        raise ValueError(f"Row {index} missing typically_stocked")


def _is_wrong_correction_format(row: dict) -> bool:
    """Reject general Q&A / instruction-tuning shapes (common with fast models)."""
    if row.get("instruction"):
        return True
    text = str(row.get("input", ""))
    if "?" in text and not row.get("raw_ocr"):
        return True
    if text.lower().startswith(("what ", "who ", "when ", "where ", "how ", "name ")):
        return True
    return False


def normalize_correction_row(row: dict, lang: str = "") -> dict | None:
    """Map alternate field names; reject non-grocery correction shapes."""
    if not isinstance(row, dict):
        return None
    if _is_wrong_correction_format(row):
        return None
    if row.get("raw_ocr") and row.get("scenario") and row.get("list_language"):
        return row

    raw = str(row.get("raw_ocr") or row.get("ocr") or row.get("input") or "").strip()
    if not raw or len(raw) > 80:
        return None

    list_lang = str(row.get("list_language") or row.get("language") or lang or "").lower()
    scenario = row.get("scenario") or row.get("correction_type") or row.get("type") or ""
    user_action = row.get("user_action") or row.get("action")
    if not user_action:
        user_action = "corrected" if row.get("corrected") or row.get("correction") else "accepted"

    canon_de = row.get("correct_canonical_de") or row.get("corrected_output") or row.get("output") or row.get("correction") or ""
    canon_en = row.get("correct_canonical_en") or canon_de
    if not scenario or not list_lang or not canon_de:
        return None

    rid = row.get("id") or f"gen_{list_lang}_{raw[:12]}"
    return {
        **row,
        "id": rid,
        "raw_ocr": raw,
        "scenario": scenario,
        "list_language": list_lang,
        "user_action": user_action,
        "correct_canonical_de": str(canon_de),
        "correct_canonical_en": str(canon_en),
        "correct_canonical_fr": row.get("correct_canonical_fr") or str(canon_de),
        "correct_canonical_es": row.get("correct_canonical_es") or str(canon_de),
        "correction_text": row.get("correction_text") or row.get("correction") or str(canon_de),
    }


def _validate_correction_row(row: dict, index: int) -> None:
    if not isinstance(row, dict):
        raise ValueError(f"Row {index} is not an object")
    for field in ("id", "raw_ocr", "scenario", "list_language", "user_action"):
        if not row.get(field):
            raise ValueError(f"Row {index} missing {field}")
    for field in ("correct_canonical_de", "correct_canonical_en"):
        if not row.get(field):
            raise ValueError(f"Row {index} missing {field}")


def count_json_objects(text: str) -> int:
    return len(_scan_json_objects(strip_markdown_fences(text), 0))


_SCHEMA_VALIDATORS: dict[str, Any] = {
    "ocr": _validate_jsonl_row,
    "triplet": _validate_triplet_row,
    "aisle": _validate_aisle_row,
    "correction": _validate_correction_row,
}


def parse_jsonl(
    text: str,
    *,
    min_lines: int = 1,
    salvage: bool = True,
    item_lookup: dict[str, dict[str, Any]] | None = None,
    lang: str = "",
    schema: str = "ocr",
    dedupe_key: tuple[str, str] | None = None,
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

    validate = _SCHEMA_VALIDATORS.get(schema, _validate_jsonl_row)
    if dedupe_key is None:
        dedupe_key = ("item_de", "raw") if schema == "ocr" else ("anchor_de", "positive_text")

    seen: set[tuple[str, str]] = set()
    valid: list[dict[str, Any]] = []
    errors: list[str] = []
    for i, row in enumerate(rows):
        try:
            if schema == "correction":
                normalized = normalize_correction_row(row, lang)
                if normalized is None:
                    errors.append(f"Row {i} wrong schema: {list(row.keys())[:6]}")
                    continue
                row = normalized
            elif item_lookup and lang:
                normalized = normalize_ocr_row(row, item_lookup, lang)
                if normalized is None:
                    if row.get("raw") and row.get("item_de"):
                        normalized = row
                    else:
                        errors.append(f"Row {i} could not normalize: {list(row.keys())}")
                        continue
                row = normalized
            validate(row, i)
            key = (str(row.get(dedupe_key[0], "")), str(row.get(dedupe_key[1], "")))
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
