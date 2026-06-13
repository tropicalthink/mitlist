# Plan 008: Fix self-host setup docs and secret-generation guidance

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 9e8d63f1..HEAD -- README.md backend/.env.example docker-compose.yml`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW (docs/comments only)
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `9e8d63f1`, 2026-06-10

## Why this matters

The README sells a "5-minute self-host". The main quick-start section is correct (`docker compose --profile prod up -d`), but the download table tells self-hosters to run `docker compose up -d` — which, because the `backend` and `frontend` services are gated behind the `prod` profile, starts **only Postgres and Redis**. Separately, `backend/.env.example` requires two ≥32-char secrets and a `DATABASE_URL` but offers no values or generation commands, so first-time self-hosters either stall or paste weak secrets. Both are cheap fixes to a first-impression path.

## Current state

`docker-compose.yml` profiles (root file): `api` → `profiles: [dev]` (line 14); `backend` → `profiles: [prod]` (line 53); `frontend` → `profiles: [prod]` (line 79); `db` (line 88) and `redis` (line 106) have no profile (always start).

`README.md:134` (Download section table):

```
| Self-host | `docker compose up -d` |
```

`README.md:148–154` (Contributing/dev section):

```
# Backend
cd backend
docker compose up -d    # postgres + redis
cp .env.example .env
go run ./cmd/migrate up
go run ./cmd/api
```

There is **no** `backend/docker-compose.yml`; that command works only because docker compose walks up to the root file, where the profile-less `db` + `redis` start — so the comment is accidentally correct but fragile/confusing. The canonical quick-start at `README.md:79–82` is already right:

```
cd mitlist
cp backend/.env.example backend/.env  # edit with your settings
docker compose --profile prod up -d
```

`backend/.env.example:1–16`:

```
# PostgreSQL connection string
DATABASE_URL=

# JWT signing secret (min 32 characters)
SECRET_KEY=

# Session/cookie signing secret (min 32 characters)
SESSION_SECRET_KEY=
```

No generation guidance, no example `DATABASE_URL`. Check `docker-compose.yml`'s `db` service (lines 88+) for the postgres user/password/db it provisions so the example `DATABASE_URL` you write matches it.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Confirm profile behavior | `docker compose config --profile prod --services` (repo root) | lists backend, frontend, db, redis |
| Confirm default behavior | `docker compose config --services` | lists only db, redis (and any other profile-less services) |

(If docker isn't available, reasoning from the compose file suffices — these are doc edits.)

## Scope

**In scope**:
- `README.md` (lines ~134 and ~148–154 only)
- `backend/.env.example` (comments and example values only — no new variables)

**Out of scope**:
- `docker-compose.yml` itself — do not re-profile services; the prod/dev split is intentional.
- `backend/README.md` and `intelligence/.env.example` — unless README edits create a direct contradiction with backend/README.md; if so, report it, don't fix it.
- Any actual secret values — examples must be generation *commands*, never literal secrets.

## Git workflow

- Branch: `docs/selfhost-setup` off `new-main-fr`.
- One commit, conventional style (`docs: fix self-host compose command and secret generation guidance`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix the download-table command

Change `README.md:134` to:

```
| Self-host | `docker compose --profile prod up -d` |
```

### Step 2: Clarify the dev snippet

In `README.md:148–154`, replace the misleading `cd backend` + `docker compose up -d` pair with the explicit root-level form:

```bash
# Backend
docker compose up -d    # postgres + redis only (no profile)
cd backend
cp .env.example .env    # see comments inside for secret generation
go run ./cmd/migrate up
go run ./cmd/api
```

### Step 3: Add generation guidance to .env.example

In `backend/.env.example`, extend the comments (values stay empty):

```
# PostgreSQL connection string.
# For the bundled docker compose db service use:
#   postgres://<user>:<password>@localhost:5432/<db>?sslmode=disable
# (substitute the credentials from docker-compose.yml's `db` service)
DATABASE_URL=

# JWT signing secret (min 32 characters). Generate with:
#   openssl rand -base64 32
SECRET_KEY=

# Session/cookie signing secret (min 32 characters). Must differ from
# SECRET_KEY. Generate with:
#   openssl rand -base64 32
SESSION_SECRET_KEY=
```

Use the *actual* credentials from the compose `db` service in the `DATABASE_URL` comment (read `docker-compose.yml` lines 88–105 first) — those are local-dev defaults, not secrets.

**Verify (all steps)**: `git diff` touches only the two files, only the described regions; `grep -n "docker compose up -d" README.md` matches only the dev snippet (line ~150), not the self-host table.

## Test plan

Docs only. If docker is available: `docker compose config --profile prod --services` and `docker compose config --services` to confirm the claims you're writing.

## Done criteria

- [ ] `README.md:134` (or its drifted equivalent) uses `--profile prod`
- [ ] `backend/.env.example` contains `openssl rand -base64 32` guidance for both secrets and a concrete localhost `DATABASE_URL` template
- [ ] No literal secret values added anywhere
- [ ] Only `README.md` and `backend/.env.example` modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The compose profiles have changed (e.g. `backend` no longer behind `prod`) — the doc fix would then be wrong.
- `backend/README.md` documents a conflicting setup flow that these edits would contradict.

## Maintenance notes

- If the compose profiles are ever restructured, both README sections and the `.env.example` `DATABASE_URL` comment must move with them.
- Consider (deferred): a `scripts/setup.sh` that copies `.env.example`, generates both secrets, and prints next steps — would make the "5 minutes" claim robust.
