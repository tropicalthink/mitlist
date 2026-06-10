"""Phase 7 — OCR classifier training (character trigram bag + dense head)."""

import json
import pickle
import re
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = ROOT / "ml" / "data"
OUT_DIR = Path(__file__).resolve().parent


def load_corpus(paths: list[Path]) -> list[tuple[str, str]]:
    rows = []
    for p in paths:
        if not p.exists():
            print(f"Skipping missing {p}")
            continue
        for line in p.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            obj = json.loads(line)
            raw = obj.get("raw", "").strip().lower()
            canonical = (obj.get("item_de") or obj.get("correct_canonical_de", "")).strip()
            if raw and canonical:
                rows.append((raw, canonical))
        print(f"Loaded {len(rows)} rows from {p}")
    return rows


def char_trigrams(text: str, max_len: int = 64) -> str:
    t = text.lower()[:max_len - 4]
    return " ".join(t[i : i + 3] for i in range(len(t) - 2)) if len(t) > 2 else t


def main() -> None:
    rows = load_corpus([DATA_DIR / "ocr_corpus.jsonl", DATA_DIR / "corrections.jsonl"])
    if len(rows) < 100:
        raise SystemExit(f"Need ≥100 training rows, got {len(rows)}. Generate Prompt 2 + 5 data first.")

    texts = [r[0] for r in rows]
    labels = [r[1] for r in rows]

    le = LabelEncoder()
    y = le.fit_transform(labels)
    num_classes = len(le.classes_)
    print(f"{num_classes} canonical classes, {len(texts)} examples")

    with open(OUT_DIR / "label_encoder.pkl", "wb") as f:
        pickle.dump(le, f)

    X_train, X_val, y_train, y_val = train_test_split(
        texts, y, test_size=0.1, random_state=42, stratify=y
    )

    X_train_ng = [char_trigrams(t) for t in X_train]
    X_val_ng = [char_trigrams(t) for t in X_val]

    vectorizer = tf.keras.layers.TextVectorization(max_tokens=8000, output_mode="tf_idf")
    vectorizer.adapt(X_train_ng)

    inputs = tf.keras.Input(shape=(1,), dtype=tf.string, name="raw_text")
    x = vectorizer(inputs)
    x = tf.keras.layers.Dense(512, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(256, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.2)(x)
    outputs = tf.keras.layers.Dense(num_classes, activation="softmax", name="probs")(x)

    model = tf.keras.Model(inputs, outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.summary()

    ds_train = (
        tf.data.Dataset.from_tensor_slices((np.array(X_train_ng, dtype=object), np.array(y_train)))
        .shuffle(10000)
        .batch(256)
    )
    ds_val = tf.data.Dataset.from_tensor_slices(
        (np.array(X_val_ng, dtype=object), np.array(y_val))
    ).batch(256)

    callbacks = [
        tf.keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3),
        tf.keras.callbacks.ModelCheckpoint(str(OUT_DIR / "best.keras"), save_best_only=True),
    ]

    model.fit(ds_train, validation_data=ds_val, epochs=50, callbacks=callbacks)

    val_probs = model.predict(np.array(X_val_ng, dtype=object), batch_size=512)
    top5 = np.argsort(val_probs, axis=1)[:, -5:]
    top1 = float(np.mean(np.argmax(val_probs, 1) == y_val))
    top5_acc = float(np.mean([y_val[i] in top5[i] for i in range(len(y_val))]))
    print(f"Top-1 accuracy: {top1:.3f}")
    print(f"Top-5 accuracy: {top5_acc:.3f}")

    model.save(OUT_DIR / "model.keras")

    # Update progress DB with model version
    try:
        import sys
        sys.path.insert(0, str(ROOT))
        from datetime import datetime, timezone
        from generator.progress import ProgressStore

        store = ProgressStore(ROOT / "progress.db")
        store.update_model_version(
            "grocery_classifier",
            version="1.0.0",
            status="trained",
            metadata={
                "top1_accuracy": top1,
                "top5_accuracy": top5_acc,
                "num_classes": num_classes,
                "trained_on": datetime.now(timezone.utc).isoformat(),
            },
        )
    except Exception as e:
        print(f"Could not update model version in DB: {e}")


if __name__ == "__main__":
    main()
