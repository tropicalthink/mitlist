#!/usr/bin/env python3
"""Merge tool/arb_translations.json into locale ARB files."""

from __future__ import annotations

import json
from pathlib import Path

L10N_DIR = Path(__file__).resolve().parent.parent / "lib" / "l10n"
TRANSLATIONS_PATH = Path(__file__).resolve().parent / "arb_translations.json"


def message_keys(data: dict) -> set[str]:
    return {k for k in data if not k.startswith("@")}


def uses_metadata(data: dict) -> bool:
    """True when locale file includes @description entries."""
    return any(k.startswith("@") for k in data)


def merge_locale(locale: str, translations: dict[str, str], en: dict) -> int:
    arb_path = L10N_DIR / f"app_{locale}.arb"
    data = json.loads(arb_path.read_text(encoding="utf-8"))
    include_meta = uses_metadata(data)
    added = 0

    for key, value in translations.items():
        if key in message_keys(data):
            continue
        data[key] = value
        if include_meta:
            meta_key = f"@{key}"
            if meta_key in en:
                data[meta_key] = en[meta_key]
        added += 1

    arb_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return added


def main() -> None:
    translations = json.loads(TRANSLATIONS_PATH.read_text(encoding="utf-8"))
    en = json.loads((L10N_DIR / "app_en.arb").read_text(encoding="utf-8"))

    for locale, entries in translations.items():
        added = merge_locale(locale, entries, en)
        arb = json.loads((L10N_DIR / f"app_{locale}.arb").read_text(encoding="utf-8"))
        missing = message_keys(en) - message_keys(arb)
        print(f"{locale}: added {added}, missing {len(missing)}")
        if missing:
            print(f"  still missing: {sorted(missing)[:5]}...")


if __name__ == "__main__":
    main()
