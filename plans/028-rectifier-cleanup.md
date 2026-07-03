# Plan 028: The document rectifier stops double-decoding and leaking OpenCV handles

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/services/scan/document_rectifier_cv_native.dart`
> On any change, compare the excerpt below to live code first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`rectifyDocumentCv` runs on the scanner capture hot path. It has two native-memory
inefficiencies: (1) it decodes the full-resolution JPEG **twice** — once as `src`
(used for dimensions) and again as `srcFull` for the warp — doubling peak decode
CPU and memory per frame; and (2) inside `_findDocumentQuad`, each `contours[i]`
and `approxPolyDP` result is a native-backed OpenCV handle that is never disposed,
leaking one-plus per detected contour on every scan. `opencv_dart` does not
reliably auto-finalize these handles (the sibling file
`capture_preprocessor_cv_native.dart` disposes every intermediate `Mat`
meticulously, confirming the convention). Fixing both tightens the capture path's
memory profile.

## Current state

```dart
// frontend/lib/services/scan/document_rectifier_cv_native.dart:11-64
Uint8List? rectifyDocumentCv(Uint8List jpegBytes) {
  final scratch = <cv.Mat>[];
  void track(cv.Mat m) => scratch.add(m);
  cv.Contours? contours;
  try {
    final src = cv.imdecode(jpegBytes, cv.IMREAD_COLOR); track(src);   // decode #1 (full res)
    if (src.isEmpty) return null;
    final h = src.rows;
    final w = src.cols;
    ...
    final small = cv.resize(src, (wSmall, hSmall)); track(small);
    ...
    final quad = _findDocumentQuad(contours, wSmall, hSmall);
    if (quad == null) return null;

    // Step 4 – Warp the ORIGINAL-resolution image using the scaled quad.
    final srcFull = cv.imdecode(jpegBytes, cv.IMREAD_COLOR);            // decode #2 (redundant)
    try {
      return _warpToRect(srcFull, quad, scale, w, h);
    } finally {
      srcFull.dispose();
    }
  } finally {
    contours?.dispose();
    for (final m in scratch) {
      try { m.dispose(); } catch (_) {}
    }
  }
}
```

```dart
// document_rectifier_cv_native.dart:77-96  (inside _findDocumentQuad)
for (var i = 0; i < contours.length; i++) {
  final contour = contours[i];                       // ← native handle, never disposed
  final area = cv.contourArea(contour);
  if (area < bestArea) continue;
  final perimeter = cv.arcLength(contour, true);
  final approx = cv.approxPolyDP(contour, 0.02 * perimeter, true);   // ← native handle, never disposed
  if (approx.length == 4) { ... }
}
```
`src` at decode #1 is already the full-resolution image (`imdecode` with no
resize); `small` is the resized copy. So `srcFull` recreates exactly what `src`
already holds. `_warpToRect(src, ...)` disposes only its own locals (`warped`,
`M`, `srcPts`, `dstPts`) in its `finally` — it does NOT dispose the passed-in
image — so `src` remains owned by the outer `scratch` loop. That means reusing
`src` is safe.

## Commands you will need

| Purpose | Command                                                    | Expected |
|---------|------------------------------------------------------------|----------|
| Analyze | `cd frontend && dart analyze lib/`                         | `No issues found!` |
| Test    | `cd frontend && flutter test test/services/`               | pass (or the sqlite-env note in the header applies) |

Note: this file imports `opencv_dart`, which is a native plugin. Pure Dart unit
tests cannot execute `rectifyDocumentCv` without the native lib. Verification is
therefore **static** (analyze + code review of dispose coverage), plus not
breaking the existing scan tests. Do not attempt to add a test that runs OpenCV.

## Scope

**In scope**:
- `frontend/lib/services/scan/document_rectifier_cv_native.dart`

**Out of scope**:
- `capture_preprocessor_cv_native.dart` and other capture files — reference them
  for the dispose pattern, but do not modify.
- The web stub (`document_rectifier_cv_stub.dart` or similar) — it returns null.

## Git workflow

- Branch: `advisor/028-rectifier-cleanup`
- Conventional commit: `fix(scan): reuse decode and dispose contour handles in rectifier`.

## Steps

### Step 1: Reuse the first decode for the warp

Delete the second `cv.imdecode(jpegBytes, ...)` (decode #2) and its inner
`try/finally`. Call `_warpToRect(src, quad, scale, w, h)` using the already-
decoded `src`. Because `src` is tracked in `scratch` and disposed in the outer
`finally`, and `_warpToRect` does not dispose its input, the disposal remains
correct and single.

**Verify**: `grep -c "cv.imdecode(jpegBytes" frontend/lib/services/scan/document_rectifier_cv_native.dart`
→ `1` (only one decode remains).

### Step 2: Dispose contour handles in `_findDocumentQuad`

Inside the loop, dispose `contour` and `approx` when they are no longer needed.
Follow the `scratch`/`track` pattern used at the top of the file, or dispose at
the end of each iteration. Care: `approx[j]` points are copied into `Point2f`
values at `:87-90` before use, so `approx` can be disposed after that copy; the
chosen `best` result is a list of `Point2f` values (not native handles), so
disposing the source `contour`/`approx` does not invalidate `best`. Verify by
reading `_orderQuad` (`:102-111`) — it operates on `Point2f` value objects.

Concretely, guard each with try/dispose so an early `continue` still frees:
give each iteration a local `try { ... } finally { contour.dispose(); approx?.dispose(); }`
or accumulate into the `scratch` list and free in the outer `finally`.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 3: Confirm no double-dispose

Re-read the final `finally` blocks: `src` is disposed once (outer `scratch`),
`contours` once, each per-iteration handle once, and `_warpToRect`'s locals once.
No handle is disposed twice.

**Verify**: `cd frontend && flutter test test/services/` → the existing scan tests
still pass (no regression).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `grep -c "cv.imdecode(jpegBytes" frontend/lib/services/scan/document_rectifier_cv_native.dart` → `1`
- [ ] `grep -n "contour.dispose\|approx.dispose\|approx?.dispose" frontend/lib/services/scan/document_rectifier_cv_native.dart` → present (contour handles freed)
- [ ] `cd frontend && flutter test test/services/` passes (no scan-test regression)
- [ ] No files outside the in-scope file modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- `_warpToRect` turns out to dispose its input `src` internally (re-read `:163-168`)
  — then reusing `src` would double-free; report before proceeding.
- The excerpt no longer matches live code (drift).

## Maintenance notes

- If `opencv_dart` is upgraded to a version with reliable finalizers, this manual
  disposal becomes redundant but harmless.
- Reviewer: trace every native handle to exactly one `dispose()` on every path
  (early return, no-quad, exception).
