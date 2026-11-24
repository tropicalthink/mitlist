# Handwriting recognizer bake-off

Recorded 2026-07-21 against the six private list photographs and 45 readable
ground-truth lines in `ocr_eval_manifest.json`. Photos and extracted crops stay
outside the repository.

The comparison holds `PP-OCRv6_small_det` fixed and changes only line
recognition. Candidate recognizers receive the same correctly detected,
reading-order line crops. Metrics use the committed OCR scorer.

## Results

| Recognizer | CER | Exact lines | Mean recognition latency/page | Approx. recognizer size | Decision |
|---|---:|---:|---:|---:|---|
| Production PP-OCRv6 medium CTC | **20.49%** | 37.78% | 4465 ms* | 74 MB | Keep |
| PP-OCRv6 control on bake-off crops | 22.22% | 40.00% | 1660 ms | 74 MB | Control only |
| Microsoft TrOCR-small-handwritten | 660.25% | 0.00% | 38585 ms | 246 MB FP32 | Reject |
| Multicentury HTR small ONNX | 44.94% | 6.67% | 3810 ms | 238 MB | Reject |
| German TrOCR-small | 79.51% | 0.00% | 3627 ms | 246 MB FP32 | Reject |
| Strict PP-OCR CTC lexicon prototype | 21.48% | 51.11% | 1718 ms | existing model | Do not ship yet |

\*The production baseline is a desktop Flutter end-to-end measurement, while
candidate latency measures host recognition after crop extraction. Treat the
numbers as relative diagnostics, not mobile performance claims.

## Findings

- The crops are valid. TrOCR's official IAM example was also checked and
  produced the expected `industry` transcription, ruling out a broken model
  load. Its failures here are domain transfer failures.
- Autoregressive HTR models hallucinated fluent but unrelated text when a short
  grocery crop was ambiguous. Examples included Wikipedia-like boilerplate from
  the English model and plausible unrelated German words from the German model.
- The Finnish/Swedish multicentury ONNX model transferred better than TrOCR's
  IAM checkpoint but still doubled the production character error rate while
  adding roughly 238 MB of model data.
- Forced CTC lexicon scoring improved exact matches on the six samples, but it
  also introduced confident semantic substitutions such as `Olivenöl` →
  `Olivenbrot`, `Reis` → `Redfish`, and `Kartoffeln` → `Kartoffelmehl`. Tuning
  those thresholds on six samples would overfit the evaluation set, so the
  prototype is not production code.

## Household lexicon decoding (2026-10-31, shipped)

The catalog-only prototype failed because 12,000 catalog names hold close
look-alikes for almost every word. A household's own vocabulary does not, and
its purchase history says which of its words are likely. The shipped decoder
(`PpOcrProcessor.decodeLineWithLexicon`) is a noisy channel per visual line:

- score = CTC forward log-likelihood of the reading + log prior;
- candidates: the recognizer's own reading (prior: P(unknown word) times a
  character-bigram model over catalog names), the household's vocabulary
  (lists, aliases, purchases; prior by use count), and the 30 catalog names
  closest in spelling (cold start);
- a candidate may span the line's fragments (split at spaces and hyphens) and
  may carry a leading bullet;
- **visual guard**: a candidate must explain the image within 1.5 nats per
  raw character of the recognizer's own reading. Priors pick between words the
  pixels support; they never make the decoder see a word that is not there.
- crossed-out lines are left as read.

Six samples, production path, household simulated as 250 random catalog items
plus each written word with probability *re-add* (three households each):

| Decoder | Active lines read exactly |
|---|---:|
| Before (greedy + beam alternatives) | 17/39 (44%) |
| Catalog cold start, no shared words | 23/39 (59%) |
| Household, 50% re-add | 26–29/39 (67–74%) |
| Household, 80% re-add | 29–30/39 (74–77%) |
| Household, 100% re-add | 32/39 (82%) |

Harmful rewrites (moved further from the written text) were zero in every
household run, including households that also buy the three closest catalog
look-alikes of every written word (`Olivenbrot` next to `Olivenöl`). The
result is flat across a tenfold range of P(unknown word); the visual guard
trades accuracy for safety (1.0: zero harm, 69% at full re-add; 2.5: up to
91% with 1–2 harmful rewrites per run). Latency is unchanged (~4.5 s/photo on
the desktop host).

Six photos cannot certify a recognizer. They do show the lexicon is where
handwriting accuracy comes from for a household app, and that it can be made
safe. The remaining errors (`Papsol` for Rapsöl, `Aliverol` for Olivenöl)
are the recognizer's own and need the fine-tune below.

## Real photos (2026-10-31)

The six photos above were taken for this project, well framed. Fourteen
handwritten lists from Wikimedia Commons (`samples/commons/`,
`ocr_eval_commons_manifest.json`) are what the scanner meets in practice:
columns, letterheads and posters around the list, a list photographed at
18 degrees, 320-400 px thumbnails. Read cold they scored 21/130 active lines
exact (CER 57%), against 17/39 on the originals.

The losses were mostly geometry, fixed in the processor: small photos are
enlarged to 1600 px, slanted ones are rotated level (slant from the
detector's line-shaped blobs, re-detected past 2 degrees), and a row splits
into columns at gaps wider than 1.6 line heights. Lexicon readings must also
share half their spelling with the raw reading, which stopped smudges and
background print turning into short words ("baThexa" -> beer).

| Decoder | Commons, active exact | Originals, active exact |
|---|---:|---:|
| Before any of this | 21/130 | 17/39 |
| Geometry, guard, strike fix, no lexicon | 28/130 | 17/39 |
| + catalog cold start | 42/130 | 23/39 |
| + household, 50% re-add | 53-59/130 | 26-29/39 |
| + household, 80% re-add | 73-75/130 | 29-32/39 |
| + household, 100% re-add | 81/130 | 33/39 |

Zero harmful rewrites in any household run on either set, including
households that also buy the closest catalog look-alikes of every word.

Crossed-out detection used to fire on any middle row 42% dark, which a
thick pen on a short word clears ("Eis", "Käse"): 8 real items on the
Commons photos were struck and hidden. It now needs one unbroken stroke
across 60% of the crop: 1 wrong, with the same 5 of 10 strikes found (4 of 6
and none wrong on the originals).

What remains is the recognizer itself on hard hands and low resolution.
Print and smudges around the list (fewer than three letters, or under 0.45x
the list's typical line height) are set aside by the scan pipeline as
`MarkStatus.notList`, restorable in review; on these photos that catches
dates, times, page numbers and licence badges and loses only the two-letter
store header "DM".

## Decision

Keep the current PP-OCRv6 CTC recognizer and its bounded alternatives, read
against the household's vocabulary as above. Do not add a second
autoregressive recognizer, a larger detector, or unconditional dictionary
decoding.

The next model-quality gate is a domain fine-tune of a compact CTC recognizer
using real corrected grocery-line crops from multiple writers. The six images
remain a regression set; they must not become both training and evaluation
data. A first credible split needs at least 1,000 transcribed lines with a
writer-disjoint holdout. Synthetic augmentation can expand that corpus but
cannot replace the real holdout.

## Reproduction

Host-only dependencies belong in an isolated environment and are not Flutter
dependencies. Install `tool/requirements-ocr-benchmark.txt`, then see
`tool/benchmark_handwriting_recognizer.py` for TrOCR/ONNX HTR candidates and
`tool/benchmark_ppocr_ctc_lexicon.py` for the constrained CTC experiment. Raw
JSON results are written under ignored `build/` paths.
