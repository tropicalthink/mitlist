"""Export Phase 8 embeddings: sentence-transformers -> ONNX -> TFLite (onnx2tf)."""

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
OUT_DIR = Path(__file__).resolve().parent
MODELS_DIR = ROOT / "ml" / "models"

MODEL_DIR = OUT_DIR / "finetuned"
ONNX_DIR = OUT_DIR / "onnx"
TF_OUT_DIR = OUT_DIR / "onnx2tf_out"
TFLITE_OUT = MODELS_DIR / "grocery_embeddings.tflite"


def _quantize_float16(saved_model_dir: Path, out_path: Path) -> None:
    """Post-conversion float16 quantization via TFLiteConverter."""
    import tensorflow as tf  # type: ignore

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model_dir))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    out_path.write_bytes(tflite_model)


def main() -> None:
    if not MODEL_DIR.exists():
        raise SystemExit(f"Missing {MODEL_DIR}. Run train.py first.")

    ONNX_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["python3", "-m", "optimum.exporters.onnx",
         "--model", str(MODEL_DIR),
         "--task", "feature-extraction",
         str(ONNX_DIR)],
        check=True,
    )

    # onnx2tf writes a set of .tflite files into TF_OUT_DIR
    subprocess.run(
        ["onnx2tf", "-i", str(ONNX_DIR / "model.onnx"),
         "-o", str(TF_OUT_DIR), "-osd"],
        check=True,
    )

    # Prefer float16 quantized tflite if onnx2tf produced one; otherwise
    # apply a post-conversion float16 pass via TFLiteConverter.
    float16_candidates = sorted(TF_OUT_DIR.glob("*float16*.tflite"))
    float32_candidates = sorted(TF_OUT_DIR.glob("*float32*.tflite")) or sorted(TF_OUT_DIR.glob("*.tflite"))

    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    if float16_candidates:
        # onnx2tf already produced a float16 tflite — use it directly.
        shutil.copyfile(float16_candidates[0], TFLITE_OUT)
        print(f"Using onnx2tf float16 output: {float16_candidates[0].name}")
    else:
        # Apply float16 quantization via TFLiteConverter from the SavedModel.
        saved_model_dir = TF_OUT_DIR  # onnx2tf -osd writes SavedModel here
        print("No float16 tflite from onnx2tf; applying TFLiteConverter float16 pass …")
        _quantize_float16(saved_model_dir, TFLITE_OUT)

    if not TFLITE_OUT.exists() or TFLITE_OUT.stat().st_size == 0:
        raise SystemExit(f"TFLite export failed — {TFLITE_OUT} missing or empty")

    size_mb = TFLITE_OUT.stat().st_size / (1024 * 1024)
    print(f"grocery_embeddings.tflite = {size_mb:.1f} MB")
    if size_mb > 40:
        print("WARNING: >40 MB — likely too large to bundle on-device. See plan 027 decision gate.")


if __name__ == "__main__":
    main()
