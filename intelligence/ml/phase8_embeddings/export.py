"""Export Phase 8 embeddings: sentence-transformers → ONNX → TFLite."""

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR = Path(__file__).resolve().parent
MODELS_DIR = ROOT / "ml" / "models"

MODEL_DIR = OUT_DIR / "finetuned"
ONNX_DIR = OUT_DIR / "onnx"
TFLITE_OUT = MODELS_DIR / "grocery_embeddings.tflite"


def main() -> None:
    if not MODEL_DIR.exists():
        raise SystemExit(f"Missing {MODEL_DIR}. Run train.py first.")

    ONNX_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "python", "-m", "optimum.exporters.onnx",
            "--model", str(MODEL_DIR),
            "--task", "feature-extraction",
            str(ONNX_DIR),
        ],
        check=True,
    )

    pb_dir = OUT_DIR / "model.pb"
    subprocess.run(
        [
            "python", "-m", "tf2onnx.convert",
            "--onnx", str(ONNX_DIR / "model.onnx"),
            "--output", str(pb_dir),
            "--opset", "13",
        ],
        check=True,
    )

    import tensorflow as tf

    converter = tf.lite.TFLiteConverter.from_saved_model(str(pb_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite = converter.convert()

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    TFLITE_OUT.write_bytes(tflite)
    print(f"Saved {len(tflite) / 1024 / 1024:.1f} MB → {TFLITE_OUT}")


if __name__ == "__main__":
    main()
