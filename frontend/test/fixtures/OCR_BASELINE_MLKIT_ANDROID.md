# Legacy ML Kit Android baseline

Recorded 2026-07-18 on a Samsung Galaxy S24 Ultra (`SM-S928B`), Android 14
(API 34), using the bundled ML Kit Latin recognizer. All six original JPEGs
were processed locally on the phone. No network OCR service was used.

The production OpenCV preprocessing stage is excluded from this baseline. It
caused an uncatchable native `SIGABRT` on this device before OCR began
(`opencv_dart` 1.2.5, tagged-pointer/free failure while opening the bundled
arm64 library directory). The measurements below therefore isolate raw OCR.

## Aggregate

| Metric | Result |
|---|---:|
| Readable ground-truth lines | 45 |
| Crossed-out ground-truth lines | 6 |
| Illegible regions | 2 |
| Character error rate | 45.19% |
| Word error rate | 82.46% |
| Readable-line recall | 60.00% |
| Exact-line rate | 13.33% |
| Crossed-out detection recall | 0.00% |
| Unmatched predictions | 1 |
| Mean OCR latency | 126.22 ms |

## Per sample

| Sample | CER | WER | Line recall | Exact lines | OCR latency |
|---|---:|---:|---:|---:|---:|
| 001 | 76.00% | 100.00% | 0.00% | 0/7 | 269.24 ms |
| 002 | 40.22% | 78.57% | 70.00% | 0/10 | 106.92 ms |
| 003 | 52.94% | 100.00% | 42.86% | 0/7 | 99.89 ms |
| 004 | 12.90% | 60.00% | 100.00% | 4/9 | 86.58 ms |
| 005 | 35.53% | 75.00% | 70.00% | 2/10 | 131.08 ms |
| 006 | 60.00% | 100.00% | 50.00% | 0/2 | 63.64 ms |

## Recognized lines

- `001`: `fopso`; `lostnclttee`; `Kesanukheo`
- `002`: `- Some frueht`; `-`; `banonn`; `-es`; `- Cicbeff`;
  `- Prigles`; `milk x`; `- einta`; `- dip humny`; `- Colalee`
- `003`: `Rous`; `deneleu Balouico`; `lorbeorblGer`; `Bomll follenbe`
- `004`: `Milk`; `Onion`; `Cice`; `Oliue oi`; `eogs`; `aubugne`; `CUmin`;
  `Pepper`; `tomates`
- `005`: `- clicfen tigas`; `- Onion`; `- olive oil`; `tomateas`; `Comin`;
  `-avbrqne`; `Cocaa`
- `006`: `Oliuenol`

ML Kit returned confidence values between roughly 0.25 and 0.53 for these
lines. The current production confidence pipeline does not consume that OCR
confidence. Crossed-out entries were either omitted by recognition or returned
without a detectable mark; the text-only dash heuristic detected none of the
six real strikethroughs.
