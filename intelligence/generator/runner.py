#!/usr/bin/env python3
"""CLI runner for DeepSeek batch generation.

Usage:
  python -m generator.runner run --prompt 1 --all
  python -m generator.runner run --prompt 2 --batch DE_group_0
  python -m generator.runner run --prompt 1 --category produce_fruit --temp 0.9
  python -m generator.runner status
  python -m generator.runner dashboard
  python -m generator.runner estimate
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from itertools import product
from pathlib import Path

import yaml

try:
    from dotenv import load_dotenv
except ImportError:
    def load_dotenv(*_args, **_kwargs):  # type: ignore[misc]
        pass

try:
    from tqdm import tqdm
except ImportError:
    def tqdm(iterable, **kwargs):  # type: ignore[misc]
        return iterable

from generator.parsers import parse_json_array, parse_jsonl, strip_markdown_fences
from generator.progress import ProgressStore

ROOT = Path(__file__).resolve().parent.parent
PROMPTS_DIR = ROOT / "prompts"
CONFIG_DIR = ROOT / "config"
DATA_DIR = ROOT / "ml" / "data"
DB_PATH = ROOT / "progress.db"

OCR_SCHEMA_EXAMPLE = (
    '{"item_de":"Birne","item_en":"Pear","item_fr":"Poire","item_es":"Pera",'
    '"lang":"DE","raw":"Birne","variant_type":"TYPO","variant_subtype":"missing_e"}'
)


def load_config() -> dict:
    with open(CONFIG_DIR / "batches.yaml") as f:
        return yaml.safe_load(f)


def load_pricing() -> dict:
    with open(CONFIG_DIR / "pricing.yaml") as f:
        return yaml.safe_load(f)


def calc_cost(model: str, prompt_tokens: int, completion_tokens: int, pricing: dict) -> float:
    rates = pricing["models"].get(model, pricing["models"]["deepseek-chat"])
    input_cost = prompt_tokens * rates["input_per_million"] / 1_000_000
    output_cost = completion_tokens * rates["output_per_million"] / 1_000_000
    return input_cost + output_cost


def load_prompt(prompt_id: str) -> str:
    path = PROMPTS_DIR / f"prompt{prompt_id}_{_prompt_suffix(prompt_id)}.txt"
    return path.read_text()


def _prompt_suffix(prompt_id: str) -> str:
    return {
        "1": "canonical",
        "2": "ocr_noise",
        "3": "triplets",
        "4": "aisles",
        "5": "corrections",
    }[prompt_id]


def substitute(template: str, variables: dict[str, str]) -> str:
    result = template
    for key, value in variables.items():
        result = result.replace("{" + key + "}", value)
    return result


def load_seed_items() -> list[dict]:
    seed_path = DATA_DIR / "seed.json"
    if not seed_path.exists():
        return []
    return json.loads(seed_path.read_text())


def append_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def merge_seed(path: Path, new_items: list[dict]) -> int:
    existing = []
    if path.exists():
        existing = json.loads(path.read_text())
    seen = {(i.get("name_de", ""), i.get("category", "")) for i in existing}
    added = 0
    for item in new_items:
        key = (item.get("name_de", ""), item.get("category", ""))
        if key not in seen:
            existing.append(item)
            seen.add(key)
            added += 1
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(existing, ensure_ascii=False, indent=2))
    return added


def get_previous_items_in_category(category: str) -> str:
    items = load_seed_items()
    names = [i.get("name_de", "") for i in items if i.get("category") == category]
    return ", ".join(names) if names else "(none yet)"


def build_batch_list(prompt_id: str, cfg: dict, *, require_seed: bool = True) -> list[tuple[str, dict[str, str]]]:
    """Return list of (batch_key, variables) for a prompt."""
    pcfg = cfg["prompts"][prompt_id]
    var_names = list(pcfg.get("variables", {}).keys())

    if prompt_id == "1":
        categories = pcfg["variables"]["CATEGORY"]
        chunks = pcfg.get("chunks_per_category", 1)
        count = str(pcfg.get("items_per_batch", 15))
        batches = []
        for cat in categories:
            for chunk in range(chunks):
                batches.append((f"{cat}_c{chunk}", {
                    "CATEGORY": cat,
                    "CHUNK": str(chunk + 1),
                    "CHUNK_TOTAL": str(chunks),
                    "ITEMS_COUNT": count,
                }))
        return batches

    if prompt_id == "2":
        # Dynamic batches from seed items
        seed = load_seed_items()
        if not seed:
            if require_seed:
                print("ERROR: Prompt 2 requires seed.json from Prompt 1. Run --prompt 1 first.", file=sys.stderr)
                sys.exit(1)
            # Estimate mode: assume ~360 groups (1800 items / 5)
            langs = pcfg["variables"]["LANGUAGE"]
            return [(f"{lang}_group_{i}", {"LANGUAGE": lang, "ITEM_LIST": ""}) for lang in langs for i in range(360)]
        langs = pcfg["variables"]["LANGUAGE"]
        group_size = pcfg.get("items_per_batch", 5)
        variants = str(pcfg.get("variants_per_item", 20))
        batches = []
        for lang in langs:
            for gi in range(math.ceil(len(seed) / group_size)):
                chunk = seed[gi * group_size : (gi + 1) * group_size]
                item_list = "\n".join(
                    f"- {i['name_de']} / {i['name_en']} / {i['name_fr']} / {i['name_es']}"
                    for i in chunk
                )
                batches.append((
                    f"{lang}_group_{gi}",
                    {
                        "LANGUAGE": lang,
                        "ITEM_LIST": item_list,
                        "VARIANTS_PER_ITEM": variants,
                        "_items": [i["name_de"] for i in chunk],
                        "_item_map": {i["name_de"].lower(): i for i in chunk},
                    },
                ))
        return batches

    if not var_names:
        return [("default", {})]

    values = [pcfg["variables"][v] for v in var_names]
    batches = []
    for combo in product(*values):
        variables = dict(zip(var_names, combo))
        key = "_".join(str(v).replace(" ", "_").replace(":", "")[:40] for v in combo)
        batches.append((key, variables))
    return batches


def run_batch(
    prompt_id: str,
    batch_key: str,
    variables: dict[str, str],
    *,
    temperature: float,
    client: "DeepSeekClient",
    store: ProgressStore,
    cfg: dict,
    pricing: dict,
    force: bool = False,
) -> bool:
    pcfg = cfg["prompts"][prompt_id]

    if not force and store.is_completed(prompt_id, batch_key):
        return True

    template = load_prompt(prompt_id)
    if prompt_id == "1":
        cat = variables.get("CATEGORY", "")
        variables = {**variables, "PREVIOUS_ITEMS": get_previous_items_in_category(cat)}

    prompt = substitute(template, {k: v for k, v in variables.items() if not k.startswith("_")})
    system = None
    if pcfg["output_mode"] == "jsonl":
        system = (
            "You are a training data generator. Output ONLY valid JSONL — "
            "one JSON object per line. No markdown, no code fences, no explanation."
        )
    elif pcfg["output_mode"] == "json_array":
        system = (
            "You are a training data generator. Output ONLY a raw JSON array. "
            "No markdown, no code fences, no explanation."
        )
    output_rel = pcfg["output"]
    output_path = ROOT / output_rel

    batch_id = store.start_batch(
        prompt_id, batch_key, model=client.model, temperature=temperature, output_path=str(output_rel)
    )

    debug_dir = ROOT / "debug"

    def _save_debug(result_content: str, reason: str) -> None:
        debug_dir.mkdir(exist_ok=True)
        (debug_dir / f"{batch_id}.txt").write_text(result_content, encoding="utf-8")
        (debug_dir / f"{batch_id}.error.txt").write_text(reason, encoding="utf-8")

    parse_attempts = int(__import__("os").getenv("PARSE_RETRIES", "2")) + 1
    total_prompt_tokens = 0
    total_completion_tokens = 0
    total_cost = 0.0
    total_latency = 0
    last_model = client.model
    rows = 0

    try:
        if pcfg["output_mode"] == "json_array":
            target = pcfg.get("items_per_batch", 15)
            min_aliases = pcfg.get("min_aliases", 12)
            min_accept = max(3, target // 3)
            all_items: list[dict] = []
            current_prompt = prompt
            last_content = ""

            for attempt in range(parse_attempts):
                for continuation in range(4):
                    result = client.complete(current_prompt, temperature=temperature, system=system)
                    last_model = result.model
                    total_prompt_tokens += result.prompt_tokens
                    total_completion_tokens += result.completion_tokens
                    total_cost += calc_cost(result.model, result.prompt_tokens, result.completion_tokens, pricing)
                    total_latency += result.latency_ms
                    last_content = result.content
                    finish_reason = result.raw_response.get("finish_reason", "")

                    try:
                        chunk_items = parse_json_array(
                            result.content, min_items=1, min_aliases=min_aliases,
                        )
                    except (ValueError, json.JSONDecodeError) as e:
                        if attempt < parse_attempts - 1:
                            print(f"  RETRY {batch_key} (parse failed, attempt {attempt + 1}): {e}", file=sys.stderr)
                            break
                        _save_debug(last_content, str(e))
                        raise

                    seen = {(i.get("name_de", ""), i.get("category", "")) for i in all_items}
                    for item in chunk_items:
                        key = (item.get("name_de", ""), item.get("category", ""))
                        if key not in seen:
                            all_items.append(item)
                            seen.add(key)

                    if len(all_items) >= min_accept:
                        break
                    if finish_reason != "length":
                        break

                    existing = ", ".join(i.get("name_de", "") for i in all_items) or "(none)"
                    need = target - len(all_items)
                    current_prompt = (
                        f"Continue the canonical grocery JSON array for category "
                        f"{variables.get('CATEGORY', '')}. "
                        f"Already generated: {existing}. "
                        f"Generate exactly {need} MORE distinct items. "
                        f"Same JSON schema. Each alias list: 15-18 entries. "
                        f"Output ONLY a raw JSON array, no markdown."
                    )
                    print(f"  CONTINUE {batch_key}: have {len(all_items)}/{target}, requesting {need} more", file=sys.stderr)
                else:
                    continue
                break

            if len(all_items) < min_accept:
                _save_debug(last_content, f"Only {len(all_items)} items, need ≥{min_accept}")
                raise ValueError(f"Only {len(all_items)} valid items, need ≥{min_accept}")

            if len(all_items) < target:
                print(f"  WARN {batch_key}: got {len(all_items)}/{target} items (partial)", file=sys.stderr)

            rows = merge_seed(output_path, all_items)

        elif prompt_id == "2":
            from collections import Counter

            items = variables.get("_items", [])
            variants_target = pcfg.get("variants_per_item", 20)
            min_per_item = max(8, variants_target // 2)
            min_accept = max(len(items) * min_per_item, 1)
            all_rows: list[dict] = []
            seen_keys: set[tuple[str, str]] = set()
            current_prompt = prompt
            last_content = ""

            def _merge_rows(new_rows: list[dict]) -> None:
                for row in new_rows:
                    key = (row.get("item_de", ""), row.get("raw", ""))
                    if key not in seen_keys:
                        all_rows.append(row)
                        seen_keys.add(key)

            def _per_item_counts() -> Counter:
                c: Counter = Counter()
                for row in all_rows:
                    c[row.get("item_de", "")] += 1
                return c

            def _enough() -> bool:
                counts = _per_item_counts()
                return len(all_rows) >= min_accept and all(
                    counts.get(it, 0) >= min_per_item for it in items
                )

            for attempt in range(parse_attempts):
                for continuation in range(4):
                    result = client.complete(current_prompt, temperature=temperature, system=system)
                    last_model = result.model
                    total_prompt_tokens += result.prompt_tokens
                    total_completion_tokens += result.completion_tokens
                    total_cost += calc_cost(result.model, result.prompt_tokens, result.completion_tokens, pricing)
                    total_latency += result.latency_ms
                    last_content = result.content
                    finish_reason = result.raw_response.get("finish_reason", "")

                    try:
                        if not result.content.strip():
                            raise ValueError("empty model response (check model/thinking mode)")
                        chunk_rows = parse_jsonl(
                            result.content,
                            min_lines=1,
                            item_lookup=variables.get("_item_map"),
                            lang=variables.get("LANGUAGE", ""),
                        )
                        _merge_rows(chunk_rows)
                    except (ValueError, json.JSONDecodeError) as e:
                        _save_debug(last_content or "(empty)", str(e))
                        preview = (result.content or "")[:300].replace("\n", " ")
                        print(f"  DEBUG {batch_key}: {preview!r}", file=sys.stderr)
                        if attempt < parse_attempts - 1:
                            print(f"  RETRY {batch_key} (parse failed, attempt {attempt + 1}): {e}", file=sys.stderr)
                            break
                        raise

                    if _enough():
                        break
                    if finish_reason != "length":
                        break

                    counts = _per_item_counts()
                    need_lines = []
                    for it in items:
                        have = counts.get(it, 0)
                        if have < variants_target:
                            need_lines.append(f"- {it}: have {have}, need {variants_target - have} more")
                    lang = variables.get("LANGUAGE", "")
                    current_prompt = (
                        f"Continue OCR noise JSONL for language {lang}. "
                        f"Generate ONLY the missing variants:\n"
                        + "\n".join(need_lines)
                        + f"\n\nUse EXACTLY this schema (field names matter):\n"
                        f"{OCR_SCHEMA_EXAMPLE}\n\n"
                        f"Required fields: item_de, item_en, item_fr, item_es, lang, raw, "
                        f"variant_type, variant_subtype. One object per line. No other field names."
                    )
                    print(f"  CONTINUE {batch_key}: {len(all_rows)} rows so far", file=sys.stderr)
                else:
                    continue
                if _enough() or len(all_rows) >= min_accept:
                    break

            if not _enough() and len(all_rows) < min_accept:
                _save_debug(last_content, f"Only {len(all_rows)} rows, need ≥{min_accept}")
                raise ValueError(f"Only {len(all_rows)} OCR rows, need ≥{min_accept}")

            if not _enough():
                print(f"  WARN {batch_key}: partial — {len(all_rows)} rows", file=sys.stderr)

            append_jsonl(output_path, all_rows)
            rows = len(all_rows)

        else:
            result = None
            for attempt in range(parse_attempts):
                result = client.complete(prompt, temperature=temperature, system=system)
                total_prompt_tokens += result.prompt_tokens
                total_completion_tokens += result.completion_tokens
                total_cost += calc_cost(result.model, result.prompt_tokens, result.completion_tokens, pricing)
                total_latency += result.latency_ms
                last_model = result.model

                try:
                    min_lines = pcfg.get("items_per_batch", 1)
                    if prompt_id == "3":
                        min_lines = pcfg.get("items_per_batch", 200)
                    elif prompt_id == "5":
                        min_lines = pcfg.get("items_per_batch", 1000)
                    rows_data = parse_jsonl(result.content, min_lines=max(1, min_lines // 2))
                    append_jsonl(output_path, rows_data)
                    rows = len(rows_data)
                    break
                except (ValueError, json.JSONDecodeError) as e:
                    if attempt < parse_attempts - 1:
                        print(f"  RETRY {batch_key} (parse failed, attempt {attempt + 1}): {e}", file=sys.stderr)
                        continue
                    _save_debug(result.content, str(e))
                    raise

        store.complete_batch(
            batch_id,
            prompt_tokens=total_prompt_tokens,
            completion_tokens=total_completion_tokens,
            cost_usd=total_cost,
            rows_generated=rows,
            latency_ms=total_latency,
            model=last_model,
        )
        return True

    except Exception as e:
        store.fail_batch(batch_id, str(e))
        print(f"  FAILED {batch_key}: {e}", file=sys.stderr)
        return False


def cmd_run(args: argparse.Namespace) -> None:
    from generator.deepseek_client import DeepSeekClient

    load_dotenv(ROOT / ".env")
    cfg = load_config()
    pricing = load_pricing()
    store = ProgressStore(DB_PATH)
    client = DeepSeekClient()

    prompt_id = str(args.prompt)
    pcfg = cfg["prompts"][prompt_id]
    temperatures = [args.temp] if args.temp else pcfg.get("temperatures", [float(__import__("os").getenv("DEFAULT_TEMPERATURE", "0.9"))])

    if args.category:
        batches = [(args.category, {"CATEGORY": args.category})]
    elif args.batch:
        all_batches = build_batch_list(prompt_id, cfg, require_seed=True)
        matches = [(k, v) for k, v in all_batches if k == args.batch]
        if not matches:
            print(f"Unknown batch: {args.batch}", file=sys.stderr)
            sys.exit(1)
        batches = matches
    elif args.all:
        batches = build_batch_list(prompt_id, cfg, require_seed=True)
    else:
        print("Specify --all, --batch KEY, or --category NAME", file=sys.stderr)
        sys.exit(1)

    # Prompt 1: run each temperature as separate batch key suffix
    expanded: list[tuple[str, dict, float]] = []
    for batch_key, variables in batches:
        for temp in temperatures:
            key = f"{batch_key}_t{str(temp).replace('.', '')}" if len(temperatures) > 1 else batch_key
            expanded.append((key, variables, temp))

    ok = fail = skip = 0
    for batch_key, variables, temp in tqdm(expanded, desc=f"Prompt {prompt_id}"):
        if not args.force and store.is_completed(prompt_id, batch_key):
            skip += 1
            continue
        if run_batch(
            prompt_id, batch_key, variables,
            temperature=temp, client=client, store=store, cfg=cfg, pricing=pricing, force=args.force,
        ):
            ok += 1
        else:
            fail += 1

    print(f"\nDone: {ok} completed, {fail} failed, {skip} skipped")
    stats = store.get_stats()
    print(f"Total cost so far: ${stats['totals'].get('total_cost_usd', 0):.4f}")
    print(f"Total rows: {stats['totals'].get('total_rows', 0):,}")


def _n(val, default=0):
    return default if val is None else val


def cmd_status(_: argparse.Namespace) -> None:
    store = ProgressStore(DB_PATH)
    stats = store.get_stats()
    t = stats["totals"]
    print("=== mitlist intelligence — generation status ===\n")
    print(f"Batches:  {_n(t.get('completed'))}/{_n(t.get('total_batches'))} completed")
    print(f"Failed:   {_n(t.get('failed'))}")
    print(f"Running:  {_n(t.get('running'))}")
    print(f"Rows:     {_n(t.get('total_rows')):,}")
    print(f"Tokens:   {_n(t.get('prompt_tokens')):,} in / {_n(t.get('completion_tokens')):,} out")
    print(f"Cost:     ${_n(t.get('total_cost_usd')):.4f}")
    print("\nBy prompt:")
    for row in stats["by_prompt"]:
        print(f"  Prompt {row['prompt_id']}: {_n(row['completed'])}/{_n(row['total'])} batches, {_n(row['rows']):,} rows, ${_n(row['cost']):.4f}")


def cmd_estimate(_: argparse.Namespace) -> None:
    cfg = load_config()
    pricing = load_pricing()
    model = __import__("os").getenv("DEEPSEEK_MODEL", "deepseek-chat")
    rates = pricing["models"][model]

    print(f"=== Cost estimate (model: {model}) ===\n")
    total_batches = 0
    for pid, pcfg in cfg["prompts"].items():
        batches = build_batch_list(pid, cfg, require_seed=False)
        n = len(batches)
        temps = len(pcfg.get("temperatures", [1]))
        if pid == "1":
            n *= temps
        total_batches += n
        est_tokens_in = 3000
        est_tokens_out = {"1": 8000, "2": 15000, "3": 12000, "4": 25000, "5": 20000}.get(pid, 10000)
        cost_per = (est_tokens_in * rates["input_per_million"] + est_tokens_out * rates["output_per_million"]) / 1_000_000
        print(f"  Prompt {pid} ({pcfg['name']}): {n} batches × ~${cost_per:.3f} ≈ ${n * cost_per:.2f}")

    print(f"\nTotal batches: {total_batches}")
    print("(Rough estimate — actual cost depends on output length)")


def cmd_dashboard(args: argparse.Namespace) -> None:
    from generator.dashboard_server import serve
    load_dotenv(ROOT / ".env")
    serve(host=args.host, port=args.port)


def main() -> None:
    parser = argparse.ArgumentParser(description="mitlist intelligence data generator")
    sub = parser.add_subparsers(dest="command", required=True)

    run_p = sub.add_parser("run", help="Run generation batches")
    run_p.add_argument("--prompt", type=int, required=True, choices=[1, 2, 3, 4, 5])
    run_p.add_argument("--all", action="store_true", help="Run all batches for this prompt")
    run_p.add_argument("--batch", type=str, help="Run a specific batch key")
    run_p.add_argument("--category", type=str, help="Prompt 1: run one category")
    run_p.add_argument("--temp", type=float, help="Override temperature")
    run_p.add_argument("--force", action="store_true", help="Re-run even if completed")
    run_p.set_defaults(func=cmd_run)

    sub.add_parser("status", help="Show generation progress").set_defaults(func=cmd_status)
    sub.add_parser("estimate", help="Estimate API cost").set_defaults(func=cmd_estimate)

    dash_p = sub.add_parser("dashboard", help="Start HTML dashboard server")
    dash_p.add_argument("--host", default=__import__("os").getenv("DASHBOARD_HOST", "127.0.0.1"))
    dash_p.add_argument("--port", type=int, default=int(__import__("os").getenv("DASHBOARD_PORT", "8765")))
    dash_p.set_defaults(func=cmd_dashboard)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
