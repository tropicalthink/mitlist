# Self-hosting mitlist

A self-hosted mitlist is the whole product: every feature, no member limit, no
billing, nothing phoning home. One server runs the web app, the API and
PostgreSQL. The iOS and Android apps connect to it too.

- [What you need](#what-you-need)
- [Install](#install)
- [HTTPS](#https)
- [Connect the mobile apps](#connect-the-mobile-apps)
- [Email](#email)
- [Attachments](#attachments)
- [Optional extras](#optional-extras)
- [Back up and restore](#back-up-and-restore)
- [Upgrade](#upgrade)
- [Troubleshooting](#troubleshooting)

## What you need

- A Linux machine with Docker Engine and the Docker Compose v2 plugin
  (`docker compose version` should print v2.x), plus `git` and `openssl`.
- About 2 GB of RAM for the first build (the web app is compiled from source
  on the server), then a few hundred MB to run. Several GB of free disk for the
  build images.
- HTTPS for the phone apps: a domain pointing at the server, or a tunnel such
  as Tailscale (see [HTTPS](#https)). A browser on your LAN can use plain
  `http://<server-ip>`.

## Install

```bash
git clone https://github.com/tropicalthink/mitlist.git
cd mitlist
./scripts/selfhost-setup.sh
docker compose up -d --build
```

The setup script asks for the URL people will open, and how HTTPS is handled
when that URL is `https://`. It writes `.env` with:

- `MITLIST_URL`: the one public address. The web app is served there and the
  API answers under `/api` on the same address, so there is no separate API
  domain to set up.
- A random database password, `SECRET_KEY`, `SESSION_SECRET_KEY` and a web
  push key pair.
- `COMPOSE_PROFILES`, so a plain `docker compose up` starts the right services.

It never overwrites a value that is already set, so you can run it again at any
time. Everything else in `.env` is optional; every variable is described in
[backend/.env.example](../backend/.env.example) and can go in the same `.env`.

The first `up` builds both images, which takes 10–20 minutes. When
`docker compose ps` shows the backend as healthy, open your URL and create
an account. The first person to sign up creates a household and invites the
rest from it.

Migrations run automatically on every start. `docker compose logs backend`
prints an `integration status` line on startup listing what is on and off.

## HTTPS

The iOS and Android apps only connect to `https://` servers, and browsers only
install the web app and allow notifications over HTTPS. Plain `http://` is
fine for trying mitlist in a browser on your LAN, but a household that uses the
phone apps needs HTTPS. Pick one:

**The bundled Caddy** (setup script option 1). Caddy gets and renews a Let's
Encrypt certificate for your domain. The domain's DNS must point at the server,
and ports 80 and 443 must be free and reachable from the internet.
`COMPOSE_PROFILES=prod,https` in `.env` turns it on.

**Your own reverse proxy** (option 2). The web container listens on
`127.0.0.1:8080` (`MITLIST_BIND`, `MITLIST_PORT`). Proxy your domain to it. One
host, one upstream, nothing path-specific. It must pass `X-Forwarded-For` and
`X-Forwarded-Proto` (every common proxy does by default) and must not buffer
responses for `/api/v1/events`, which holds the live-update stream open. Caddy
example:

```caddyfile
mitlist.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

nginx example:

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering off;
    proxy_read_timeout 1h;
    client_max_body_size 32m;
}
```

If your proxy runs on another machine, or in Docker on a network outside the
private ranges, add its address to `TRUSTED_PROXIES` in `.env` so rate limits
see the real client address.

**No public ports.** A tunnel gives you HTTPS without opening the firewall:
`tailscale serve --bg 8080` on the server serves it at
`https://<machine>.<tailnet>.ts.net` to every device on your tailnet, and a
Cloudflare Tunnel does the same on your own domain. Use that HTTPS address as
`MITLIST_URL` and choose option 2 in the setup script.

**Browser on a LAN only.** Use `http://<server-ip>:8080` as the URL. The setup
script then binds the web container to all interfaces. The web app works except
for installing it and browser notifications. The phone apps won't connect.

## Connect the mobile apps

On the sign-in screen, tap **Choose your server** and enter your `MITLIST_URL`.
The app checks the server and remembers it. Everyone in the household does the
same once.

What differs from the hosted service:

- **Mobile push notifications need the official push credentials.** A store
  build of the app can only receive pushes sent through the official Firebase
  project, so a self-hosted server can't reach it. The in-app notification
  inbox, live updates while the app is open, and email all still work. Browser
  push (the web app) works fully, using the VAPID keys the setup script
  generated. Home screen widgets don't get instant push refreshes either.
- **Sign in with Google/Apple** needs your own developer credentials (see the
  OAuth section of `backend/.env.example`). Email and password sign-in is on by
  default and needs nothing.

To also receive mobile pushes, build the app yourself against your own
Firebase project. See [build-configuration.md](build-configuration.md) and set
`FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` on the server.

## Email

mitlist sends verification codes, password resets, invitations and reminders by
email. Without email:

- New accounts are let in straight away, without a verification code.
- "Forgot password" is unavailable. An admin can reset a password from the
  database (see [Troubleshooting](#troubleshooting)).

Any SMTP server works: your mail provider, a transactional service, or a relay
on your network. Add to `.env`:

```dotenv
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=mitlist@example.com
SMTP_PASSWORD=...
SMTP_TLS=starttls          # starttls (587), tls (465), none (local relay only)
MAIL_FROM_EMAIL=mitlist@example.com
MAIL_FROM_NAME=mitlist
```

`MAIL_FROM_EMAIL` must be an address your SMTP server is allowed to send as.
Restart with `docker compose up -d`. Once email works, new accounts verify their
address again.

## Attachments

Receipts, photos and pinwall media are stored in the `uploads` Docker volume.
Uploads and downloads go through your own URL with short-lived signed links.
`MAX_STORAGE_PER_GROUP_GB=0` (the self-host default) means no quota.

To use S3-compatible storage instead (AWS S3, Cloudflare R2, Backblaze B2,
Garage, ...), set `S3_BUCKET_NAME`, `S3_ENDPOINT_URL`, `AWS_REGION`,
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The endpoint must be reachable
from the phones and browsers that use mitlist, because they upload to it
directly. Files already on local disk are not moved over automatically.

## Optional extras

| What | How |
| --- | --- |
| Recipe import from sites that block bots | Add `scraper` to `COMPOSE_PROFILES` and set `SCRAPER_FLARESOLVER_URL=http://flaresolverr:8191`. Runs a headless Chromium (~500 MB RAM). |
| Live currency rates | `FX_RATE_API_URL` (see backend/.env.example). Without it, people enter exchange rates by hand. |
| Error reports to your own GlitchTip/Sentry | `SENTRY_DSN`. Off unless set. |
| Guest accounts ("continue without signing up") | `GUEST_AUTH_ENABLED=true`. Off by default, since anyone who can reach the server can then create accounts. |
| An external PostgreSQL | `DATABASE_URL` (and `DB_SSLMODE=require` across a network). The bundled `db` service still starts but is unused. |

Billing, in-app purchases and App Check stay off unless you configure them,
and households have no member limit.

## Back up and restore

Two things hold your data: the PostgreSQL database and the `uploads` volume.
`.env` holds the keys; keep a copy somewhere safe, because losing `SECRET_KEY`
and `SESSION_SECRET_KEY` signs everyone out.

Back up (safe while running):

```bash
mkdir -p backups
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB"' > backups/mitlist-$(date +%F).dump
docker compose exec -T backend tar -C /app/data/uploads -czf - . > backups/uploads-$(date +%F).tgz
```

Run that from cron and copy `backups/` off the machine.

Restore into a fresh install (same `.env`):

```bash
docker compose up -d db
docker compose exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' < backups/mitlist-YYYY-MM-DD.dump
docker compose up -d
docker compose exec -T backend tar -C /app/data/uploads -xzf - < backups/uploads-YYYY-MM-DD.tgz
```

## Upgrade

```bash
git pull
docker compose up -d --build
```

Database migrations apply on start. Read [CHANGELOG.md](../CHANGELOG.md) first
for anything marked as needing a config change, and take a backup before
upgrading across several versions. Do not run migrations backwards to downgrade:
restore the backup instead.

To check a running install from any machine with Go:

```bash
cd backend && go run ./cmd/smoke -base-url https://mitlist.example.com
```

## Troubleshooting

**`docker compose up` only starts the database.** `COMPOSE_PROFILES` is missing
from `.env`. Run `./scripts/selfhost-setup.sh` again, or add
`COMPOSE_PROFILES=prod`.

**The backend keeps restarting.** `docker compose logs backend` names the
problem. The usual ones: `FRONTEND_URL must be an absolute http(s) origin`
means `MITLIST_URL` is empty or not a URL. `SECRET_KEY must be at least 32
characters` means the key is missing.

**`port is already allocated` for 5432.** The host already runs PostgreSQL. Set
`POSTGRES_HOST_PORT=5433` (any free port) in `.env`.

**Database authentication fails after changing `POSTGRES_PASSWORD`.** PostgreSQL
keeps the password it was first created with. Change it inside the database to
match `.env`:
`docker compose exec db psql -U mitlist -c "ALTER USER mitlist PASSWORD 'new-password'"`.

**The mobile app rejects the URL or can't reach the server.** The app only
accepts `https://` addresses. Open `<MITLIST_URL>/healthz` in the phone's
browser: it should print `ok` without a certificate warning (a self-signed
certificate is rejected too).

**Live updates lag or arrive in bursts.** A proxy in front is buffering
`/api/v1/events`. Turn response buffering off for it (see [HTTPS](#https)).

**Reset someone's password without email.** Set it directly in the database
(the address is stored lowercase):

```bash
docker compose exec db psql -U mitlist -d mitlist -c \
  "CREATE EXTENSION IF NOT EXISTS pgcrypto;
   UPDATE users SET password_hash = crypt('a new password', gen_salt('bf', 12))
   WHERE email = 'person@example.com';"
```

Configure [email](#email) to make "Forgot password" work instead.
