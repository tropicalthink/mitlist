# mitlist

**The shared household. Free. Open source. Your server.**

Lists, chores, money, meal plans — all in one place. Built for flatmates who want less friction and more clarity. Try it as a guest, no sign-up. No ads. No tracking.

---

## Why mitlist

You're already paying rent. Most of these apps have a usable free tier — but the
free tiers come with ads, daily limits, or the features you actually wanted
sitting behind a subscription. mitlist has one tier, and it's the whole thing.

> **How to read these tables.** ✅ = yes · ⚠️ = partial, see the note · ❌ = no ·
> ? = we couldn't verify it. Competitor facts were checked on **2026-07-27**
> against each vendor's own pages (linked below); prices are list prices in the
> currency the vendor quotes and change often. Where a rival's behaviour was
> unclear we marked it `?` rather than `❌` — an unverified guess in our own
> favour is worse than an empty cell. Found a mistake? Open an issue; we'd
> rather fix the table than win with it.

### vs Paid alternatives

| | mitlist | [Splitwise](https://www.splitwise.com/pro) | [Flatastic](https://flatastic-app.com) | [Bring!](https://www.getbring.com) |
|---|---|---|---|---|
| **Install it today from a store** | ❌ build it yourself | ✅ | ✅ | ✅ |
| **Price** | Free, no tiers, no ads | Free tier (ads + daily expense cap); Pro $4.99/mo or $39.99/yr | Free tier; Premium $1.99/mo · $18.49/yr solo, $6.49/mo · $34.99/yr household | Free tier (ads); Premium $1.99/mo or $8.99/yr |
| **Expense splitting** (equal, exact, %, shares) | ✅ | ✅ | ⚠️ tracks who paid what and the resulting balances | ❌ |
| **Settlement tracking** | ✅ counterparty must confirm | ✅ | ⚠️ balances + monthly overview | ❌ |
| **Recurring expenses** | ✅ | ✅ | ? | ❌ |
| **Multi-currency** | ✅ manual rate, or opt-in feed | ⚠️ Pro only | ? | ❌ |
| **Bank / card import** | ❌ | ⚠️ Pro only | ❌ | ❌ |
| **Receipt handling** | ⚠️ attach a photo; no parsing | ⚠️ Pro scans + itemises receipts | ? | ❌ |
| **Expense search, charts, itemisation** | ❌ | ⚠️ Pro only | ? | ❌ |
| **Chores** (rotating, cron, subtasks) | ✅ | ❌ | ✅ + a points system | ❌ |
| **Shopping lists** (shared, cost tracking) | ✅ | ❌ | ✅ | ✅ the category leader |
| **Barcode scanning, store deals, Alexa/Watch** | ❌ | ❌ | ❌ | ✅ |
| **Meal plans + recipes** | ✅ | ❌ | ❌ | ⚠️ recipes + ingredient import, no planner |
| **Calendar** (all-in-one) | ✅ | ❌ | ❌ | ❌ |
| **Household board / chat** | ⚠️ pinwall notices, no chat | ⚠️ per-expense comment threads | ✅ pinboard + chat | ❌ |
| **Offline use** | ✅ full read/write, queued sync | ✅ add/remove in existing groups, syncs later | ? | ? |
| **Data export** | ⚠️ expenses (CSV/JSON) + calendar (iCal) — not chores or lists | ✅ per-group CSV free; full JSON backup is Pro | ⚠️ Premium | ? |
| **Self-hostable** | ✅ | ❌ | ❌ | ❌ |
| **Open source** | ✅ AGPL-3.0 | ❌ | ❌ | ❌ |

### vs Self-hostable alternatives

| | mitlist | [Grocy](https://grocy.info) | [Homechart](https://homechart.app) | [IHateMoney](https://ihatemoney.org) | [Actual Budget](https://actualbudget.org) |
|---|---|---|---|---|---|
| **License** | AGPL-3.0 | MIT | ❌ proprietary ² | BSD | MIT |
| **Price** | Free | Free | Free solo; household $4.99/mo · $49.99/yr · $149.99 lifetime | Free | Free |
| **Install it today from a store** | ❌ build it yourself | ⚠️ community apps ³ | ✅ official iOS + Android | ❌ web only | ⚠️ iOS app shipped; Android on the roadmap |
| **Expense splitting** | ✅ | ❌ | ✅ | ✅ | ❌ ¹ |
| **Chore rotation** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Shopping lists** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Meal plans + recipes** | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Unified calendar** | ✅ + iCal | ✅ + iCal | ✅ | ❌ | ❌ |
| **Inventory / pantry** | ❌ | ✅ best in class | ✅ | ❌ | ❌ |
| **Barcode + product lookup** | ❌ ⁴ | ✅ | ? | ❌ | ❌ |
| **Bank sync** | ❌ | ❌ | ? | ❌ | ✅ |
| **On-device OCR** (incl. handwriting) | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Offline-first client** | ✅ | ❌ PWA, no offline use | ? | ❌ | ✅ |
| **Multi-household** | ✅ | ❌ | ✅ | ✅ | ❌ ¹ |
| **Data export** | ⚠️ expenses + iCal | ✅ full REST API | ✅ | ✅ JSON/CSV | ✅ |
| **Docker compose** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **GitHub stars** (Jul 2026) | – ⁵ | 9.3k | n/a ² | 1.4k | 27.7k |

¹ Actual Budget is personal finance (envelope budgeting), not shared household expense splitting.
² Homechart is self-hostable but **not open source**. Its vendor states plainly that its products are not open source, promising an MPL-2.0 release only if a product goes six months without a major update; the public `candiddev/homechart` repo (239★) holds the README, translations, and issue tracker, not the source. An earlier version of this table listed it as AGPL-3.0 — that was our error.
³ Grocy ships a PWA and describes it as having no offline capability; the well-regarded Android and iOS clients are community projects, not official.
⁴ mitlist has a barcode *field* you can type into on a product record. Nothing scans it and nothing resolves it to a product.
⁵ mitlist's canonical repo is self-hosted git, so there is no star count to compare — read that as "unproven", not "modest".

**mitlist's honest pitch: among the tools that are free, open source, and self-hosted, it's the one that covers money, chores, shopping, and meals in a single offline-first app, with a fully on-device scanner and an offline grocery catalog. Homechart covers a similar spread with better-polished, actually-installable apps — it just isn't open source and charges for household use. And every app in both tables has one thing mitlist doesn't: you can install it right now (see [Where mitlist is still rough](#where-mitlist-is-still-rough)).**

### What each does better than us

#### Self-hostable

| App | Does better |
|-----|-------------|
| **Actual Budget** | Bank sync (Plaid/GoCardless), envelope budgeting, spending reports, net worth tracking, scheduled transactions, CRDT-based sync, and ~27k stars' worth of contributors. The gold standard for personal finance. |
| **Grocy** | Inventory/pantry tracking with expiry dates, barcode scanning with product lookup, recipe ingredient scaling, equipment and battery tracking, a full REST API, keyboard shortcuts. Nearly a decade of kitchen-ERP depth we don't have. |
| **Homechart** | Published iOS and Android apps that work against your own server, inventory, SSO, encrypted backups, and paid support from someone whose job it is to answer you. |
| **IHateMoney** | Extreme simplicity. No accounts needed for invitees — just share a link. Battle-tested since 2011. If you ONLY need expense splitting, it's lighter. |

#### Closed source

| App | Does better |
|-----|-------------|
| **Splitwise** | Bank/card import, receipt scanning and itemisation, expense search, charts, per-expense comment threads, and a decade of edge cases worked out. (mitlist matches it on opt-in live FX rates, receipt photos, and email notifications — and doesn't cap your expenses or show you ads.) |
| **Flatastic** | A real chat plus pinboard for the flat, a points system that makes chore fairness visible, and a published app your least technical flatmate can install in a minute. |
| **Paprika** | Best-in-class recipe clipping (dedicated site parsers, not just AI), cook mode (full-screen step-by-step with timers), pantry management, nutritional auto-calculation, grocery aisle ordering. The gold standard for recipes. |
| **Tody** | Gamification (streaks, effort levels), room-by-room chore views, visual progress. Makes chores feel like a game. |
| **Bring! / AnyList** | Barcode scanning with a product database, store deals and loyalty cards, Apple Watch, Alexa and voice input, and the most polished shared shopping list anywhere. Bring! does the one thing mitlist's list screen does — and does it better. |

---

## Self-host in 5 minutes

```bash
git clone https://git.vinylnostalgia.com/mo/mitlist.git
cd mitlist
cp .env.example .env                  # docker compose database credentials
cp backend/.env.example backend/.env  # the app's own runtime config
```

There are **two** env files, and they do different jobs:

- **Root `.env`** feeds docker compose `${...}` interpolation — the Postgres
  credentials and the generated `DATABASE_URL`. The prod profile reads
  these and **refuses to start** if `POSTGRES_PASSWORD` is unset.
- **`backend/.env`** is the application's own runtime config (`SECRET_KEY`,
  `SESSION_SECRET_KEY`, OAuth, API keys, …). It does **not** feed compose
  interpolation, so the database password must go in the root `.env`.

Open the **root `.env`** and set **strong, unique** credentials before starting:

```bash
# Generate strong passwords (run these and paste the output into the root .env)
openssl rand -base64 24   # use for POSTGRES_PASSWORD
```

Set in the root `.env`:

```
POSTGRES_PASSWORD=<strong random value>   # REQUIRED — no default
POSTGRES_USER=mitlist
POSTGRES_DB=mitlist
```

Then fill in `SECRET_KEY`, `SESSION_SECRET_KEY`, and any OAuth/API keys in
`backend/.env`, and start:

```bash
docker compose --profile prod up -d
```

PostgreSQL and the Go API start automatically. The database schema is
created on first boot (`RUN_MIGRATIONS_ON_STARTUP=true` — idempotent, safe to
leave on). Point the Flutter app at your server and you're done.

> **Security note**: The database port is bound to `127.0.0.1` only and is
> not reachable from the public network. If you point `DATABASE_URL` at a remote
> Postgres over a public network, set `DB_SSLMODE=require` in the root `.env`.

See [backend/README.md](backend/README.md) for full configuration reference, including how to [enable optional crash reporting](backend/README.md#enable-error-reporting-optional) (off by default — set `SENTRY_DSN` for the backend and the `GLITCHTIP_DSN_WEB` CI secret for the web PWA).

The Flutter app's own build-time settings (`--dart-define`) are listed in
[docs/build-configuration.md](docs/build-configuration.md) — including which
optional features silently disappear when a define is missing.

For production releases, follow the [deployment checklist](docs/DEPLOYMENT.md).
It includes PlanetScale migration checks, the Redis-free cutover, rollback
guidance, and the automated post-deploy smoke command.

### Hosted database: PlanetScale Postgres

The planned official service uses PlanetScale Postgres instead of operating a
Postgres container. The application needs no adapter: set `DATABASE_URL` in the
deployment environment (or the root `.env` when using the prod Compose
profile) to the PlanetScale connection string, preserve its TLS parameters,
and run the normal migrations. Cloudflare R2 holds attachments while Postgres
stores their metadata, household quota counters, and refresh sessions.

---

## Tech stack

| Layer | Tech |
|-------|------|
| Mobile app | Flutter (iOS + Android) |
| Web app | Flutter Web PWA |
| Backend | Go (chi router, pgx) |
| Database | PostgreSQL 16 |
| File storage | S3 / Cloudflare R2 |
| On-device storage | SQLite via Drift (offline outbox + bundled grocery reference DB) |
| On-device ML | PP-OCRv6 detection + recognition on ONNX Runtime; TFLite grocery classifier |

---

## Features

- **Expense splitting** — Equal, exact amounts, percentages, or shares. Settlement tracking with reimbursement suggestions; a settlement only moves balances once the counterparty confirms it.
- **Chore rotation** — Round-robin, fixed assignment, or cron schedules. Subtasks, skip reasons, undo, reschedule.
- **Shopping lists** — Shared lists with item claiming, cost tracking, and automatic expense generation.
- **Meal plans + recipes** — Weekly planner, recipe clipping via AI, auto-generate shopping lists from meal plans.
- **Pinwall** — Corkboard-style household notices with reminders and entity linking.
- **Calendar** — Unified view of chores, meal plans, expenses, and reminders.
- **Offline-first** — Works without internet. Edits queue in an outbox and sync when you're back online; live updates stream over SSE when connected.
- **Scanner** — Photograph a handwritten or printed shopping list and it becomes list items. Detection and recognition both run locally with bundled PP-OCRv6 models on ONNX Runtime — no cloud OCR, no network needed — followed by an on-device classifier and a review step before anything is added. Crossed-out lines are detected and skipped.
- **Grocery brain** — An offline catalog of ~3,200 canonical grocery items and ~277k multilingual aliases ships with the app, so autocomplete, aisle ordering, and scan matching work with no server. It also learns the words your household actually uses, on the device.
- **Notifications** — Push to mobile (FCM) and web (VAPID), plus in-app notifications for chores, expenses, and reminders.
- **Multi-currency** — Record expenses in any currency; balances settle in the group's base currency. Enter the FX rate by hand, or enable an opt-in live rate feed that prefills it.
- **Multi-household** — Switch between households. One account, many groups.
- **Accounts** — Guest mode to start instantly, or sign in with email/password, Google, or Apple.
- **5 languages** — English, German, Spanish, French, Dutch.

---

## Your data, your rules

- **Your server, your data** — Connect the app directly to your instance. Guest mode means you can start without handing over an email.
- **Export everything** — Download expenses as CSV or JSON anytime from the app.
- **No lock-in** — Delete your account to revoke every session, remove credentials and personal profile data, and anonymize your shared household history. Export first if you want a copy.
- **Scans stay on the device** — OCR runs entirely on your phone; list photos are never uploaded for recognition. Correcting a scan can optionally save the corrected line crops locally to improve handwriting recognition — that's off by default, stores no account, household, or list identifiers, and the samples only leave the device if you export them yourself.
- **No telemetry by default** — mitlist collects no usage data or analytics and never phones home. Crash reporting is **opt-in**: an operator can enable it by configuring a Sentry/GlitchTip DSN (off unless set; point it at a self-hosted GlitchTip to keep crash data on your own infrastructure). See [PRIVACY.md](PRIVACY.md).

---

## Download

### Home Assistant

Mitlist ships a native Home Assistant custom integration for household todo
lists, chores, calendars, live events, status counters, and scoped actions.
Tagged `home-assistant-v*` releases can be installed through HACS using this
repository as an Integration custom repository. See the
[Home Assistant guide](home_assistant/README.md) for setup and security details.

Store builds aren't published yet — the way to run mitlist today is to self-host the backend and build the Flutter app yourself (or open the web PWA against your instance).

| Platform | Status |
|----------|--------|
| iOS | Not on the App Store yet — build from source |
| Android | Not on Google Play yet — build from source |
| Web | Flutter Web PWA — build and serve, or point at your instance |
| Self-host | `docker compose --profile prod up -d` |

> The mobile app bundles ~117 MB of assets — the OCR models and the grocery
> reference database — so that scanning and autocomplete work offline. Build
> split-per-ABI APKs or an app bundle; a fat APK is much larger than you want.

---

## Where mitlist is still rough

Being honest about what the comparison tables don't show:

- **No published apps.** There are no store listings or hosted instance yet. You self-host and build the client. Fine for tinkerers, not yet for your non-technical flatmate.
- **Live FX is opt-in.** A self-hosted instance can enable a live rate feed (`FX_RATE_API_URL`) that prefills each expense's exchange rate; without it, you enter the rate by hand. The prefilled rate is advisory, not a bank-grade per-expense rate lock.
- **No bank import.** Expenses are entered by hand (or scanned via OCR), with optional receipt photos attached per expense. No Plaid/GoCardless bank or card sync.
- **No pantry/inventory tracking.** Unlike Grocy, mitlist doesn't track what's in your fridge or expiry dates.
- **Handwriting recognition is good, not solved.** On the current test set the local models read ~98% of legible lines and get ~38% of them exactly right, with messy German handwriting still the weak spot. That's why the scan review screen exists — you check the result before it lands on the list.
- **No barcode product lookup.** The scanner reads text — printed and handwritten — but it won't resolve a barcode to a product. The bundled grocery catalog matches names, not barcodes.
- **The app is big.** Shipping the OCR models and the grocery catalog offline costs ~117 MB of assets. That's the price of the scanner working on a plane.
- **No per-expense comments, search, or charts.** There's a household activity feed, but you can't discuss an individual expense, search your expense history, or see a spending chart. Splitwise Pro does all three.
- **No chat.** The pinwall is a notice board, not a conversation. Flatastic gives a flat an actual chat; mitlist assumes you already have a group chat somewhere else.
- **The web app is the junior sibling.** The PWA covers the household, but the scanner is mobile-only — OCR needs the on-device runtime and is unavailable on web.
- **Recipe clipping is AI-only.** No dedicated per-site parsers like Paprika, so import quality varies by source.
- **Younger and less battle-tested.** Splitwise, IHateMoney, and Actual Budget have years of edge cases worked out. mitlist doesn't yet.

If any of these are dealbreakers, one of the apps above will serve you better — and that's fine.

---

## Support mitlist

mitlist exists because there was no free, pretty, self-hostable option. The
complete self-hosted product stays free and open source: no locked community
edition, no ads, and no sale of household data. Official hosting is free for
normal household use while it remains sustainable, with limits and operating
costs explained publicly on the landing site's transparency page.

Ways to help, in order of usefulness:

1. **Run a household on it** and report the bugs you hit. Official builds carry
   an in-app "Send feedback" sheet that posts to the request tracker; it's
   hidden in builds without a tracker key, so self-hosted clients send nothing.
2. **Star the repo** and tell the next flat that's drowning in group-chat math.
3. **Self-host it** — costs the project nothing, gives you everything.
4. **Chip in for server costs** — donations are opening soon and will be
   accounted for in the open.

---

## Contributing

See [AGENTS.md](AGENTS.md) for architecture and development guidelines.

```bash
# Frontend
cd frontend
flutter pub get
flutter run

# Backend
cp .env.example .env    # root: docker compose DB creds (dev defaults are fine)
docker compose up -d    # postgres only (no profile)
cd backend
cp .env.example .env    # the app's own runtime config — see comments inside
go run ./cmd/migrate up
go run ./cmd/api
```

The root `.env.example` ships dev-usable defaults, so `docker compose up` works
out of the box for local development. For production, set strong values (see
[Self-host in 5 minutes](#self-host-in-5-minutes)).

---

## License

[AGPL-3.0](LICENSE) — Free forever. Share your improvements.

This repository contains the complete corresponding source. You may obtain it
from this repository as permitted under the GNU Affero General Public License.
