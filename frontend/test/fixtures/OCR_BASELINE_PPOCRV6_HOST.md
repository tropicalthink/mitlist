# PP-OCRv6 portable host baseline

Recorded 2026-07-21 with the production Dart implementation on Linux CPU using
ONNX Runtime 1.20.0, `PP-OCRv6_small_det`, and `PP-OCRv6_medium_rec`. All six
images were processed locally. No cloud service or platform OCR API was used.

The detector input is capped at 1600 pixels on its long edge. Detection DB
post-processing, crop construction, CTC decoding, same-row fragment merging,
and strikethrough analysis are implemented in shared Dart code.

## Aggregate

| Metric | Result |
|---|---:|
| Readable ground-truth lines | 45 |
| Crossed-out ground-truth lines | 6 |
| Illegible regions | 2 |
| Character error rate | 20.49% |
| Word error rate | 64.91% |
| Readable-line recall | 97.78% |
| Exact-line rate | 37.78% |
| Crossed-out detection recall | 100.00% |
| Unmatched predictions | 3 |
| Mean end-to-end latency | 4464.67 ms |

The latency is a desktop Flutter-test measurement and is not an Android/iOS
performance claim. A connected-device run is required before release.

## Comparison with the legacy Android ML Kit baseline

| Metric | ML Kit | PP-OCRv6 portable |
|---|---:|---:|
| Character error rate | 45.19% | **20.49%** |
| Word error rate | 82.46% | **64.91%** |
| Readable-line recall | 60.00% | **97.78%** |
| Exact-line rate | 13.33% | **37.78%** |
| Crossed-out detection recall | 0.00% | **100.00%** |

Known weaknesses remain on the hardest German handwriting (`001`, `003`, and
`006`), and recognizer confidence is over-optimistic on some wrong outputs.
Confidence is therefore retained as review evidence, not treated as proof that
a transcription is correct. The current portable decoder retains a bounded CTC
beam for local grocery/household resolution, and the strike-through detector
checks shallow diagonal strokes as well as horizontal ink coverage.
