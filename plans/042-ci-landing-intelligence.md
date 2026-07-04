# Plan 042: CI builds the landing site and smoke-checks the intelligence pipeline

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- .gitea/workflows/ci.yml landing/package.json intelligence`
> On any change, re-read `ci.yml` and `landing/package.json` first.

## Status

- **Priority**: P3
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

CI has only `backend` and `frontend` jobs. The `landing/` Astro site is never
built in CI, and the `intelligence/` Python pipeline (which produces the app's
grocery seed and classifier) is only invoked as two specific scripts —
`check_classifier_parity.py` and `resolution_eval.py` — with no import/smoke check
of the rest. A broken landing build or a Python syntax/import error elsewhere in
the pipeline ships undetected. Cheap CI jobs close that gap.

## Current state

```yaml
# .gitea/workflows/ci.yml — only two jobs: backend, frontend.
# frontend job already runs:
#   python3 intelligence/ml/check_classifier_parity.py
#   python3 ../intelligence/ml/eval/resolution_eval.py   (after a flutter test export)
# Nothing builds landing/ (grep 'landing'/'astro' in workflows → none).
```
`landing/` is an Astro project (`landing/package.json`, `astro build`). Confirm
the build script name with `cat landing/package.json` (look for
`scripts.build`). `intelligence/` has no tracked `test_*.py`; confirm with
`ls intelligence/**/test_*.py 2>/dev/null`.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Landing build | `cd landing && npm ci && npm run build` | exit 0 |
| Python import smoke | `cd intelligence && python3 -c "import ..."` (per Step 2) | exit 0 |
| YAML valid | `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"` | exit 0 |

## Scope

**In scope**:
- `.gitea/workflows/ci.yml`
- Possibly a tiny `intelligence/` smoke script if a clean import target isn't
  obvious (create `intelligence/smoke_test.py` only if needed — see Step 2)

**Out of scope**:
- Writing real pytest coverage for the pipeline — that's a larger follow-up; this
  plan adds a build/import smoke gate, not a test suite.
- Changing `landing/` or `intelligence/` source.

## Git workflow

- Branch: `advisor/042-ci-landing-intelligence`
- Conventional commit: `ci: build landing and smoke-check intelligence pipeline`.

## Steps

### Step 1: Add a `landing` job

Add a job that checks out, sets up Node, and runs the landing build:

```yaml
  landing:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install
        run: cd landing && npm ci
      - name: Build
        run: cd landing && npm run build
```
Confirm the build script exists (`npm run build` maps to `astro build`); if the
script has a different name, use it.

**Verify**: locally `cd landing && npm ci && npm run build` → exit 0 (if network/
deps allow; if the environment can't install, at least confirm the script name and
that the YAML is valid).

### Step 2: Add an `intelligence` smoke job

Add a job that installs the pipeline's Python deps (find them:
`ls intelligence/requirements*.txt intelligence/pyproject.toml 2>/dev/null`) and
imports the key modules so a syntax/import error fails CI. Prefer importing the
real modules over a bespoke script:

```yaml
  intelligence:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install
        run: pip install -r intelligence/requirements.txt   # adjust to real file
      - name: Import smoke
        run: |
          cd intelligence
          python3 -c "import ml.build_app_seed, ml.build_store_aisles, ml.check_classifier_parity"
```
Adjust the import list to the real module paths (`ls intelligence/ml/*.py`). If
imports require heavy optional deps, import only the lightweight builders/checkers.
Create a minimal `intelligence/smoke_test.py` only if a one-liner import is
impractical.

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"`
→ exit 0; and locally the import line runs (or, if deps aren't installable here,
confirm the module paths exist with `ls`).

### Step 3: Validate the workflow

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"`
→ exit 0.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -n "landing:" .gitea/workflows/ci.yml` → a landing job exists
- [ ] `grep -n "intelligence:" .gitea/workflows/ci.yml` → an intelligence job exists
- [ ] The intelligence job imports real pipeline modules (the paths exist: `ls intelligence/ml/build_app_seed.py` etc.)
- [ ] `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"` exits 0
- [ ] Report states whether `npm run build` / the import smoke actually ran locally or only the paths were verified
- [ ] No files outside `.gitea/workflows/ci.yml` (and an optional smoke script) modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- `landing/` has no build script or its deps can't be resolved — report what
  `package.json` contains.
- The intelligence modules import heavy ML deps that make a CI import job slow or
  fragile — report; import only the lightweight modules, or scope this to landing
  only and note it.

## Maintenance notes

- Follow-up: grow real pytest coverage over the pipeline's parsers/seed builders.
- Reviewer: confirm the import list matches real module paths and the landing
  build script name is correct.
