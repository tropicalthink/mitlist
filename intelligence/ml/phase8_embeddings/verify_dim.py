"""Prints the embedding dimension of the finetuned model. Expect 128."""
from pathlib import Path
from sentence_transformers import SentenceTransformer

MODEL_DIR = Path(__file__).resolve().parent / "finetuned"
m = SentenceTransformer(str(MODEL_DIR))
vec = m.encode(["Hafermilch"])
print("embedding dim:", vec.shape[-1])
