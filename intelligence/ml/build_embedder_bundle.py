#!/usr/bin/env python3
"""Build the static embedding bundle for on-device semantic grocery search.

Architecture:
  Teacher model (green-list, run at build time only):
    - Preferred: local Phase-8 fine-tuned model (intelligence/ml/phase8_embeddings/)
    - Fallback:  intfloat/multilingual-e5-small  (Apache-2.0)
    - Alt:       Alibaba-NLP/gte-multilingual-base (Apache-2.0)
  Distillation via Model2Vec (MIT licence):
    - Custom vocabulary from data/embedder_vocab.txt (word/phrase-level).
    - Dart tokenizer: lowercase → whitespace split → greedy longest-match phrases
      → char-trigram OOV fallback (Plan 026 charTrigrams reuse).
    - int8 quantisation + optional PCA dimension reduction.
  Outputs (all versioned, format mirrors build_app_seed.py):
    frontend/assets/grocery/embedder_vocab.json
    frontend/assets/grocery/catalog_vectors.json
    frontend/assets/grocery/embedder_golden.json

Run (maintainer, needs model weights + model2vec + sentence-transformers):
  pip install model2vec sentence-transformers numpy
  python3 intelligence/ml/build_embedder_bundle.py

The executor only `python3 -m py_compile`s this file; the maintainer runs it.

Green-list licence sources used by this script:
  - Model2Vec            MIT  (https://github.com/MinishLab/model2vec)
  - multilingual-e5-small  Apache-2.0  (intfloat/multilingual-e5-small)
  - gte-multilingual-base  Apache-2.0  (Alibaba-NLP/gte-multilingual-base)
  - Open Food Facts vocab  ODbL  (attribute; index kept separable via off_enrich_seed.py)
"""
import argparse
import json
import pathlib
import struct
from typing import Optional

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DATA = HERE / "data"
ASSET_DIR = ROOT / "frontend" / "assets" / "grocery"

# Bundle version — bump whenever the matrix layout or vocab changes.
ASSET_VERSION = 1

# Default teacher model; override via --teacher.
# The Phase-8 SentenceTransformer is saved under phase8_embeddings/finetuned/
# (that dir holds modules.json / config_sentence_transformers.json).
DEFAULT_TEACHER = str(HERE / "phase8_embeddings" / "finetuned")
FALLBACK_TEACHER = "intfloat/multilingual-e5-small"

# Target embedding dim after PCA (keeps bundle small, ~2-3 MB for 3 k items).
TARGET_DIM = 128

# Number of golden queries per language for the Dart parity test.
GOLDEN_QUERIES_PER_LANG = 10


# ── Utility ──────────────────────────────────────────────────────────────────

def _load_vocab(path: pathlib.Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    return [l.strip() for l in lines if l.strip()]


def _load_seed(path: pathlib.Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))


def _preferred_name(item: dict, lang: str = "en") -> str:
    """Return the preferred display name for a seed item in the given language."""
    return item.get(f"name_{lang}") or item.get("name_en") or item.get("name_de") or ""


def _all_query_name_pairs(seed: list[dict]) -> list[tuple[str, str]]:
    """Build (query_text, item_id) pairs for golden-file generation."""
    pairs: list[tuple[str, str]] = []
    # Use build_app_seed's slugify logic to derive item_id
    import unicodedata, re
    def slugify(s: str) -> str:
        s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
        s = re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower()
        return s or "item"

    seen: dict[str, int] = {}
    for item in seed:
        base = slugify(item.get("name_en") or item.get("name_de") or "")
        iid = base
        n = 2
        while iid in seen:
            iid = f"{base}_{n}"; n += 1
        seen[iid] = 1
        for lang in ["de", "en", "fr", "es"]:
            name = item.get(f"name_{lang}", "")
            if name:
                pairs.append((name.lower(), iid))
    return pairs


# ── int8 quantisation helpers ─────────────────────────────────────────────────

