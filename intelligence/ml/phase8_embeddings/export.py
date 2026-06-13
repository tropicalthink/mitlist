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

    # Pick the float32 (or float16) tflite onnx2tf produced and copy it out.
    candidates = sorted(TF_OUT_DIR.glob("*float32*.tflite")) or sorted(TF_OUT_DIR.glob("*.tflite"))
    if not candidates:
        raise SystemExit(f"onnx2tf produced no .tflite in {TF_OUT_DIR}")
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(candidates[0], TFLITE_OUT)
    print(f"Saved {TFLITE_OUT.stat().st_size / 1024 / 1024:.1f} MB → {TFLITE_OUT} (from {candidates[0].name})")


if __name__ == "__main__":
    main()
