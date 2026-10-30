#!/usr/bin/env sh
# Prepare a self-hosted mitlist: writes the root .env with the public URL,
# strong database and signing secrets and a web push key pair, then tells you
# the one command that starts it. Safe to re-run: it never replaces a value
# that is already set, so it cannot rotate a key out from under a running
# install.
#
#   ./scripts/selfhost-setup.sh                      # asks two questions
#   MITLIST_URL=https://mitlist.example.com HTTPS=caddy ./scripts/selfhost-setup.sh
#
# Non-interactive variables: MITLIST_URL, HTTPS=caddy|proxy (https URLs only).
# Full guide: docs/SELF_HOSTING.md
set -eu

cd "$(dirname "$0")/.."
ENV_FILE=.env

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

command -v openssl >/dev/null 2>&1 || die "openssl is required to generate keys (apt install openssl / apk add openssl)"
command -v docker >/dev/null 2>&1 || die "docker is required: https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || die "the docker compose plugin (v2) is required: https://docs.docker.com/compose/install/"

# get KEY → current value in .env ('' when absent or empty)
get() {
  sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1
}

# set KEY VALUE → replace an existing (possibly commented-out) line, else append
set_var() {
  if grep -q "^$1=" "$ENV_FILE"; then
    tmp="$ENV_FILE.tmp.$$"
    awk -v k="$1" -v v="$2" 'BEGIN { done = 0 }
      index($0, k "=") == 1 && !done { print k "=" v; done = 1; next }
      { print }' "$ENV_FILE" >"$tmp" && mv "$tmp" "$ENV_FILE"
  elif grep -q "^#$1=" "$ENV_FILE"; then
    tmp="$ENV_FILE.tmp.$$"
    awk -v k="$1" -v v="$2" 'BEGIN { done = 0 }
      index($0, "#" k "=") == 1 && !done { print k "=" v; done = 1; next }
      { print }' "$ENV_FILE" >"$tmp" && mv "$tmp" "$ENV_FILE"
  else
    printf '%s=%s\n' "$1" "$2" >>"$ENV_FILE"
  fi
}

# set_if_empty KEY VALUE → only fills a missing value
set_if_empty() {
  if [ -z "$(get "$1")" ]; then
    set_var "$1" "$2"
    return 0
  fi
  return 1
}

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

if [ ! -f "$ENV_FILE" ]; then
  cp .env.example "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  say "Created $ENV_FILE from .env.example."
fi

# --- Public URL -------------------------------------------------------------
url=${MITLIST_URL:-$(get MITLIST_URL)}
if [ -z "$url" ]; then
  say ""
  say "What URL will people open to reach mitlist?"
  say "  With a domain:  https://mitlist.example.com"
  say "  LAN only:       http://<this server's LAN IP>:8080"
  printf 'URL: '
  read -r url
fi
url=$(printf '%s' "$url" | sed 's:/*$::')
case "$url" in
  http://*|https://*) ;;
  *) die "the URL must start with http:// or https:// (got '$url')" ;;
esac
set_var MITLIST_URL "$url"

host_port=$(printf '%s' "$url" | sed -E 's#^https?://##; s#/.*$##')
host=$(printf '%s' "$host_port" | sed -E 's#:[0-9]+$##')
port=$(printf '%s' "$host_port" | sed -nE 's#^.*:([0-9]+)$#\1#p')
# The API refuses a loopback FRONTEND_URL in production, and nobody else could
# open the links it sends anyway.
case "$host" in
  localhost|*.localhost|127.*|'[::1]')
    die "use an address other devices can reach, such as http://<this machine's LAN IP>:8080, not $host" ;;
esac