def _quantise_int8(matrix: np.ndarray) -> tuple[np.ndarray, float]:
    """Quantise a float32 matrix to int8, returning (int8_matrix, scale).

    Dequantise in Dart: float_vec[i] = int8_vec[i] * scale
    Scale = max_abs / 127.0
    """
    max_abs = np.abs(matrix).max()
    if max_abs == 0:
        return matrix.astype(np.int8), 1.0
    scale = float(max_abs / 127.0)
    quantised = np.clip(np.round(matrix / scale), -128, 127).astype(np.int8)
    return quantised, scale


def _matrix_to_nested_list(matrix: np.ndarray) -> list[list[int]]:
    """Convert a 2-D int8 numpy array to a JSON-serialisable nested list."""
    return matrix.tolist()


# ── Embedder distillation ─────────────────────────────────────────────────────

def _load_teacher(teacher_path: str):
    """Load a SentenceTransformer model, with fallback to the public model."""
    from sentence_transformers import SentenceTransformer  # type: ignore
    tp = pathlib.Path(teacher_path)
    if tp.exists():
        print(f"[build_embedder] Loading local teacher from {tp}")
        return SentenceTransformer(str(tp))
    print(f"[build_embedder] Local teacher not found at {tp}; using {FALLBACK_TEACHER}")
    return SentenceTransformer(FALLBACK_TEACHER)


def _distill(teacher, vocab: list[str], target_dim: int) -> tuple[np.ndarray, int]:
    """Distil the teacher into a static embedder and emit one vector per vocab entry.

    Model2Vec's ``distill_from_model`` builds a static lookup table from the
    teacher's *token* embeddings (optionally PCA-reduced to ``target_dim``).
    We then ``StaticModel.encode`` each custom-vocab string so the returned
    matrix is row-aligned to ``vocab`` (multi-word phrases are encoded by
    tokenising + mean-pooling, exactly mirroring the Dart runtime's per-token
    mean-pool). The result is the (len(vocab) × final_dim) matrix the rest of
    this script and StaticEmbeddingService.dart expect.

    Returns: (float32 matrix of shape [len(vocab), final_dim], final_dim)
    """
    try:
        from model2vec.distill import distill_from_model  # type: ignore
    except ImportError:
        raise SystemExit(
            "model2vec[distill] is required: pip install 'model2vec[distill]'\n"
            "See https://github.com/MinishLab/model2vec for the API."
        )

    # Pull the underlying HF transformer + tokenizer out of the SentenceTransformer.
    transformer = teacher[0]
    hf_model = transformer.auto_model
    tokenizer = getattr(transformer, "tokenizer", None) or teacher.tokenizer

    print(f"[build_embedder] Distilling teacher → static table (pca_dims={target_dim}) …")
    static_model = distill_from_model(
        model=hf_model,
        tokenizer=tokenizer,
        pca_dims=target_dim,
    )

    print(f"[build_embedder] Encoding {len(vocab)} vocab entries with the static model …")
    matrix = np.asarray(
        static_model.encode(vocab, show_progress_bar=True),
        dtype=np.float32,
    )

    actual_dim = matrix.shape[1]
    print(f"[build_embedder] Vocab matrix shape: {matrix.shape}")
    return matrix, actual_dim


# ── Catalog embedding ─────────────────────────────────────────────────────────

