"""Export Phase 7 classifier to Flex-free TFLite.

The original model's TextVectorization (TF-IDF) layer is stripped from the
TFLite graph.  Vectorisation is now client-side: the Dart runtime reads
grocery_classifier_vocab.json (vocab + IDF weights), reproduces the TF-IDF
vector, and feeds a float32 input directly to the dense layers.

Outputs written to intelligence/ml/models/:
  grocery_classifier.tflite       — Flex-free quantised model (float32 input)
  grocery_classifier_labels.txt   — one label per line (le.classes_ order)
  grocery_classifier_vocab.json   — {"vocab":…, "idf":…, "max_len":64, "strip_chars":…}
  grocery_classifier_golden.json  — end-to-end reference predictions (original model)
"""

import json
import pickle
import string
from pathlib import Path

import tensorflow as tf

from train import char_trigrams

ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR = Path(__file__).resolve().parent
MODELS_DIR = ROOT / "ml" / "models"


def main() -> None:
    # ------------------------------------------------------------------ #
    # 1. Load original model and extract TextVectorization layer           #
    # ------------------------------------------------------------------ #
    model = tf.keras.models.load_model(OUT_DIR / "model.keras")

    vectorizer = None
    for layer in model.layers:
        if isinstance(layer, tf.keras.layers.TextVectorization):
            vectorizer = layer
            break
    if vectorizer is None:
        raise RuntimeError("No TextVectorization layer found in model.keras")

    vocab = vectorizer.get_vocabulary()           # list[str], idx 0="" idx 1="[UNK]"
    idf = [float(w) for w in vectorizer.idf_weights.numpy()]  # same length as vocab

    # ------------------------------------------------------------------ #
    # 2. Build a NEW model with float TF-IDF input (reuse dense layers)   #
    # ------------------------------------------------------------------ #
    vec_len = len(vocab)
    inp = tf.keras.Input(shape=(vec_len,), dtype=tf.float32, name="tfidf")
    x = inp
    for layer in model.layers:
        if isinstance(layer, (tf.keras.layers.InputLayer,
                               tf.keras.layers.TextVectorization)):
            continue
        x = layer(x)
    dense_model = tf.keras.Model(inp, x)

    # ------------------------------------------------------------------ #
    # 3. Convert with builtins only — NO SELECT_TF_OPS                    #
    # ------------------------------------------------------------------ #
    converter = tf.lite.TFLiteConverter.from_keras_model(dense_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    out = MODELS_DIR / "grocery_classifier.tflite"
    out.write_bytes(tflite_model)
    print(f"Saved {len(tflite_model) / 1024:.0f} KB → {out}")

    # ------------------------------------------------------------------ #
    # 4. Labels from label_encoder.pkl                                     #
    # ------------------------------------------------------------------ #
    with open(OUT_DIR / "label_encoder.pkl", "rb") as f:
        le = pickle.load(f)

    labels_path = MODELS_DIR / "grocery_classifier_labels.txt"
    labels_path.write_text("\n".join(le.classes_))
    print(f"Labels: {len(le.classes_)} classes → {labels_path}")

    # ------------------------------------------------------------------ #
    # 5. Vocab + IDF JSON for client-side vectorisation                   #
    # ------------------------------------------------------------------ #
    vocab_path = MODELS_DIR / "grocery_classifier_vocab.json"
    json.dump(
        {"vocab": vocab, "idf": idf, "max_len": 64, "strip_chars": string.punctuation},
        open(vocab_path, "w"),
    )
    print(f"Vocab: {len(vocab)} tokens → {vocab_path}")

    # ------------------------------------------------------------------ #
    # 6. Golden references (end-to-end, using the ORIGINAL string model)  #
    # ------------------------------------------------------------------ #
    samples = ["Vollmilch", "0at M1lk", "Bananen", "Joghurt natur", "Hähnchenbrust"]
    golden = []
    for raw in samples:
        probs = model.predict([[char_trigrams(raw)]], verbose=0)[0]
        top5 = probs.argsort()[-5:][::-1].tolist()
        golden.append({
            "raw": raw,
            "top5_indices": top5,
            "top5_labels": [le.classes_[i] for i in top5],
        })
    golden_path = MODELS_DIR / "grocery_classifier_golden.json"
    json.dump(golden, open(golden_path, "w"))
    print(f"Golden: {len(golden)} samples → {golden_path}")


if __name__ == "__main__":
    main()
