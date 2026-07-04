# Plan 024: Upload size/quota is enforced against the real object, not a client claim

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/services/attachment_service.go backend/internal/services/storage/storage.go`
> On any change, compare the excerpts below to live code first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

Attachment uploads enforce both the max-file-size and the per-group storage cap
against `in.ByteSize` — a number supplied in the client's request body — but that
number is never checked against what actually gets stored. The presigned PUT has
no content-length limit, and `FinalizeUpload` flips the row to `Ready` without
inspecting the real object size. A member can declare `byte_size: 1`, pass both
limits, then upload an arbitrarily large object: storage exhaustion /
denial-of-wallet. Reconciling the declared size with the real object closes the
bypass.

## Current state

```go
// attachment_service.go:91-118  (CreateUploadIntent — validates the CLAIM)
if in.ByteSize <= 0 { return ... "byte_size must be positive" }
if s.cfg.MaxFileSizeBytes > 0 && in.ByteSize > int64(s.cfg.MaxFileSizeBytes) {
	return ... "file too large"
}
...
if s.cfg.MaxStoragePerGroupGB > 0 {
	used, err := s.repo.SumReadyBytesByGroup(ctx, in.GroupID)
	...
	if used+in.ByteSize > limit { return ... "group storage limit exceeded" }
}
```

```go
// attachment_service.go:157-190  (FinalizeUpload — trusts the claim)
a, err := s.repo.GetByID(ctx, attachmentID)
...
if a.GroupID != groupID { return ... permission denied }
if err := s.repo.UpdateStatus(ctx, attachmentID, models.AttachmentStatusReady); err != nil { ... }
a.Status = models.AttachmentStatusReady
return a, nil     // ← never verifies real object size
```

The presign helper is `s.storage.GetUploadURL(objectKey, contentType, expires)`
at `attachment_service.go:144`, implemented in
`backend/internal/services/storage/storage.go` (`GetUploadURL`, ~line 100). It
presigns a PUT with bucket/key/content-type and **no** content-length-range
condition. Read that method before Step 1.

## Commands you will need

| Purpose | Command                                                   | Expected |
|---------|-----------------------------------------------------------|----------|
| Build   | `cd backend && go build ./...`                            | exit 0   |
| Vet     | `cd backend && go vet ./...`                              | exit 0   |
| Tests   | `cd backend && go test ./internal/services/`              | all pass |

## Scope

**In scope**:
- `backend/internal/services/attachment_service.go`
- `backend/internal/services/storage/storage.go`
- `backend/internal/services/attachment_service_test.go` (extend; create if absent)

**Out of scope**:
- The attachment repository schema — no new columns needed (the real size can be
  written into the existing `ByteSize` field on finalize).
- Client upload code (frontend) — the contract (declare size, PUT, finalize) is
  unchanged from the client's view.

## Git workflow

- Branch: `advisor/024-upload-size-verification`
- Conventional commit: `fix(attachments): verify real object size on finalize; bound presigned upload`.

## Steps

### Step 1: Add a HEAD/stat method to the storage service

In `storage/storage.go`, add a method that returns the stored object's size for a
given key — e.g. `func (s *Service) HeadObjectSize(ctx, key string) (int64, error)`.
Implement it with the same S3/R2 client `GetUploadURL` uses (look for the
existing client field on `Service`). If the SDK is `aws-sdk-go-v2`, that is
`HeadObject`; return `*out.ContentLength`.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 2: Reconcile size in FinalizeUpload

In `FinalizeUpload`, after ownership check and before marking `Ready`:
- Call `HeadObjectSize` for `a.ObjectKey`.
- If the real size exceeds `MaxFileSizeBytes` (when configured), reject with a
  `*api.ValidationError{Message: "uploaded file exceeds size limit"}` and do NOT
  mark Ready (optionally delete the orphaned object — see Step 4).
- Re-check the group cap using the real size:
  `used, _ := SumReadyBytesByGroup(...); if used + realSize > limit { reject }`.
- Persist the real size into the attachment row (update `ByteSize`) so
  `SumReadyBytesByGroup` (which sums Ready rows) counts the true bytes, then mark
  `Ready`. Add a repo method or reuse an existing update if one sets ByteSize.

**Verify**: `cd backend && go build ./... && go vet ./...` → exit 0.

### Step 3 (defense in depth): bound the presigned PUT

If the storage SDK/presign path supports it, add a content-length-range condition
to `GetUploadURL` (or switch to a presigned POST policy with `content-length-range`)
capped at `MaxFileSizeBytes`. If the current SDK/presign method cannot express
this without a larger change, SKIP this step and rely on Step 2 (record the skip
in your report) — Step 2 is the load-bearing fix.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 4: Tests

Extend `attachment_service_test.go` (or create it, modeling on an existing
`backend/internal/services/*_test.go` that mocks a repo). Because HEAD hits
storage, inject a fake storage sizer (add a small interface for the size lookup
so the test can stub it — keep the interface minimal). Cover:
- Declared size within limits, real size within limits → finalize succeeds,
  stored ByteSize equals real size.
- Declared `byte_size: 1`, real size over `MaxFileSizeBytes` → finalize rejected,
  status not Ready.
- Real size pushes group over cap → rejected.

**Verify**: `cd backend && go test ./internal/services/ -run Attachment -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `grep -n "HeadObject\|HeadObjectSize" backend/internal/services/storage/storage.go` → present
- [ ] `grep -n "HeadObjectSize\|real size\|ContentLength" backend/internal/services/attachment_service.go` → the finalize path calls it
- [ ] New/extended attachment tests pass; the `byte_size:1` bypass case fails finalize
- [ ] `cd backend && go test ./internal/services/` all pass
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- The storage `Service` exposes no usable client for HEAD (e.g. it is a thin
  presign-only wrapper) — report what it exposes; do not add a whole new S3
  client dependency without confirming.
- Marking Ready and updating ByteSize are entangled in a way that needs a schema
  change — report before migrating.

## Maintenance notes

- The window between presign and finalize still allows a large object to exist
  transiently; Step 2 prevents it from ever counting or serving. A background
  reaper for never-finalized objects is a separate follow-up.
- Reviewer: confirm the group-cap re-check uses the REAL size, and that a
  rejected finalize cannot leave a Ready row.