def _embed_catalog(
    seed: list[dict],
    vocab: list[str],
    matrix: np.ndarray,
) -> tuple[list[str], np.ndarray]:
    """Embed every canonical item's preferred name using the static model.

    Tokenisation: lowercase → split on whitespace → greedy longest-match phrase
    from vocab_set → mean-pool token vectors. Same logic as StaticEmbeddingService.dart.

    Returns: (item_ids, catalog_matrix float32 [n_items × dim])
    """
    import unicodedata, re

    vocab_set = set(vocab)
    # Sort by descending length for greedy longest-match
    sorted_phrases = sorted((v for v in vocab if " " in v), key=len, reverse=True)
    token_to_idx = {v: i for i, v in enumerate(vocab)}

    def _embed_text(text: str) -> np.ndarray:
        t = text.lower().strip()
        tokens: list[str] = []
        # Greedy longest-match
        remaining = t
        while remaining:
            matched = False
            for phrase in sorted_phrases:
                if remaining.startswith(phrase):
                    tokens.append(phrase)
                    remaining = remaining[len(phrase):].lstrip()
                    matched = True
                    break
            if not matched:
                # Single whitespace-split word
                parts = remaining.split(None, 1)
                word = parts[0]
                remaining = parts[1] if len(parts) > 1 else ""
                if word in token_to_idx:
                    tokens.append(word)
                # else: OOV dropped (trigram fallback handled in Dart only)
        if not tokens:
            return np.zeros(matrix.shape[1], dtype=np.float32)
        idxs = [token_to_idx[t] for t in tokens if t in token_to_idx]
        if not idxs:
            return np.zeros(matrix.shape[1], dtype=np.float32)
        vecs = matrix[idxs]
        return vecs.mean(axis=0)

    # Derive item IDs (mirror build_app_seed.py slugify)
    def slugify(s: str) -> str:
        s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
        s = re.sub(r"[^a-zA-Z0-9]+", "_", s).strip("_").lower()
        return s or "item"

    seen: dict[str, int] = {}
    item_ids: list[str] = []
    catalog_vecs: list[np.ndarray] = []

    for item in seed:
        base = slugify(item.get("name_en") or item.get("name_de") or "")
        iid = base
        n = 2
        while iid in seen:
            iid = f"{base}_{n}"; n += 1
        seen[iid] = 1
        item_ids.append(iid)
        # Use English name for embedding (widest multilingual coverage)
        name = item.get("name_en") or item.get("name_de") or ""
        catalog_vecs.append(_embed_text(name))

    catalog_matrix = np.stack(catalog_vecs, axis=0).astype(np.float32)
    # L2-normalise rows for cosine via dot product
    norms = np.linalg.norm(catalog_matrix, axis=1, keepdims=True)
    norms = np.where(norms == 0, 1.0, norms)
    catalog_matrix = catalog_matrix / norms
    return item_ids, catalog_matrix


# ── Golden file generation ────────────────────────────────────────────────────

def _build_golden(
    seed: list[dict],
    item_ids: list[str],
    vocab: list[str],
    matrix: np.ndarray,
    catalog_matrix: np.ndarray,
    queries_per_lang: int = GOLDEN_QUERIES_PER_LANG,
) -> list[dict]:
    """Generate golden (query → top-5 item IDs) entries for Dart parity testing.

    Uses the Python embed+cosine so the Dart implementation can be validated.
    """
    sorted_phrases = sorted((v for v in vocab if " " in v), key=len, reverse=True)
    token_to_idx = {v: i for i, v in enumerate(vocab)}

    def _embed(text: str) -> np.ndarray:
        t = text.lower().strip()
        tokens: list[str] = []
        remaining = t
        while remaining:
            matched = False
            for phrase in sorted_phrases:
                if remaining.startswith(phrase):
                    tokens.append(phrase)
                    remaining = remaining[len(phrase):].lstrip()
                    matched = True
                    break
            if not matched:
                parts = remaining.split(None, 1)
                word = parts[0]
                remaining = parts[1] if len(parts) > 1 else ""
                if word in token_to_idx:
                    tokens.append(word)
        if not tokens:
            return np.zeros(matrix.shape[1], dtype=np.float32)
        idxs = [token_to_idx[t] for t in tokens if t in token_to_idx]
        if not idxs:
            return np.zeros(matrix.shape[1], dtype=np.float32)
        vecs = matrix[idxs]
        vec = vecs.mean(axis=0).astype(np.float32)
        norm = np.linalg.norm(vec)
        return vec / norm if norm > 0 else vec

    # Sample golden queries: use canonical names in all 4 languages
    golden: list[dict] = []
    seen_queries: set[str] = set()
    item_id_set = set(item_ids)

    for lang in ["de", "en", "fr", "es"]:
        count = 0
        for item in seed:
            if count >= queries_per_lang:
                break
            name = item.get(f"name_{lang}", "")
            if not name or name.lower() in seen_queries:
                continue
            query = name.lower()
            seen_queries.add(query)
            qvec = _embed(query)
            scores = catalog_matrix @ qvec
            top5_idx = np.argsort(scores)[::-1][:5]
            top5_ids = [item_ids[i] for i in top5_idx]
            golden.append({
                "query": query,
                "lang": lang,
                "top5_item_ids": top5_ids,
            })
            count += 1

    return golden


