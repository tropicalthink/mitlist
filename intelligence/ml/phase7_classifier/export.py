"""Export Phase 7 classifier to TFLite."""

import pickle
from pathlib import Path

import tensorflow as tf

ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR = Path(__file__).resolve().parent
MODELS_DIR = ROOT / "ml" / "models"


def main() -> None:
    model = tf.keras.models.load_model(OUT_DIR / "model.keras")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    out = MODELS_DIR / "grocery_classifier.tflite"
    out.write_bytes(tflite_model)
    print(f"Saved {len(tflite_model) / 1024:.0f} KB → {out}")

    with open(OUT_DIR / "label_encoder.pkl", "rb") as f:
        le = pickle.load(f)

    labels_path = MODELS_DIR / "grocery_classifier_labels.txt"
    labels_path.write_text("\n".join(le.classes_))
    print(f"Labels: {len(le.classes_)} classes → {labels_path}")


if __name__ == "__main__":
    main()
