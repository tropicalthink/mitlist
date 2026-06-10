"""Phase 8 — Multilingual embedding fine-tuning with triplet loss."""

import json
import random
import sys
from pathlib import Path

import torch
from sentence_transformers import InputExample, SentenceTransformer, losses
from sentence_transformers.evaluation import TripletEvaluator
from sentence_transformers.models import Dense
from torch.utils.data import DataLoader

ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = ROOT / "ml" / "data"
OUT_DIR = Path(__file__).resolve().parent


def load_triplets(path: Path) -> list[InputExample]:
    examples: list[InputExample] = []
    if not path.exists():
        raise SystemExit(f"Missing {path}. Generate Prompt 3 data first.")

    lines = path.read_text(encoding="utf-8").splitlines()
    for line in lines:
        if not line.strip():
            continue
        obj = json.loads(line)
        anchor = obj["anchor_de"]
        positive = obj["positive_text"]
        negative = obj.get("negative_de") or obj.get("negative_en", "")
        if anchor and positive and negative:
            examples.append(InputExample(texts=[anchor, positive, negative]))

    for line in lines:
        if not line.strip():
            continue
        obj = json.loads(line)
        for lang_pair in [
            ("anchor_de", "anchor_en"),
            ("anchor_de", "anchor_fr"),
            ("anchor_en", "anchor_es"),
            ("anchor_fr", "anchor_es"),
        ]:
            a, b = obj.get(lang_pair[0]), obj.get(lang_pair[1])
            neg = obj.get("negative_en") or obj.get("negative_de", "unknown")
            if a and b and a != b:
                examples.append(InputExample(texts=[a, b, neg]))

    print(f"Loaded {len(examples)} triplets")
    return examples


def main() -> None:
    examples = load_triplets(DATA_DIR / "triplets.jsonl")

    model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
    dense = Dense(
        in_features=model.get_sentence_embedding_dimension(),
        out_features=128,
        activation_function=torch.nn.Tanh(),
    )
    model.add_module("dense_projection", dense)

    loader = DataLoader(examples, shuffle=True, batch_size=64)
    loss = losses.TripletLoss(
        model=model,
        distance_metric=losses.TripletDistanceMetric.COSINE,
        triplet_margin=0.3,
    )

    random.shuffle(examples)
    eval_ex = examples[: min(500, len(examples))]
    evaluator = TripletEvaluator(
        anchors=[e.texts[0] for e in eval_ex],
        positives=[e.texts[1] for e in eval_ex],
        negatives=[e.texts[2] for e in eval_ex],
        name="grocery_triplets",
    )

    model.fit(
        train_objectives=[(loader, loss)],
        evaluator=evaluator,
        epochs=10,
        warmup_steps=100,
        output_path=str(OUT_DIR / "finetuned"),
        save_best_model=True,
        show_progress_bar=True,
    )

    print(f"Training complete → {OUT_DIR / 'finetuned'}")

    try:
        sys.path.insert(0, str(ROOT))
        from datetime import datetime, timezone
        from generator.progress import ProgressStore

        store = ProgressStore(ROOT / "progress.db")
        store.update_model_version(
            "grocery_embeddings",
            version="1.0.0",
            status="trained",
            metadata={
                "base_model": "paraphrase-multilingual-MiniLM-L12-v2",
                "num_triplets": len(examples),
                "trained_on": datetime.now(timezone.utc).isoformat(),
            },
        )
    except Exception as e:
        print(f"Could not update model version in DB: {e}")


if __name__ == "__main__":
    main()