# ── Writers ───────────────────────────────────────────────────────────────────

def _write_vocab_bundle(
    vocab: list[str],
    matrix: np.ndarray,
    dim: int,
    out_path: pathlib.Path,
) -> None:
    """Write embedder_vocab.json."""
    quant, scale = _quantise_int8(matrix)
    payload = {
        "version": ASSET_VERSION,
        "dim": dim,
        "vocab": vocab,
        "vectors_int8": _matrix_to_nested_list(quant),
        "scale": scale,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    size_mb = out_path.stat().st_size / 1_000_000
    print(f"[build_embedder] vocab bundle → {out_path} ({size_mb:.2f} MB, {len(vocab)} tokens)")


def _write_catalog_bundle(
    item_ids: list[str],
    catalog_matrix: np.ndarray,
    dim: int,
    out_path: pathlib.Path,
) -> None:
    """Write catalog_vectors.json."""
    quant, scale = _quantise_int8(catalog_matrix)
    payload = {
        "version": ASSET_VERSION,
        "dim": dim,
        "item_ids": item_ids,
        "vectors_int8": _matrix_to_nested_list(quant),
        "scale": scale,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    size_mb = out_path.stat().st_size / 1_000_000
    print(f"[build_embedder] catalog bundle → {out_path} ({size_mb:.2f} MB, {len(item_ids)} items)")


def _write_golden(golden: list[dict], out_path: pathlib.Path) -> None:
    payload = {
        "version": ASSET_VERSION,
        "entries": golden,
    }
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"[build_embedder] golden file → {out_path} ({len(golden)} entries)")


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--teacher", default=DEFAULT_TEACHER,
                    help="Path or HF model ID for the teacher SentenceTransformer")
    ap.add_argument("--vocab", default=str(DATA / "embedder_vocab.txt"),
                    help="Custom vocab file (from off_enrich_seed.py)")
    ap.add_argument("--seed", default=str(DATA / "seed_enriched.json"),
                    help="Enriched seed (or seed.json if off_enrich was skipped)")
    ap.add_argument("--dim", type=int, default=TARGET_DIM,
                    help="Target embedding dimension after PCA")
    ap.add_argument("--golden-per-lang", type=int, default=GOLDEN_QUERIES_PER_LANG,
                    help="Number of golden queries per language")
    ap.add_argument("--out-dir", default=str(ASSET_DIR),
                    help="Output directory for bundle JSON files")
    args = ap.parse_args()

    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    vocab_path = pathlib.Path(args.vocab)
    seed_path = pathlib.Path(args.seed)
    if not seed_path.exists():
        # Fall back to base seed
        seed_path = DATA / "seed.json"
        print(f"[build_embedder] seed_enriched.json not found; using {seed_path}")

    print(f"[build_embedder] Loading vocab from {vocab_path}")
    vocab = _load_vocab(vocab_path)
    print(f"[build_embedder] {len(vocab)} vocab tokens.")

    print(f"[build_embedder] Loading seed from {seed_path}")
    seed = _load_seed(seed_path)
    print(f"[build_embedder] {len(seed)} canonical items.")

    teacher = _load_teacher(args.teacher)

    matrix, actual_dim = _distill(teacher, vocab, args.dim)

    print(f"[build_embedder] Embedding catalog ({len(seed)} items) …")
    item_ids, catalog_matrix = _embed_catalog(seed, vocab, matrix)

    print(f"[build_embedder] Building golden file …")
    golden = _build_golden(seed, item_ids, vocab, matrix, catalog_matrix,
                           queries_per_lang=args.golden_per_lang)

    _write_vocab_bundle(vocab, matrix, actual_dim, out_dir / "embedder_vocab.json")
    _write_catalog_bundle(item_ids, catalog_matrix, actual_dim, out_dir / "catalog_vectors.json")
    _write_golden(golden, out_dir / "embedder_golden.json")

    print("[build_embedder] Done.")


if __name__ == "__main__":
    main()
