# Releasing Mitlist

This document describes how to cut a versioned release of Mitlist. Follow each
step in order; do not skip CI or the smoke-test.

## Prerequisites

- You have write access to the `new-main-fr` branch and tag namespace.
- The deploy pipeline is `.gitea/workflows/deploy-prod.yml` (triggered by
  merging a PR into `prod`).

---

## Release steps

### 1. Confirm CI is green

All merges to `new-main-fr` must pass `.gitea/workflows/ci.yml`, which runs:

```
cd backend && go build ./...
cd backend && go vet ./...
cd backend && go test ./...
cd frontend && flutter test
```

Do not proceed if any job is red.

### 2. Bump the version and update CHANGELOG

1. Edit `frontend/pubspec.yaml` — increment `version: X.Y.Z+N` following
   [Semantic Versioning](https://semver.org/):
   - **Patch** (`Z`): bug-fixes only, no new features.
   - **Minor** (`Y`): new backwards-compatible features.
   - **Major** (`X`): breaking changes (API incompatibility, DB migrations that
     cannot be rolled back, removed features).
   - Increment the build number (`+N`) for every release regardless.

2. In `CHANGELOG.md`:
   - Rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` with today's date.
   - Add a new empty `## [Unreleased]` section above it.

3. Commit both files:
   ```
   git add frontend/pubspec.yaml CHANGELOG.md
   git commit -m "chore(release): bump to vX.Y.Z"
   ```

### 3. Tag the release

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

Tags are lightweight version markers — they do **not** trigger a deploy on
their own (see Step 5).

### 4. Create a Gitea Release

1. Navigate to **Releases → New Release** for the tag `vX.Y.Z`.
2. Set the title to `vX.Y.Z`.
3. Paste the CHANGELOG section for this version as the release notes (see the
   template at the bottom of this file).
4. Publish the release.

### 5. Deploy to production

Open a PR from `new-main-fr` (or a release branch) into `prod` and merge it.
This triggers `.gitea/workflows/deploy-prod.yml`, which:

- Builds the Flutter web frontend and the Go backend.
- Pushes images tagged `latest` **and** `$(date +%Y-%m-%d)-<sha7>` to the
  internal container registry (e.g. `git.vinylnostalgia.com/…`).

> **Note:** images are currently tagged `date-sha`, not the semver. If you want
> version-traceable image tags, optionally retag the pushed images after the
> workflow completes:
> ```
> docker pull git.vinylnostalgia.com/<actor>/<repo>-backend:latest
> docker tag  git.vinylnostalgia.com/<actor>/<repo>-backend:latest \
>             git.vinylnostalgia.com/<actor>/<repo>-backend:vX.Y.Z
> docker push git.vinylnostalgia.com/<actor>/<repo>-backend:vX.Y.Z
> # repeat for -frontend
> ```

### 6. Post-deploy smoke test

Hit the two health endpoints on the running backend (substitute your domain):

```bash
curl -sf https://<your-domain>/healthz && echo "healthz OK"
curl -sf https://<your-domain>/readyz  && echo "readyz  OK"
```

Both are defined in `backend/cmd/api/main.go`. A non-200 or curl failure means
the deployment is broken — roll back by reverting the `prod` merge and
re-deploying.

---

## Release notes template

```markdown
## vX.Y.Z — YYYY-MM-DD

### What's new
-

### Fixed
-

### Upgrade notes
<!-- anything the operator needs to do: env vars, DB migrations, etc. -->
```

---

## Hotfix process

For urgent fixes against an already-released tag:

1. Branch off the tag: `git checkout -b hotfix/vX.Y.Z+1 vX.Y.Z`.
2. Apply the fix and write a test.
3. Follow Steps 2–6 above with a patch-version bump.
4. Cherry-pick or merge the fix back into `new-main-fr`.