profiles=prod
case "$url" in
  https://*)
    mode=${HTTPS:-}
    if [ -z "$mode" ]; then
      say ""
      say "Who terminates HTTPS for $host?"
      say "  1) The bundled Caddy: gets a Let's Encrypt certificate automatically."
      say "     Needs $host's DNS pointing here and ports 80 + 443 free and reachable."
      say "  2) My own reverse proxy (Traefik, nginx, a Cloudflare tunnel, ...)."
      printf 'Choice [1]: '
      read -r choice
      case "${choice:-1}" in 2) mode=proxy ;; *) mode=caddy ;; esac
    fi
    if [ "$mode" = caddy ]; then
      profiles=prod,https
    fi
    set_var MITLIST_BIND 127.0.0.1
    set_if_empty VAPID_SUBJECT "$url" || true
    ;;
  http://*)
    mode=plain
    # A LAN address: reachable from the household's other devices.
    set_var MITLIST_BIND 0.0.0.0
    set_var MITLIST_PORT "${port:-80}"
    ;;
esac
current_profiles=$(get COMPOSE_PROFILES)
case ",$current_profiles," in
  *,scraper,*) profiles="$profiles,scraper" ;;
esac
set_var COMPOSE_PROFILES "$profiles"

# --- Secrets (never overwritten) ---------------------------------------------
generated=""
pg_pass=$(get POSTGRES_PASSWORD)
if [ -z "$pg_pass" ] || [ "$pg_pass" = mitlist ]; then
  # Compose's default project name: the directory, lowercased, with anything
  # outside [a-z0-9_-] dropped.
  project=${COMPOSE_PROJECT_NAME:-$(get COMPOSE_PROJECT_NAME)}
  [ -n "$project" ] || project=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
  if docker volume inspect "${project}_postgres-data" >/dev/null 2>&1; then
    say ""
    say "warning: POSTGRES_PASSWORD is the dev default, but a database volume already"
    say "exists and keeps the password it was created with. Left unchanged; see"
    say "docs/SELF_HOSTING.md (Troubleshooting) to change it inside PostgreSQL."
  else
    set_var POSTGRES_PASSWORD "$(openssl rand -hex 24)"
    generated="$generated POSTGRES_PASSWORD"
  fi
fi
if set_if_empty SECRET_KEY "$(openssl rand -hex 32)"; then generated="$generated SECRET_KEY"; fi
if set_if_empty SESSION_SECRET_KEY "$(openssl rand -hex 32)"; then generated="$generated SESSION_SECRET_KEY"; fi

if [ -z "$(get VAPID_PRIVATE_KEY)" ] || [ -z "$(get VAPID_PUBLIC_KEY)" ]; then
  # Raw base64url keys, the format webpush-go expects: the 32-byte private
  # scalar and the 65-byte uncompressed public point.
  pem=$(openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null)
  vapid_private=$(printf '%s\n' "$pem" | openssl ec -outform DER 2>/dev/null | tail -c +8 | head -c 32 | b64url)
  vapid_public=$(printf '%s\n' "$pem" | openssl ec -pubout -outform DER 2>/dev/null | tail -c 65 | b64url)
  if [ ${#vapid_private} -ne 43 ] || [ ${#vapid_public} -ne 87 ]; then
    die "could not generate a VAPID key pair with this openssl"
  fi
  set_var VAPID_PRIVATE_KEY "$vapid_private"
  set_var VAPID_PUBLIC_KEY "$vapid_public"
  generated="$generated VAPID_KEYS"
fi
set_if_empty PASSWORD_AUTH_ENABLED true || true
chmod 600 "$ENV_FILE"

# --- Summary -----------------------------------------------------------------
say ""
say "Wrote $ENV_FILE"
say "  URL:       $url"
say "  Services:  $profiles"
if [ -n "$generated" ]; then say "  Generated:$generated"; fi
say ""
case "$mode" in
  caddy) say "Make sure $host resolves to this server and ports 80/443 are open." ;;
  proxy) say "Point your reverse proxy for $host at http://127.0.0.1:$(get MITLIST_PORT)." ;;
  plain) say "Plain http works on a LAN. Use https for anything reachable from the internet." ;;
esac
if [ -z "$(get SMTP_HOST)" ] && [ -z "$(get AWS_SES_REGION)" ]; then
  say "Email is not configured: sign-up skips verification and password reset is off."
  say "Add SMTP_* to $ENV_FILE to turn both on (docs/SELF_HOSTING.md#email)."
fi
say ""
say "Start (the first run builds the images, which takes a while):"
say "  docker compose up -d --build"
say "Then open $url and create your account."
